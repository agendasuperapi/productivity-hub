import 'package:flutter/material.dart';
import 'dart:io';
import 'screens/browser_screen.dart';
import 'screens/browser_screen_windows.dart';
import 'utils/webview_platform_init.dart';

void main() {
  // Inicializa o WebViewPlatform antes de rodar o app
  // Para Windows, agora usamos flutter_inappwebview que gerencia ambientes isolados automaticamente
  initializeWebViewPlatform();
  
  runApp(const GerenciaZapApp());
}

class GerenciaZapApp extends StatelessWidget {
  const GerenciaZapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerencia Zap - Navegador Multi-Aba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Platform.isWindows 
          ? const BrowserScreenWindows()
          : const BrowserScreen(),
    );
  }
}
