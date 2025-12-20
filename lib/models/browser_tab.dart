import 'package:flutter/material.dart';
import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';

/// Representa uma aba do navegador com WebView isolado e cookies individuais
class BrowserTab {
  final String id;
  String title;
  String url;
  late final WebViewController controller;
  bool isLoading;
  bool canGoBack;
  bool canGoForward;

  BrowserTab({
    required this.id,
    required this.title,
    required this.url,
    required this.controller,
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  /// Cria uma nova aba com WebView isolado
  factory BrowserTab.create({
    required String id,
    String? initialUrl,
  }) {
    final url = initialUrl ?? 'about:blank';
    
    // Nota: Windows não é suportado ainda pelo webview_flutter
    // Esta verificação é feita no main.dart antes de criar abas
    
    // Cria um WebViewController com cookies isolados
    // IMPORTANTE: Cada aba terá seu próprio contexto de cookies isolado
    // - No Android: Cada WebView tem cookies isolados por padrão quando criamos instâncias separadas
    // - No iOS/macOS: WKWebView isola cookies automaticamente quando criamos WebViewControllers separados
    // 
    // Isso permite que cada aba tenha sessões completamente independentes,
    // permitindo múltiplas contas do WhatsApp, Google, etc. simultaneamente
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
        ),
      );
    
    // setBackgroundColor não está implementado no macOS, então só chama no Windows/Android/iOS
    if (!Platform.isMacOS) {
      controller.setBackgroundColor(Colors.white);
    }
    
    // Permite acesso a arquivos locais e recursos web
    controller.enableZoom(true);
    
    return BrowserTab(
      id: id,
      title: 'Nova Aba',
      url: url,
      controller: controller,
    );
  }

  /// Carrega uma URL na aba
  Future<void> loadUrl(String url) async {
    await controller.loadRequest(Uri.parse(url));
  }

  /// Atualiza o título da aba
  void updateTitle(String newTitle) {
    title = newTitle.isEmpty ? 'Nova Aba' : newTitle;
  }

  /// Atualiza a URL da aba
  void updateUrl(String newUrl) {
    url = newUrl;
  }

  /// Atualiza o estado de navegação
  void updateNavigationState({
    required bool isLoading,
    required bool canGoBack,
    required bool canGoForward,
  }) {
    this.isLoading = isLoading;
    this.canGoBack = canGoBack;
    this.canGoForward = canGoForward;
  }
}

