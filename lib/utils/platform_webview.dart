import 'dart:io';
import 'package:flutter/material.dart';

// Importações condicionais baseadas na plataforma
import 'package:webview_flutter/webview_flutter.dart' 
    if (dart.library.html) 'package:webview_flutter/webview_flutter.dart'
    if (dart.library.io) 'package:webview_flutter/webview_flutter.dart';

/// Abstração para WebView que funciona em todas as plataformas
class PlatformWebView {
  static bool get isWindows => Platform.isWindows;
  static bool get isSupported => !Platform.isWindows; // Windows não tem suporte ainda
  
  /// Cria um WebViewController compatível com a plataforma
  static dynamic createController() {
    if (Platform.isWindows) {
      throw UnsupportedError(
        'webview_flutter não tem suporte oficial para Windows ainda. '
        'Por favor, teste primeiro no Android, iOS ou macOS.'
      );
    }
    
    // Para outras plataformas, usa webview_flutter normalmente
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true);
  }
}

