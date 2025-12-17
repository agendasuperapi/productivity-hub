import 'package:flutter/material.dart';
import '../models/tab_group.dart';
import '../services/tab_groups_service.dart';

/// Tela de gerenciamento de grupos de abas (drawer)
class TabGroupsScreen extends StatefulWidget {
  final String? selectedGroupId;
  final Function(String?) onGroupSelected;

  const TabGroupsScreen({
    super.key,
    this.selectedGroupId,
    required this.onGroupSelected,
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
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Grupo'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome do grupo',
            hintText: 'Ex: Trabalho, Pessoal, etc.',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _service.createGroup(name: result);
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

  Future<void> _editGroup(TabGroup group) async {
    final nameController = TextEditingController(text: group.name);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Grupo'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome do grupo',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _service.updateGroup(id: group.id!, name: result);
        await _loadGroups();
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
                    : ListView.builder(
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          final isSelected = widget.selectedGroupId == group.id;
                          
                          return ListTile(
                            leading: Icon(
                              Icons.folder,
                              color: isSelected ? const Color(0xFF00a4a4) : Colors.grey,
                            ),
                            title: Text(
                              group.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF00a4a4) : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              widget.onGroupSelected(group.id);
                              Navigator.of(context).pop();
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
                                  onTap: () => _editGroup(group),
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
                                    onTap: () => _deleteGroup(group),
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

