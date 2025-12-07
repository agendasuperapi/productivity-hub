import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/browser_tab_windows.dart';

/// Widget WebView para Windows usando flutter_inappwebview
class BrowserWebViewWindows extends StatefulWidget {
  final BrowserTabWindows tab;
  final Function(String) onUrlChanged;
  final Function(String, String) onTitleChanged; // Agora recebe (title, tabId)
  final Function(bool, bool, bool) onNavigationStateChanged;

  const BrowserWebViewWindows({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
  });

  @override
  State<BrowserWebViewWindows> createState() => _BrowserWebViewWindowsState();
}

class _BrowserWebViewWindowsState extends State<BrowserWebViewWindows> {
  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(BrowserWebViewWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se mudou de aba, atualiza o controller
    // IMPORTANTE: Não recria o WebView, apenas atualiza a referência
    // Isso preserva os cookies e o estado da aba
    if (oldWidget.tab.id != widget.tab.id && _controller != null) {
      widget.tab.setController(_controller!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usa InAppWebView com o ambiente isolado da aba
    // IMPORTANTE: Só carrega URL inicial se o controller ainda não foi criado
    // Isso evita recarregar quando troca de aba
    return InAppWebView(
      // Usa o ambiente isolado criado para esta aba
      webViewEnvironment: widget.tab.environment,
      // Só carrega URL inicial se não tiver controller ainda (primeira vez)
      initialUrlRequest: _controller == null && 
                         widget.tab.url != 'about:blank' && 
                         widget.tab.url.isNotEmpty
          ? URLRequest(url: WebUri(widget.tab.url))
          : null,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.tab.setController(controller);
        
        // Atualiza o estado de navegação inicial
        _updateNavigationState();
      },
      onLoadStart: (controller, url) {
        widget.tab.updateUrl(url?.toString() ?? '');
        widget.onUrlChanged(url?.toString() ?? '');
        _updateNavigationState();
      },
      onLoadStop: (controller, url) async {
        widget.tab.updateUrl(url?.toString() ?? '');
        widget.onUrlChanged(url?.toString() ?? '');
        
        // Obtém o título da página
        final title = await controller.getTitle();
        if (title != null && title.isNotEmpty) {
          widget.tab.updateTitle(title);
          widget.onTitleChanged(title, widget.tab.id);
        }
        
        _updateNavigationState();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          widget.tab.updateTitle(title);
          widget.onTitleChanged(title, widget.tab.id);
        }
      },
      onProgressChanged: (controller, progress) {
        widget.tab.updateNavigationState(
          isLoading: progress < 100,
          canGoBack: widget.tab.canGoBack,
          canGoForward: widget.tab.canGoForward,
        );
        widget.onNavigationStateChanged(
          progress < 100,
          widget.tab.canGoBack,
          widget.tab.canGoForward,
        );
      },
    );
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    
    final canGoBack = await _controller!.canGoBack();
    final canGoForward = await _controller!.canGoForward();
    
    widget.tab.updateNavigationState(
      isLoading: false,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
    );
    
    widget.onNavigationStateChanged(false, canGoBack, canGoForward);
  }

  @override
  void dispose() {
    // Não dispose o controller aqui, o TabManager faz isso
    super.dispose();
  }
}
