import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/browser_tab.dart';

/// Widget WebView para uma aba do navegador
class BrowserWebView extends StatefulWidget {
  final BrowserTab tab;
  final Function(String) onUrlChanged;
  final Function(String) onTitleChanged;
  final Function(bool, bool, bool) onNavigationStateChanged;

  const BrowserWebView({
    super.key,
    required this.tab,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onNavigationStateChanged,
  });

  @override
  State<BrowserWebView> createState() => _BrowserWebViewState();
}

class _BrowserWebViewState extends State<BrowserWebView> {
  @override
  void initState() {
    super.initState();
    _setupWebView();
  }

  void _setupWebView() {
    // Configura o NavigationDelegate para capturar eventos
    widget.tab.controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          widget.onNavigationStateChanged(true, false, false);
          widget.onUrlChanged(url);
          widget.onTitleChanged('Carregando...');
        },
        onPageFinished: (String url) async {
          // Obtém o título da página
          final title = await widget.tab.controller.getTitle() ?? 'Nova Aba';
          widget.onTitleChanged(title);
          widget.onUrlChanged(url);
          
          // Verifica estado de navegação
          final canGoBack = await widget.tab.controller.canGoBack();
          final canGoForward = await widget.tab.controller.canGoForward();
          widget.onNavigationStateChanged(false, canGoBack, canGoForward);
        },
        onWebResourceError: (WebResourceError error) {
          widget.onNavigationStateChanged(false, false, false);
        },
        onNavigationRequest: (NavigationRequest request) {
          widget.onUrlChanged(request.url);
          return NavigationDecision.navigate;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: widget.tab.controller);
  }
}

