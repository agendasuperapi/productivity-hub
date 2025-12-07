import 'dart:io';
import 'package:flutter/foundation.dart';

/// Inicializa o WebViewPlatform para a plataforma atual
void initializeWebViewPlatform() {
  if (Platform.isWindows) {
    // Para Windows, precisamos usar webview_windows
    // Mas como webview_flutter não tem suporte oficial para Windows,
    // vamos tentar uma abordagem alternativa
    try {
      // Tenta inicializar com webview_windows se disponível
      // Nota: webview_flutter não tem suporte oficial para Windows ainda
      debugPrint('Windows platform detected. WebView support may be limited.');
    } catch (e) {
      debugPrint('Error initializing WebView for Windows: $e');
    }
  } else if (Platform.isAndroid) {
    // Android usa webview_flutter_android
    // Já inicializado automaticamente
  } else if (Platform.isIOS || Platform.isMacOS) {
    // iOS/macOS usa webview_flutter_wkwebview
    // Já inicializado automaticamente
  }
}

