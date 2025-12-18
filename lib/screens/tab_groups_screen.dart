import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/tab_group.dart';
import '../services/tab_groups_service.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/icons_api_service.dart';
import '../widgets/icon_image_widget.dart';

/// Tela de gerenciamento de grupos de abas (drawer)
class TabGroupsScreen extends StatefulWidget {
  final String? selectedGroupId;
  final Function(String?) onGroupSelected;
  final Function(String?)? onGroupUpdated; // ✅ Callback quando um grupo é atualizado
  final bool shouldCloseOnSelect; // Controla se deve fechar o Navigator ao selecionar

  const TabGroupsScreen({
    super.key,
    this.selectedGroupId,
    required this.onGroupSelected,
    this.onGroupUpdated, // ✅ Callback opcional para notificar atualização
    this.shouldCloseOnSelect = true, // Padrão: fecha o Navigator (comportamento original)
  });

  @override
  State<TabGroupsScreen> createState() => _TabGroupsScreenState();
}

class _TabGroupsScreenState extends State<TabGroupsScreen> {
  final TabGroupsService _service = TabGroupsService();
  List<TabGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await _service.getTabGroups();
      
      // Se não houver grupos, cria o grupo padrão
      if (groups.isEmpty) {
        await _service.createDefaultGroup();
        final updatedGroups = await _service.getTabGroups();
        setState(() {
          _groups = updatedGroups;
        });
      } else {
        setState(() {
          _groups = groups;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar grupos: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    File? selectedIconFile;
    String? selectedIconUrl;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo Grupo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do grupo',
                    hintText: 'Ex: Trabalho, Pessoal, etc.',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                // Seletor de ícone (mesmo sistema das abas)
                Row(
                  children: [
                    const Text('Ícone: '),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        // ✅ Abre menu para escolher entre imagem ou ícone da API
                        final iconOption = await _showIconOptions();
                        if (iconOption != null) {
                          setDialogState(() {
                            if (iconOption['type'] == 'file') {
                              selectedIconFile = iconOption['file'] as File;
                              selectedIconUrl = null;
                            } else if (iconOption['type'] == 'url') {
                              selectedIconUrl = iconOption['url'] as String;
                              selectedIconFile = null;
                            }
                          });
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selectedIconFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  selectedIconFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : selectedIconUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: IconImageWidget(
                                      iconUrl: selectedIconUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(Icons.broken_image, size: 30),
                                    ),
                                  )
                                : const Icon(Icons.add_photo_alternate, size: 30),
                      ),
                    ),
                    if (selectedIconFile != null || selectedIconUrl != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setDialogState(() {
                            selectedIconFile = null;
                            selectedIconUrl = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'iconFile': selectedIconFile,
                    'iconUrl': selectedIconUrl,
                  });
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'] != null) {
      try {
        final newGroup = await _service.createGroup(name: result['name'] as String);
        
        // ✅ Faz upload do ícone se foi selecionado (arquivo ou URL)
        if (newGroup.id != null) {
          String? iconUrl;
          
          if (result['iconFile'] != null) {
            // ✅ Upload de arquivo local
            final iconFile = result['iconFile'] as File;
            iconUrl = await _service.uploadGroupIcon(iconFile, newGroup.id!);
          } else if (result['iconUrl'] != null) {
            // ✅ Usa URL diretamente (ícone da API)
            iconUrl = result['iconUrl'] as String;
          }
          
          if (iconUrl != null) {
            await _service.updateGroup(id: newGroup.id!, iconUrl: iconUrl);
          }
        }
        
        await _loadGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grupo criado com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar grupo: $e')),
          );
        }
      }
    }
  }

