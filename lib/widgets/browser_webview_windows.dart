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
    try {
      return InAppWebView(
      // Usa o ambiente isolado criado para esta aba
      webViewEnvironment: widget.tab.environment,
      // Só carrega URL inicial se a aba já foi marcada como carregada (lazy loading)
      // Isso garante que apenas a primeira aba seja carregada ao abrir o app
      initialUrlRequest: _controller == null && 
                         widget.tab.isLoaded &&
                         widget.tab.url != 'about:blank' && 
                         widget.tab.url.isNotEmpty
          ? URLRequest(url: WebUri(widget.tab.url))
          : null,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              // Configurações adicionais para melhor compatibilidade com sites complexos
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              iframeAllowFullscreen: true,
              // Limita recursos para evitar crashes
              resourceCustomSchemes: const [],
              // Configurações de segurança
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              // Configurações de cache
              cacheEnabled: true,
              clearCache: false,
            ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.tab.setController(controller);
        
        // Atualiza o estado de navegação inicial
        _updateNavigationState();
      },
      onLoadStart: (controller, url) {
        try {
          widget.tab.updateUrl(url?.toString() ?? '');
          widget.onUrlChanged(url?.toString() ?? '');
          _updateNavigationState();
        } catch (e) {
          debugPrint('Erro em onLoadStart: $e');
        }
      },
      onLoadStop: (controller, url) async {
        try {
          widget.tab.updateUrl(url?.toString() ?? '');
          widget.onUrlChanged(url?.toString() ?? '');
          
          // Obtém o título da página
          final title = await controller.getTitle();
          if (title != null && title.isNotEmpty) {
            widget.tab.updateTitle(title);
            widget.onTitleChanged(title, widget.tab.id);
          }
          
          _updateNavigationState();
        } catch (e) {
          debugPrint('Erro em onLoadStop: $e');
        }
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          widget.tab.updateTitle(title);
          widget.onTitleChanged(title, widget.tab.id);
        }
      },
      onProgressChanged: (controller, progress) {
        try {
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
        } catch (e) {
          debugPrint('Erro em onProgressChanged: $e');
        }
      },
      // Tratamento de erros com logs detalhados (apenas para debug, não bloqueia carregamento)
      onReceivedError: (controller, request, error) {
        try {
          final errorMsg = '''
=== ERRO NO WEBVIEW ===
URL: ${request.url}
Descrição: ${error.description}
Tipo: ${error.type}
======================
''';
          debugPrint(errorMsg);
          // Não bloqueia o carregamento, apenas registra o erro
        } catch (e) {
          debugPrint('Erro ao processar onReceivedError: $e');
        }
      },
      onReceivedHttpError: (controller, request, response) {
        // Log apenas de erros HTTP críticos (4xx, 5xx)
        final statusCode = response.statusCode;
        if (statusCode != null && statusCode >= 400) {
          debugPrint('=== ERRO HTTP NO WEBVIEW ===');
          debugPrint('URL: ${request.url}');
          debugPrint('Status Code: $statusCode');
          debugPrint('============================');
        }
      },
      );
    } catch (e, stackTrace) {
      debugPrint('=== ERRO CRÍTICO NO BUILD DO WEBVIEW ===');
      debugPrint('Exception: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('========================================');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Erro ao carregar página'),
            SizedBox(height: 8),
            Text('Tente recarregar ou abrir outra página'),
          ],
        ),
      );
    }
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
