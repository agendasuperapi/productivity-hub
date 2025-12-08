import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../screens/browser_window_screen.dart';
import '../models/saved_tab.dart';

/// Helper para criar novas janelas nativas do Windows
class WindowCreator {
  static final Map<String, ui.FlutterView> _windows = {};
  
  /// Cria uma nova janela nativa para uma aba salva
  static Future<void> createWindowForTab(SavedTab savedTab) async {
    try {
      // Cria uma nova view/janela usando a API nativa do Flutter
      final configuration = ui.ViewConfiguration(
        size: const ui.Size(1200, 800),
        devicePixelRatio: 1.0,
      );
      
      final view = ui.PlatformDispatcher.instance.createRootView(configuration);
      
      // Armazena a referência da janela
      _windows[savedTab.id ?? ''] = view;
      
      // Configura o título da janela (se possível)
      // Nota: A API nativa não suporta título diretamente, precisamos usar window_manager
      
      // Renderiza o conteúdo na nova janela
      view.render(() {
        // Cria um novo MaterialApp para esta janela
        runApp(
          MaterialApp(
            title: savedTab.name,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: BrowserWindowScreen(savedTab: savedTab),
          ),
        );
      }, configuration);
      
    } catch (e) {
      debugPrint('Erro ao criar janela nativa: $e');
      // Fallback: retorna null para usar rota fullscreen
      rethrow;
    }
  }
  
  /// Fecha uma janela específica
  static void closeWindow(String tabId) {
    final view = _windows[tabId];
    if (view != null) {
      // Fecha a view (a implementação exata depende da API)
      _windows.remove(tabId);
    }
  }
}

