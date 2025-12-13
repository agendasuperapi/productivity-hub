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
}

class _QuickMessagesScreenState extends State<QuickMessagesScreen> with WindowListener {
  final QuickMessagesService _service = QuickMessagesService();
  List<QuickMessage> _messages = [];
  List<QuickMessage> _filteredMessages = [];
  bool _isLoading = true;
  String _activationKey = '/'; // Tecla de ativação padrão
  final TextEditingController _searchController = TextEditingController();
  SortOption _sortOption = SortOption.name; // ✅ Opção de ordenação padrão
  final QuickMessageUsageService _usageService = QuickMessageUsageService(); // ✅ Serviço de uso
  bool _isMaximized = false; // ✅ Estado para controlar se a janela está maximizada

  @override
  void initState() {
    super.initState();
    _loadActivationKey();
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
  
  /// ✅ Fecha a janela
  Future<void> _closeWindow() async {
    if (Platform.isWindows) {
      try {
        await windowManager.close();
      } catch (e) {
        debugPrint('Erro ao fechar janela: $e');
      }
    } else {
      Navigator.of(context).pop();
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
    final titleController = TextEditingController(text: message?.title ?? '');
    final messageController = TextEditingController(text: message?.message ?? '');
    final shortcutController = TextEditingController(text: message?.shortcut ?? '');
    final formKey = GlobalKey<FormState>();

    // ✅ Detecta se é tela pequena (celular/tablet)
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;

    if (isSmallScreen) {
      // ✅ Para telas pequenas, usa bottom sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: screenSize.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildDialogContent(
            context: context,
            message: message,
            titleController: titleController,
            messageController: messageController,
            shortcutController: shortcutController,
            formKey: formKey,
            isSmallScreen: true,
          ),
        ),
      );
    } else {
      // ✅ Para telas grandes (desktop), usa diálogo
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          child: _buildDialogContent(
            context: context,
            message: message,
            titleController: titleController,
            messageController: messageController,
            shortcutController: shortcutController,
            formKey: formKey,
            isSmallScreen: false,
          ),
        ),
      );
    }
  }

  Widget _buildDialogContent({
    required BuildContext context,
    QuickMessage? message,
    required TextEditingController titleController,
    required TextEditingController messageController,
    required TextEditingController shortcutController,
    required GlobalKey<FormState> formKey,
    required bool isSmallScreen,
  }) {
    // ✅ Usa uma referência ao State para acessar métodos e variáveis
    final state = this;
    final screenSize = MediaQuery.of(context).size;
    
    return Container(
      width: isSmallScreen ? double.infinity : screenSize.width * 0.6,
      height: isSmallScreen ? screenSize.height * 0.8 : screenSize.height * 0.75,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Título
          Row(
            children: [
              Expanded(
                child: Text(
                  message == null ? 'Nova Mensagem Rápida' : 'Editar Mensagem Rápida',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Formulário com scroll
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ex: Obrigado',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite um título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: shortcutController,
                      decoration: InputDecoration(
                        labelText: 'Atalho',
                        hintText: 'Ex: obr',
                        helperText: 'Digite sem espaços ou caracteres especiais (máximo 8 caracteres)',
                        border: const OutlineInputBorder(),
                        prefixText: state._activationKey,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      maxLength: 8,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite um atalho';
                        }
                        if (value.length > 8) {
                          return 'O atalho não pode ter mais de 8 caracteres';
                        }
                        if (value.contains(' ')) {
                          return 'O atalho não pode conter espaços';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: messageController,
                      decoration: InputDecoration(
                        labelText: 'Mensagem',
                        hintText: 'Digite a mensagem que será inserida\nUse *negrito*, _itálico_, ~tachado~, `inline`\nUse <SAUDACAO> para saudação automática',
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(12),
                        helperText: 'Dica: Use <SAUDACAO> para substituir por "Bom dia", "Boa tarde" ou "Boa noite" automaticamente',
                        helperMaxLines: 2,
                      ),
                      maxLines: null,
                      minLines: isSmallScreen ? 8 : 12,
                      textAlignVertical: TextAlignVertical.top,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite uma mensagem';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Botões
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  _showPreviewDialog(context, messageController.text);
                },
                child: const Text('Pre-Visualizar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final shortcut = shortcutController.text.toLowerCase();
                    
                    // Verifica se o atalho já existe (exceto se estiver editando)
                    final exists = await state._service.shortcutExists(
                      shortcut,
                      excludeId: message?.id,
                    );
                    
                    if (exists) {
                      if (!state.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Este atalho já está em uso'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (!state.mounted) return;
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    if (message == null) {
                      // Criar nova mensagem
                      final newMessage = QuickMessage(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text,
                        message: messageController.text,
                        shortcut: shortcut,
                        createdAt: DateTime.now(),
                      );
                      
                      final saved = await state._service.saveMessage(newMessage);
                      if (saved != null && state.mounted) {
                        // ✅ Atualiza cache global e recarrega do banco para garantir sincronização
                        await GlobalQuickMessagesService().refreshMessages();
                        navigator.pop();
                        state._loadMessages();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Mensagem rápida salva com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      // Atualizar mensagem existente
                      final updated = message.copyWith(
                        title: titleController.text,
                        message: messageController.text,
                        shortcut: shortcut,
                      );
                      
                      final saved = await state._service.updateMessage(updated);
                      if (saved != null && state.mounted) {
                        // ✅ Atualiza cache global e recarrega do banco para garantir sincronização
                        await GlobalQuickMessagesService().refreshMessages();
                        navigator.pop();
                        state._loadMessages();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Mensagem rápida atualizada!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(message == null ? 'Salvar' : 'Atualizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ Substitui placeholders na mensagem (ex: <SAUDACAO>)
  String _replacePlaceholders(String message) {
    if (message.isEmpty) return message;
    
    // ✅ Substitui <SAUDACAO> pela saudação apropriada baseada no horário
    final now = DateTime.now();
    final hour = now.hour;
    
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Boa tarde';
    } else {
      greeting = 'Boa noite';
    }
    
    return message.replaceAll(RegExp(r'<SAUDACAO>', caseSensitive: false), greeting);
  }

  void _showPreviewDialog(BuildContext context, String message) {
    // ✅ Substitui placeholders antes de mostrar o preview
    final processedMessage = _replacePlaceholders(message);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[300],
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pre-Visualização da Mensagem',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[900]),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: message.isEmpty
                        ? Text(
                            'Digite uma mensagem para ver o preview',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _WhatsAppFormattedText(text: processedMessage),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Fechar',
                      style: TextStyle(color: Colors.grey[900]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyMessage(QuickMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem copiada para a área de transferência!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
                  // ✅ Botão Fechar (ícone nativo: X)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _closeWindow,
                    tooltip: 'Fechar',
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

/// Widget que formata texto conforme as regras do WhatsApp
class _WhatsAppFormattedText extends StatelessWidget {
  final String text;

  const _WhatsAppFormattedText({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text(
        'Digite uma mensagem para ver o preview',
        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
      );
    }

    return _buildFormattedText(text);
  }

  Widget _buildFormattedText(String text) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // Regex para encontrar formatações: *negrito*, _itálico_, ~tachado~, `inline`
    final patterns = [
      RegExp(r'\*([^*]+)\*'), // Negrito: *texto*
      RegExp(r'_([^_]+)_'),    // Itálico: _texto_
      RegExp(r'~([^~]+)~'),    // Tachado: ~texto~
      RegExp(r'`([^`]+)`'),    // Inline: `texto`
    ];

    final styles = [
      const TextStyle(fontWeight: FontWeight.bold),
      const TextStyle(fontStyle: FontStyle.italic),
      const TextStyle(decoration: TextDecoration.lineThrough),
      const TextStyle(fontFamily: 'monospace', fontSize: 14),
    ];

    while (currentIndex < text.length) {
      int? earliestMatchIndex;
      int? earliestMatchEnd;
      int? patternIndex;
      String? matchedText;

      // Encontra a primeira formatação
      for (int i = 0; i < patterns.length; i++) {
        final match = patterns[i].firstMatch(text.substring(currentIndex));
        if (match != null) {
          final matchStart = currentIndex + match.start;
          if (earliestMatchIndex == null || matchStart < earliestMatchIndex) {
            earliestMatchIndex = matchStart;
            earliestMatchEnd = currentIndex + match.end;
            patternIndex = i;
            matchedText = match.group(1);
          }
        }
      }

      if (earliestMatchIndex != null && matchedText != null) {
        // Adiciona texto antes da formatação
        if (earliestMatchIndex > currentIndex) {
          spans.add(TextSpan(text: text.substring(currentIndex, earliestMatchIndex)));
        }

        // Adiciona texto formatado
        spans.add(TextSpan(
          text: matchedText,
          style: styles[patternIndex!],
        ));

        currentIndex = earliestMatchEnd!;
      } else {
        // Adiciona o resto do texto
        spans.add(TextSpan(text: text.substring(currentIndex)));
        break;
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: spans,
      ),
    );
  }
}

