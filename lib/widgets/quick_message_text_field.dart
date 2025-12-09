import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quick_messages_service.dart';

/// TextField customizado com suporte a mensagens rápidas
class QuickMessageTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final String activationKey; // Tecla que ativa o atalho (padrão: "/")
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool enabled;
  final TextInputType? keyboardType;

  const QuickMessageTextField({
    super.key,
    this.controller,
    this.hintText,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.activationKey = '/',
    this.style,
    this.decoration,
    this.enabled = true,
    this.keyboardType,
  });

  @override
  State<QuickMessageTextField> createState() => _QuickMessageTextFieldState();
}

class _QuickMessageTextFieldState extends State<QuickMessageTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  final QuickMessagesService _service = QuickMessagesService();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }


  String _lastText = '';
  Timer? _debounceTimer;

  void _handleTextChanged(String text) {
    // Cancela timer anterior
    _debounceTimer?.cancel();
    
    // Se o texto não mudou, não faz nada
    if (text == _lastText) {
      widget.onChanged?.call(text);
      return;
    }
    
    _lastText = text;
    
    // Verifica se o texto termina com a tecla de ativação + algum texto
    if (text.endsWith(widget.activationKey) && text.length > 1) {
      // Se digitou apenas a tecla de ativação, não faz nada
      widget.onChanged?.call(text);
      return;
    }

    // Procura por padrão: tecla_ativação + atalho no final do texto
    // Procura pelo último padrão que termina no final do texto atual
    final pattern = RegExp('${RegExp.escape(widget.activationKey)}([a-zA-Z0-9]+)\$');
    final match = pattern.firstMatch(text);

    if (match != null) {
      final shortcut = match.group(1) ?? '';
      
      if (shortcut.isNotEmpty && shortcut.length >= 2) {
        // Aguarda um pouco para ver se o usuário vai continuar digitando
        // Se não continuar em 500ms, substitui o atalho
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _checkAndReplaceShortcut(shortcut, match.start, match.end);
        });
      }
    }

    widget.onChanged?.call(text);
  }

  Future<void> _checkAndReplaceShortcut(String shortcut, int start, int end) async {
    final message = await _service.getMessageByShortcut(shortcut);
    
    if (message != null) {
      // Substitui o atalho pela mensagem
      final text = _controller.text;
      final before = text.substring(0, start);
      final after = text.substring(end);
      final newText = '$before${message.message}$after';
      
      // Usa setState para garantir que a UI seja atualizada
      setState(() {
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: start + message.message.length,
          ),
        );
      });

      // Chama onChanged com o novo texto
      widget.onChanged?.call(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onChanged: _handleTextChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.style,
      decoration: widget.decoration ?? InputDecoration(
        hintText: widget.hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
    );
  }
}

