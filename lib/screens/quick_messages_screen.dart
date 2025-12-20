import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_message.dart';
import '../services/quick_messages_service.dart';
import '../services/global_quick_messages_service.dart';
import '../services/quick_message_usage_service.dart';
import '../services/keywords_service.dart';
import '../widgets/draggable_resizable_dialog.dart';
import '../widgets/add_edit_quick_message_dialog.dart';

/// Tela para gerenciar mensagens rápidas
class QuickMessagesScreen extends StatefulWidget {
  const QuickMessagesScreen({super.key});

  @override
  State<QuickMessagesScreen> createState() => _QuickMessagesScreenState();
}

enum SortOption {
  name,
  shortcut,
  message,
  mostUsed,
  dateCreated, // ✅ Data de cadastro (mais novo primeiro)
}

class _QuickMessagesScreenState extends State<QuickMessagesScreen> with WindowListener {
  final QuickMessagesService _service = QuickMessagesService();
  final KeywordsService _keywordsService = KeywordsService();
  List<QuickMessage> _messages = [];
  List<QuickMessage> _filteredMessages = [];
  bool _isLoading = true;
  String _activationKey = '/'; // Tecla de ativação padrão
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.name; // ✅ Opção de ordenação padrão
  final QuickMessageUsageService _usageService = QuickMessageUsageService(); // ✅ Serviço de uso
  bool _isMaximized = false; // ✅ Estado para controlar se a janela está maximizada
  Map<String, String> _keywordsCache = {}; // ✅ Cache de palavras-chave

