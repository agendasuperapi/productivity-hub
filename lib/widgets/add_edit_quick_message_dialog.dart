import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quick_message.dart';
import '../services/quick_messages_service.dart';
import '../services/global_quick_messages_service.dart';
import '../services/keywords_service.dart';
import 'draggable_resizable_dialog.dart';

/// Widget reutilizável para adicionar/editar mensagem rápida
/// Usado em todos os lugares: tela lateral, botão da barra de títulos e edição
class AddEditQuickMessageDialog extends StatefulWidget {
  final QuickMessage? message; // null = nova mensagem, não null = editar
  final String activationKey; // Tecla de ativação (ex: '/')

  const AddEditQuickMessageDialog({
    super.key,
    this.message,
    required this.activationKey,
  });

  @override
  State<AddEditQuickMessageDialog> createState() => _AddEditQuickMessageDialogState();
}

class _AddEditQuickMessageDialogState extends State<AddEditQuickMessageDialog> {
  final QuickMessagesService _service = QuickMessagesService();
  final KeywordsService _keywordsService = KeywordsService();
  late final TextEditingController _titleController;
  late final List<TextEditingController> _messageControllers;
  late final TextEditingController _shortcutController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Map<String, String> _keywordsCache = {}; // Cache de palavras-chave

  @override
  void initState() {
    super.initState();
    // ✅ Separa mensagem em múltiplos textos se houver separador
    final separator = '|||MULTI_TEXT_SEPARATOR|||';
    final messageTexts = widget.message?.message.split(separator) ?? 
        [widget.message?.message ?? ''];
    
    _titleController = TextEditingController(text: widget.message?.title ?? '');
    _messageControllers = messageTexts.map((text) => TextEditingController(text: text)).toList();
    _shortcutController = TextEditingController(text: widget.message?.shortcut ?? '');
    
    // ✅ Carrega palavras-chave customizadas
    _loadKeywords();
  }

  /// ✅ Carrega palavras-chave customizadas do banco
  Future<void> _loadKeywords() async {
    try {
      final keywordsMap = await _keywordsService.getKeywordsMap();
      if (mounted) {
        setState(() {
          _keywordsCache = keywordsMap;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar palavras-chave: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _messageControllers) {
      controller.dispose();
    }
    _shortcutController.dispose();
    super.dispose();
  }

  /// ✅ Substitui placeholders na mensagem (ex: <SAUDACAO> e palavras-chave customizadas)
  String _replacePlaceholders(String message) {
    if (message.isEmpty) return message;
    
    String result = message;
    
    // ✅ Substitui <SAUDACAO> (padrão do sistema)
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
    
    result = result.replaceAll(RegExp(r'<SAUDACAO>', caseSensitive: false), greeting);
    
    // ✅ Substitui palavras-chave customizadas
    for (final entry in _keywordsCache.entries) {
      final key = entry.key;
      final value = entry.value;
      // Busca tanto <KEY> quanto KEY (sem os < >)
      result = result.replaceAll(RegExp(key, caseSensitive: false), value);
    }
    
    return result;
  }

  void _showPreviewDialog(BuildContext context, String message) {
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

  Future<void> _saveMessage() async {
    if (!_formKey.currentState!.validate()) return;

    final shortcut = _shortcutController.text.toLowerCase();
    
    // ✅ Verifica se o atalho já existe (exceto se estiver editando)
    final exists = await _service.shortcutExists(
      shortcut,
      excludeId: widget.message?.id,
    );
    
    if (exists) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Atalho já cadastrado',
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            widget.message == null
                ? 'Este atalho já está cadastrado! Por favor, escolha outro atalho para esta mensagem.'
                : 'Este atalho já está cadastrado em outra mensagem! Por favor, escolha outro atalho.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // ✅ Concatena múltiplos textos com separador especial
    final separator = '|||MULTI_TEXT_SEPARATOR|||';
    final combinedMessage = _messageControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => controller.text)
        .join(separator);
    
    if (widget.message == null) {
      // Criar nova mensagem
      final newMessage = QuickMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        message: combinedMessage,
        shortcut: shortcut,
        createdAt: DateTime.now(),
      );
      
      final saved = await _service.saveMessage(newMessage);
      if (saved != null && mounted) {
        await GlobalQuickMessagesService().refreshMessages();
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Mensagem rápida salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Atualizar mensagem existente
      final updated = widget.message!.copyWith(
        title: _titleController.text,
        message: combinedMessage,
        shortcut: shortcut,
      );
      
      final saved = await _service.updateMessage(updated);
      if (saved != null && mounted) {
        await GlobalQuickMessagesService().refreshMessages();
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Mensagem rápida atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 800;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Formulário com scroll
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
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
                      controller: _shortcutController,
                      decoration: InputDecoration(
                        labelText: 'Atalho',
                        hintText: 'Ex: obr',
                        helperText: 'Digite sem espaços ou caracteres especiais (máximo 8 caracteres)',
                        border: const OutlineInputBorder(),
                        prefixText: widget.activationKey,
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
                    // ✅ Seção de múltiplos textos
                    Text(
                      'Textos da Mensagem',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione múltiplos textos para enviar separadamente (cada texto será enviado com Enter)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ✅ Lista de campos de texto
                    ..._messageControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: 'Texto ${index + 1}',
                                    hintText: 'Digite o texto ${index + 1}',
                                    border: const OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                    contentPadding: const EdgeInsets.all(12),
                                    helperText: index == 0 
                                        ? 'Dica: Use <SAUDACAO> para substituir por "Bom dia", "Boa tarde" ou "Boa noite" automaticamente. Use palavras-chave customizadas como <PIX>, <NOME>, etc.'
                                        : null,
                                    helperMaxLines: 3,
                                  ),
                                  maxLines: null,
                                  minLines: isSmallScreen ? 4 : 6,
                                  textAlignVertical: TextAlignVertical.top,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Digite o texto ${index + 1}';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_messageControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      controller.dispose();
                                      _messageControllers.removeAt(index);
                                    });
                                  },
                                  tooltip: 'Remover texto ${index + 1}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                    // ✅ Botão para adicionar novo texto
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar outro texto'),
                      onPressed: () {
                        setState(() {
                          _messageControllers.add(TextEditingController());
                        });
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
                  // ✅ Concatena textos para preview (sem separador, apenas quebras de linha)
                  final previewText = _messageControllers
                      .where((controller) => controller.text.isNotEmpty)
                      .map((controller) => controller.text)
                      .join('\n\n---\n\n');
                  _showPreviewDialog(context, previewText);
                },
                child: const Text('Pre-Visualizar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveMessage,
                child: Text(widget.message == null ? 'Salvar' : 'Atualizar'),
              ),
            ],
          ),
        ],
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

