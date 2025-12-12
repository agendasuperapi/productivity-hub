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
  final String? iconUrl; // ✅ URL do ícone da página
  final String? pageName; // ✅ Nome da página

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
    this.iconUrl,
    this.pageName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      child: Row(
        children: [
          // ✅ Ícone e nome da página (se disponível)
          if (iconUrl != null || pageName != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone da página
                  if (iconUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        iconUrl!,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.language,
                            size: 20,
                            color: Colors.blue,
                          );
                        },
                      ),
                    )
                  else
                    const Icon(
                      Icons.language,
                      size: 20,
                      color: Colors.blue,
                    ),
                  if (pageName != null) ...[
                    const SizedBox(width: 6),
                    // Nome da página
                    Text(
                      pageName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlTextField extends StatefulWidget {
  final String currentUrl;
  final Function(String) onUrlSubmitted;

  const _UrlTextField({
    required this.currentUrl,
    required this.onUrlSubmitted,
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
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      },
    );
  }
}