  @override
  void initState() {
    super.initState();
    _loadActivationKey();
    _loadKeywords();
    _loadMessages();
    _searchController.addListener(_filterMessages);
    
    // ✅ Configura listeners de janela no Windows
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await windowManager.ensureInitialized();
          windowManager.addListener(this);
          await _checkAndUpdateWindowState();
        } catch (e) {
          debugPrint('Erro ao configurar listeners de janela: $e');
        }
      });
    }
  }
  
  @override
  void dispose() {
    // ✅ Remove listener de janela
    if (Platform.isWindows) {
      try {
        windowManager.removeListener(this);
      } catch (e) {
        debugPrint('Erro ao remover listener de janela: $e');
      }
    }
    _searchController.dispose();
    super.dispose();
  }
  
  /// ✅ Verifica e atualiza o estado da janela
  Future<void> _checkAndUpdateWindowState() async {
    if (Platform.isWindows) {
      try {
        final isMaximized = await windowManager.isMaximized();
        if (mounted && isMaximized != _isMaximized) {
          setState(() {
            _isMaximized = isMaximized;
          });
        }
      } catch (e) {
        debugPrint('Erro ao verificar estado da janela: $e');
      }
    }
  }
  
  /// ✅ Minimiza a janela
  Future<void> _minimizeWindow() async {
    if (Platform.isWindows) {
      try {
        await windowManager.minimize();
      } catch (e) {
        debugPrint('Erro ao minimizar janela: $e');
      }
    }
  }
  
  /// ✅ Maximiza ou restaura a janela
  Future<void> _toggleMaximizeWindow() async {
    if (Platform.isWindows) {
      try {
        if (_isMaximized) {
          // ✅ Restaura com 70% do tamanho da tela
          await windowManager.restore();
          // ✅ Aguarda um pouco para garantir que a janela foi restaurada
          await Future.delayed(const Duration(milliseconds: 100));
          try {
            // ✅ Obtém o tamanho da tela disponível usando dart:ui
            final views = ui.PlatformDispatcher.instance.views;
            if (views.isNotEmpty) {
              final screenSize = views.first.physicalSize;
              final devicePixelRatio = views.first.devicePixelRatio;
              final screenWidth = screenSize.width / devicePixelRatio;
              final screenHeight = screenSize.height / devicePixelRatio;
              
              // ✅ Calcula 70% do tamanho da tela
              final newWidth = screenWidth * 0.7;
              final newHeight = screenHeight * 0.7;
              
              // ✅ Centraliza a janela
              final x = (screenWidth - newWidth) / 2;
              final y = (screenHeight - newHeight) / 2;
              
              // ✅ Aplica o novo tamanho e posição
              await windowManager.setSize(Size(newWidth, newHeight));
              await windowManager.setPosition(Offset(x, y));
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao restaurar com 70% da tela: $e');
            // Se houver erro, apenas restaura normalmente sem redimensionar
          }
        } else {
          await windowManager.maximize();
        }
        // ✅ Aguarda um pouco e verifica o estado real para garantir sincronização
        await Future.delayed(const Duration(milliseconds: 100));
        await _checkAndUpdateWindowState();
      } catch (e) {
        debugPrint('Erro ao maximizar/restaurar janela: $e');
      }
    }
  }
  
  // ✅ Listeners do WindowListener
  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = true;
      });
    }
  }

  @override
  void onWindowRestore() {
    if (mounted) {
      setState(() {
        _isMaximized = false;
      });
    }
  }


  void _filterMessages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<QuickMessage> filtered;
      if (query.isEmpty) {
        filtered = List.from(_messages);
      } else {
        filtered = _messages.where((message) {
          return message.title.toLowerCase().contains(query) ||
                 message.shortcut.toLowerCase().contains(query) ||
                 message.message.toLowerCase().contains(query);
        }).toList();
      }
      
      // ✅ Aplica ordenação
      _filteredMessages = _sortMessages(filtered);
    });
  }
  
  /// ✅ Versão síncrona para ordenação (usa apenas usageCount do banco)
  List<QuickMessage> _sortMessages(List<QuickMessage> messages) {
    final sorted = List<QuickMessage>.from(messages);
    
    switch (_sortOption) {
      case SortOption.name:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.shortcut:
        sorted.sort((a, b) => a.shortcut.toLowerCase().compareTo(b.shortcut.toLowerCase()));
        break;
      case SortOption.message:
        sorted.sort((a, b) => a.message.toLowerCase().compareTo(b.message.toLowerCase()));
        break;
      case SortOption.mostUsed:
        // ✅ Ordena por uso (mais usadas primeiro) - usa apenas usageCount do banco
        // Para contadores locais, será atualizado quando a lista for recarregada
        sorted.sort((a, b) => b.usageCount.compareTo(a.usageCount));
        break;
      case SortOption.dateCreated:
        // ✅ Ordena por data de cadastro (mais novo primeiro)
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return sorted;
  }

  Future<void> _loadActivationKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('quick_messages_activation_key');
      if (savedKey != null && savedKey.isNotEmpty) {
        setState(() {
          _activationKey = savedKey;
        });
        debugPrint('[QuickMessages] 🔑 Tecla de ativação carregada: "$_activationKey"');
      } else {
        debugPrint('[QuickMessages] 🔑 Usando tecla de ativação padrão: "$_activationKey"');
      }
    } catch (e) {
      debugPrint('[QuickMessages] ⚠️ Erro ao carregar tecla de ativação: $e');
    }
  }

  Future<void> _saveActivationKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quick_messages_activation_key', key);
      debugPrint('[QuickMessages] 💾 Tecla de ativação salva: "$key"');
    } catch (e) {
      debugPrint('[QuickMessages] ⚠️ Erro ao salvar tecla de ativação: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });
    final messages = await _service.getAllMessages();
    setState(() {
      _messages = messages;
      _filteredMessages = _sortMessages(messages); // ✅ Aplica ordenação ao carregar
      _isLoading = false;
    });
  }

  Future<void> _showAddEditDialog({QuickMessage? message}) async {
    // ✅ Detecta se é tela pequena (celular/tablet)
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;

    if (isSmallScreen) {
      // ✅ Para telas pequenas, usa bottom sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: screenSize.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: AddEditQuickMessageDialog(
              message: message,
              activationKey: _activationKey,
            ),
          );
        },
      );
    } else {
      // ✅ Para telas grandes (desktop), usa diálogo
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (context) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: DraggableResizableDialog(
              initialWidth: MediaQuery.of(context).size.width * 0.6,
              initialHeight: MediaQuery.of(context).size.height * 0.75,
              minWidth: 500,
              minHeight: 400,
              titleBar: Container(
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF00a4a4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(Icons.message, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message == null ? 'Nova Mensagem Rápida' : 'Editar Mensagem Rápida',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              child: AddEditQuickMessageDialog(
                message: message,
                activationKey: _activationKey,
              ),
            ),
          );
        },
      );
    }
    
    // ✅ Recarrega mensagens após salvar/editar
    _loadMessages();
  }


  /// ✅ Carrega palavras-chave customizadas
  Future<void> _loadKeywords() async {
    try {
      final keywords = await _keywordsService.getKeywordsMap();
      if (mounted) {
        setState(() {
          _keywordsCache = keywords;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar palavras-chave: $e');
    }
  }

  Future<void> _copyMessage(QuickMessage message) async {
    // ✅ Substitui palavras-chave antes de copiar
    var processedMessage = KeywordsService.replacePlaceholders(
      message.message,
      _keywordsCache,
    );
    
    // ✅ Substitui o separador interno por quebras de linha duplas
    // Garante que todas as ocorrências sejam substituídas
    const separator = '|||MULTI_TEXT_SEPARATOR|||';
    processedMessage = processedMessage.replaceAll(separator, '\n\n');
    // ✅ Garante que não há separadores restantes (caso haja variações)
    processedMessage = processedMessage.replaceAll(RegExp(r'\|\|\|MULTI_TEXT_SEPARATOR\|\|\|'), '\n\n');
    
    await Clipboard.setData(ClipboardData(text: processedMessage));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Copiado!',
            style: TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _deleteMessage(QuickMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a mensagem "${message.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _service.deleteMessage(message.id);
      if (deleted && mounted) {
        // ✅ Atualiza cache global e recarrega do banco para garantir sincronização
        await GlobalQuickMessagesService().refreshMessages();
        _loadMessages();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensagem rápida excluída!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Platform.isWindows
          ? _DraggableAppBar(
              onWindowStateChanged: _checkAndUpdateWindowState,
              child: AppBar(
                backgroundColor: const Color(0xFF00a4a4),
                foregroundColor: Colors.white,
                title: const Text('Mensagens Rápidas'),
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.white,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Configurar tecla de ativação',
                    onPressed: () => _showActivationKeyDialog(),
                  ),
                  // ✅ Botão Minimizar (ícone nativo: linha horizontal)
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: _minimizeWindow,
                    tooltip: 'Minimizar',
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  // ✅ Botão Maximizar/Restaurar (ícones nativos: quadrado vazio / restaurar)
                  IconButton(
                    icon: Icon(
                      _isMaximized ? Icons.filter_none : Icons.crop_square,
                      size: 18,
                    ),
                    onPressed: _toggleMaximizeWindow,
                    tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            )
          : AppBar(
              title: const Text('Mensagens Rápidas'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Configurar tecla de ativação',
                  onPressed: () => _showActivationKeyDialog(),
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Campo de pesquisa e ordenação
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar mensagens...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}), // Atualiza para mostrar/ocultar ícone de limpar
                      ),
                      const SizedBox(height: 8),
                      // ✅ Dropdown de ordenação
                      Row(
                        children: [
                          const Icon(Icons.sort, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Ordenar por:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<SortOption>(
                              value: _sortOption,
                              isExpanded: true,
                              underline: Container(),
                              items: const [
                                DropdownMenuItem(
                                  value: SortOption.name,
                                  child: Text('Nome'),
                                ),
                                DropdownMenuItem(
                                  value: SortOption.shortcut,
                                  child: Text('Atalho'),
                                ),
                                DropdownMenuItem(
                                  value: SortOption.message,
                                  child: Text('Mensagem'),
                                ),
                                DropdownMenuItem(
                                  value: SortOption.mostUsed,
                                  child: Text('Mais usadas'),
                                ),
                                DropdownMenuItem(
                                  value: SortOption.dateCreated,
                                  child: Text('Data de cadastro (mais novo)'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _sortOption = value;
                                    _filterMessages(); // Reaplica filtro e ordenação
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Informação sobre como usar (compacta)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Digite "$_activationKey" + atalho em qualquer campo de texto',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de mensagens
                Expanded(
                  child: _filteredMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _messages.isEmpty 
                                    ? Icons.message_outlined 
                                    : Icons.search_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _messages.isEmpty
                                    ? 'Nenhuma mensagem rápida cadastrada'
                                    : 'Nenhuma mensagem encontrada',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredMessages.length,
                          itemBuilder: (context, index) {
                            final message = _filteredMessages[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 3),
                              elevation: 1,
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    message.shortcut[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  message.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_activationKey${message.shortcut}',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.message,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    // ✅ Exibe contador de uso
                                    FutureBuilder<int>(
                                      future: _usageService.getTotalUsageCount(message),
                                      builder: (context, snapshot) {
                                        final totalUsage = snapshot.data ?? message.usageCount;
                                        if (totalUsage > 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.trending_up, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Usada $totalUsage vez${totalUsage != 1 ? 'es' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Copiar mensagem',
                                      onPressed: () => _copyMessage(message),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Editar',
                                      onPressed: () => _showAddEditDialog(message: message),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Excluir',
                                      onPressed: () => _deleteMessage(message),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showActivationKeyDialog() async {
    final controller = TextEditingController(text: _activationKey);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tecla de Ativação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escolha a tecla que ativará os atalhos:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 1,
              decoration: const InputDecoration(
                labelText: 'Tecla',
                hintText: 'Ex: /',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newKey = controller.text;
                setState(() {
                  _activationKey = newKey;
                });
                _saveActivationKey(newKey);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tecla de ativação alterada para $newKey'),
                    backgroundColor: Colors.green,
                  ),
                );
                debugPrint('[QuickMessages] 🔑 Tecla de ativação alterada para: "$newKey"');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// ✅ Widget que torna o AppBar arrastável usando a API nativa do sistema
class _DraggableAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  final VoidCallback? onWindowStateChanged;

  const _DraggableAppBar({
    required this.child,
    this.onWindowStateChanged,
  });

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }

    // ✅ Usa DragToMoveArea nativo do window_manager
    // Isso usa a API nativa do Windows para arrastar a janela sem tremor
    return DragToMoveArea(
      child: GestureDetector(
        onDoubleTap: () async {
          // Double tap para maximizar/restaurar
          try {
            final isMaximized = await windowManager.isMaximized();
            if (isMaximized) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
            // ✅ Aguarda um pouco e atualiza o estado
            await Future.delayed(const Duration(milliseconds: 100));
            onWindowStateChanged?.call();
          } catch (e) {
            debugPrint('Erro ao maximizar/restaurar: $e');
          }
        },
        child: child,
      ),
    );
  }
}


