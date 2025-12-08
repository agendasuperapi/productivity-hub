import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../screens/browser_window_screen.dart';
import '../models/saved_tab.dart';

/// Helper para gerenciar múltiplas janelas na mesma instância
class WindowManagerHelper {
  static final Map<String, WindowController> _windows = {};
  
  /// Cria uma nova janela para uma aba salva
  static Future<void> createWindowForTab(SavedTab savedTab) async {
    if (!Platform.isWindows || savedTab.id == null) {
      return;
    }
    
    try {
      // Cria uma nova janela usando window_manager
      final windowController = await windowManager.createWindow(
        const Size(1200, 800),
        title: savedTab.name,
        center: true,
        skipTaskbar: false,
        backgroundColor: Colors.white,
        titleBarStyle: TitleBarStyle.normal,
      );
      
      // Armazena a referência da janela
      _windows[savedTab.id!] = windowController;
      
      // Configura o conteúdo da janela
      await windowController.setAsFrameless(false);
      await windowController.setTitle(savedTab.name);
      await windowController.show();
      await windowController.focus();
      
      // Cria um novo MaterialApp para esta janela
      // Nota: Isso requer uma abordagem diferente, pois cada janela precisa de seu próprio contexto
      // Por enquanto, vamos usar uma nova instância leve
    } catch (e) {
      debugPrint('Erro ao criar janela: $e');
    }
  }
  
  /// Fecha uma janela específica
  static Future<void> closeWindow(String tabId) async {
    final windowController = _windows[tabId];
    if (windowController != null) {
      await windowController.close();
      _windows.remove(tabId);
    }
  }
  
  /// Fecha todas as janelas secundárias
  static Future<void> closeAllWindows() async {
    for (final windowController in _windows.values) {
      await windowController.close();
    }
    _windows.clear();
  }
}

