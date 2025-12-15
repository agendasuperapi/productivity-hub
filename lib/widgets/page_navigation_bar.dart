import 'package:flutter/material.dart';

/// Barra de navegação individual para cada página/WebView
class PageNavigationBar extends StatelessWidget {
  final String currentUrl;
  final bool isLoading;
  final bool canGoBack;
  final bool canGoForward;
  final Function(String) onUrlSubmitted;
  final VoidCallback? onBackPressed;
  final VoidCallback? onForwardPressed;
  final VoidCallback? onRefreshPressed;
  final VoidCallback? onDownloadHistoryPressed; // ✅ Callback para abrir histórico de downloads
  final VoidCallback? onZoomInPressed; // ✅ Callback para aumentar zoom
  final VoidCallback? onZoomOutPressed; // ✅ Callback para diminuir zoom
  final VoidCallback? onZoomResetPressed; // ✅ Callback para restaurar zoom padrão
  final double? currentZoom; // ✅ Zoom atual para exibir no tooltip
  final VoidCallback? onUrlFieldInteraction; // ✅ Callback quando há interação no campo de URL
  final String? iconUrl; // ✅ URL do ícone da página
  final String? pageName; // ✅ Nome da página
  final bool isPdfWindow; // ✅ Indica se é uma janela de PDF
  final bool isAlwaysOnTop; // ✅ Indica se a janela está fixada (alwaysOnTop)

  const PageNavigationBar({
    super.key,
    required this.currentUrl,
    required this.isLoading,
    required this.canGoBack,
    required this.canGoForward,
    required this.onUrlSubmitted,
    this.onBackPressed,
    this.onForwardPressed,
    this.onRefreshPressed,
    this.onDownloadHistoryPressed,
    this.onZoomInPressed,
    this.onZoomOutPressed,
    this.onZoomResetPressed,
    this.currentZoom,
    this.onUrlFieldInteraction,
    this.iconUrl,
    this.pageName,
    this.isPdfWindow = false,
    this.isAlwaysOnTop = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Barra de navegação normal
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      child: Row(
        children: [
          // Botões de navegação
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: canGoBack ? onBackPressed : null,
            tooltip: 'Voltar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: canGoForward ? onForwardPressed : null,
            tooltip: 'Avançar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: onRefreshPressed,
            tooltip: 'Atualizar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          // ✅ Botões de zoom (logo após o botão de atualizar)
          if (onZoomInPressed != null || onZoomOutPressed != null || onZoomResetPressed != null) ...[
            const SizedBox(width: 4),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 4),
            // Botão diminuir zoom
            if (onZoomOutPressed != null)
              IconButton(
                icon: const Icon(Icons.zoom_out, size: 20),
                onPressed: onZoomOutPressed,
                tooltip: currentZoom != null 
                    ? 'Diminuir zoom (${(currentZoom! * 100).toStringAsFixed(1)}%)'
                    : 'Diminuir zoom',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            // Botão restaurar zoom
            if (onZoomResetPressed != null)
              IconButton(
                icon: const Icon(Icons.zoom_out_map, size: 20),
                onPressed: onZoomResetPressed,
                tooltip: currentZoom != null 
                    ? 'Restaurar zoom padrão (atual: ${(currentZoom! * 100).toStringAsFixed(1)}%)'
                    : 'Restaurar zoom padrão',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            // Botão aumentar zoom
            if (onZoomInPressed != null)
              IconButton(
                icon: const Icon(Icons.zoom_in, size: 20),
                onPressed: onZoomInPressed,
                tooltip: currentZoom != null 
                    ? 'Aumentar zoom (${(currentZoom! * 100).toStringAsFixed(1)}%)'
                    : 'Aumentar zoom',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
          // ✅ Só mostra o botão de histórico se o callback estiver definido
          if (onDownloadHistoryPressed != null)
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              onPressed: onDownloadHistoryPressed,
              tooltip: 'Histórico de downloads',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 4),
          // Campo de URL
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _UrlTextField(
                currentUrl: currentUrl,
                onUrlSubmitted: onUrlSubmitted,
                onInteraction: onUrlFieldInteraction, // ✅ Passa callback de interação
              ),
            ),
          ),
          // ✅ Indicador de janela fixada
          if (isAlwaysOnTop) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Fixada',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UrlTextField extends StatefulWidget {
  final String currentUrl;
  final Function(String) onUrlSubmitted;
  final VoidCallback? onInteraction; // ✅ Callback quando há interação

  const _UrlTextField({
    required this.currentUrl,
    required this.onUrlSubmitted,
    this.onInteraction,
  });

  @override
  State<_UrlTextField> createState() => _UrlTextFieldState();
}

class _UrlTextFieldState extends State<_UrlTextField> {
  late TextEditingController _urlController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // ✅ Se a URL for 'about:blank', deixa o campo em branco
    final displayUrl = (widget.currentUrl == 'about:blank' || widget.currentUrl.isEmpty) ? '' : widget.currentUrl;
    _urlController = TextEditingController(text: displayUrl);
    // ✅ Adiciona listener para detectar quando o usuário começa a digitar
    _urlController.addListener(() {
      if (_urlController.text.isNotEmpty) {
        widget.onInteraction?.call();
      }
    });
    // ✅ Detecta quando o campo ganha foco
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onInteraction?.call();
      }
    });
  }

  @override
  void didUpdateWidget(_UrlTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Atualiza o texto do controller quando a URL mudar (mas só se não estiver em foco)
    // Isso evita que o texto seja sobrescrito enquanto o usuário está digitando
    if (widget.currentUrl != oldWidget.currentUrl && !_focusNode.hasFocus) {
      // ✅ Se a URL for 'about:blank', mostra em branco
      final displayUrl = (widget.currentUrl == 'about:blank' || widget.currentUrl.isEmpty) ? '' : widget.currentUrl;
      _urlController.text = displayUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String value) {
    String url = value.trim();
    
    // Adiciona https:// se não tiver protocolo
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Verifica se parece ser um domínio ou IP
      if (url.contains('.') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(url)) {
        url = 'https://$url';
      } else {
        // Se não parecer URL, faz busca no Google
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    
    widget.onUrlSubmitted(url);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _urlController,
      focusNode: _focusNode,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: 'Digite uma URL ou pesquise',
        hintStyle: TextStyle(fontSize: 14),
      ),
      style: const TextStyle(fontSize: 14),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      onSubmitted: _handleSubmitted,
      onTap: () {
        // ✅ Notifica interação quando campo é clicado
        widget.onInteraction?.call();
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      },
    );
  }
}