  /// ✅ Abre menu para escolher entre adicionar imagem ou buscar ícone da API
  Future<Map<String, dynamic>?> _showIconOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Escolha uma opção',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Adicionar imagem'),
                subtitle: const Text('Selecione uma imagem PNG do seu computador'),
                onTap: () {
                  Navigator.pop(context, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette, color: Colors.blue),
                title: const Text('Buscar ícone'),
                subtitle: const Text('Busca em múltiplas APIs - ícones coloridos e em preto e branco'),
                onTap: () {
                  Navigator.pop(context, 'icon');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result == 'image') {
      return await _pickIconFile();
    } else if (result == 'icon') {
      return await _pickIconFromApi();
    }
    return null;
  }

  /// ✅ Seleciona ícone do arquivo local
  Future<Map<String, dynamic>?> _pickIconFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['png'],
    );

    if (result != null && result.files.single.path != null) {
      return {
        'type': 'file',
        'file': File(result.files.single.path!),
      };
    }
    return null;
  }

  /// ✅ Seleciona ícone da API (busca em múltiplas APIs)
  Future<Map<String, dynamic>?> _pickIconFromApi() async {
    final selectedIcon = await showDialog<IconResult>(
      context: context,
      builder: (context) => const IconPickerDialog(),
    );

    if (selectedIcon != null) {
      return {
        'type': 'url',
        'url': selectedIcon.url,
      };
    }
    return null;
  }

  Future<void> _editGroup(TabGroup group) async {
    final nameController = TextEditingController(text: group.name);
    File? selectedIconFile;
    String? selectedIconUrl = group.iconUrl;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Grupo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do grupo',
                  ),
                  autofocus: group.name != 'Geral',
                  enabled: group.name != 'Geral', // Desabilita edição do nome para o grupo "Geral"
                  readOnly: group.name == 'Geral', // Torna readonly para o grupo "Geral"
                ),
                if (group.name == 'Geral')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'O grupo "Geral" não pode ser renomeado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Seletor de ícone (mesmo sistema das abas)
                Row(
                  children: [
                    const Text('Ícone: '),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        // ✅ Abre menu para escolher entre imagem ou ícone da API
                        final iconOption = await _showIconOptions();
                        if (iconOption != null) {
                          setDialogState(() {
                            if (iconOption['type'] == 'file') {
                              selectedIconFile = iconOption['file'] as File;
                              selectedIconUrl = null; // Remove o ícone atual ao selecionar novo
                            } else if (iconOption['type'] == 'url') {
                              selectedIconUrl = iconOption['url'] as String;
                              selectedIconFile = null; // Remove arquivo se houver
                            }
                          });
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: selectedIconFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  selectedIconFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : selectedIconUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: IconImageWidget(
                                      iconUrl: selectedIconUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(Icons.image, size: 30),
                                    ),
                                  )
                                : const Icon(Icons.add_photo_alternate, size: 30),
                      ),
                    ),
                    if (selectedIconFile != null || selectedIconUrl != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setDialogState(() {
                            selectedIconFile = null;
                            selectedIconUrl = null;
                          });
                        },
                        tooltip: 'Remover ícone',
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Para o grupo "Geral", mantém o nome original
                final nameToSave = group.name == 'Geral' 
                    ? group.name 
                    : nameController.text.trim();
                
                if (nameToSave.isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameToSave,
                    'iconFile': selectedIconFile,
                    'iconUrl': selectedIconUrl,
                    'removeIcon': selectedIconFile == null && selectedIconUrl == null && group.iconUrl != null,
                  });
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'] != null && group.id != null) {
      try {
        String? iconUrl;
        bool removeIcon = result['removeIcon'] == true;
        
        // Remove ícone se solicitado
        if (removeIcon && group.iconUrl != null) {
          await _service.deleteGroupIcon(group.iconUrl!);
          iconUrl = null;
        }
        // ✅ Faz upload do novo ícone se foi selecionado (arquivo ou URL)
        else if (result['iconFile'] != null) {
          // Remove o ícone antigo se existir
          if (group.iconUrl != null) {
            await _service.deleteGroupIcon(group.iconUrl!);
          }
          iconUrl = await _service.uploadGroupIcon(result['iconFile'] as File, group.id!);
        } else if (result['iconUrl'] != null) {
          // ✅ Usa URL diretamente (ícone da API)
          // Remove o ícone antigo se existir
          if (group.iconUrl != null) {
            await _service.deleteGroupIcon(group.iconUrl!);
          }
          iconUrl = result['iconUrl'] as String;
        }
        
        // Para o grupo "Geral", não atualiza o nome
        await _service.updateGroup(
          id: group.id!,
          name: group.name == 'Geral' ? null : result['name'] as String,
          iconUrl: iconUrl,
          removeIcon: removeIcon,
        );
        await _loadGroups();
        
        // ✅ Notifica a tela principal que o grupo foi atualizado
        if (widget.onGroupUpdated != null) {
          widget.onGroupUpdated!(group.id);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grupo atualizado com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar grupo: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteGroup(TabGroup group) async {
    // Não permite deletar o grupo padrão "Geral"
    if (group.name == 'Geral') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não é possível deletar o grupo padrão "Geral"')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Tem certeza que deseja deletar o grupo "${group.name}"?\n\nAs abas deste grupo serão movidas para o grupo "Geral".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteGroup(group.id!);
        await _loadGroups();
        
        // Se o grupo deletado era o selecionado, seleciona o grupo padrão
        if (widget.selectedGroupId == group.id) {
          final defaultGroup = _groups.firstWhere(
            (g) => g.name == 'Geral',
            orElse: () => _groups.first,
          );
          widget.onGroupSelected(defaultGroup.id);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grupo deletado com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao deletar grupo: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Cabeçalho
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF00a4a4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grupos de Abas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Organize suas abas em grupos',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Botão de criar novo grupo
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createGroup,
                icon: const Icon(Icons.add),
                label: const Text('Novo Grupo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00a4a4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // Lista de grupos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum grupo cadastrado',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: _groups.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _groups.removeAt(oldIndex);
                            _groups.insert(newIndex, item);
                          });
                          
                          // Atualiza a ordem no banco
                          try {
                            await _service.reorderGroups(_groups.map((g) => g.id!).toList());
                            // Notifica o callback para atualizar o grupo padrão se necessário
                            if (_groups.isNotEmpty) {
                              widget.onGroupSelected(_groups.first.id);
                            }
                          } catch (e) {
                            // Reverte em caso de erro
                            await _loadGroups();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro ao reordenar grupos: $e')),
                              );
                            }
                          }
                        },
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final isSelected = widget.selectedGroupId == group.id;
                          
                          return ListTile(
                            key: ValueKey(group.id),
                            leading: group.iconUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: IconImageWidget(
                                      iconUrl: group.iconUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: Icon(
                                        group.name == 'Geral' ? Icons.public : Icons.folder,
                                        color: isSelected ? const Color(0xFF00a4a4) : Colors.grey,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    group.name == 'Geral' ? Icons.public : Icons.folder,
                                    color: isSelected ? const Color(0xFF00a4a4) : Colors.grey,
                                    size: 40,
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF00a4a4) : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (index == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00a4a4).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Padrão',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF00a4a4),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            selected: isSelected,
                            onTap: () {
                              widget.onGroupSelected(group.id);
                              // Só fecha o Navigator se shouldCloseOnSelect for true
                              if (widget.shouldCloseOnSelect) {
                                Navigator.of(context).pop();
                              }
                            },
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                  onTap: () => Future.delayed(
                                    const Duration(milliseconds: 100),
                                    () => _editGroup(group),
                                  ),
                                ),
                                if (group.name != 'Geral')
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Deletar', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                    onTap: () => Future.delayed(
                                      const Duration(milliseconds: 100),
                                      () => _deleteGroup(group),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

