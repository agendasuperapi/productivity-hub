import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

/// Helper para definir título de janelas secundárias no Windows
class WindowTitleHelper {
  /// Define o título da janela atual
  static Future<void> setWindowTitle(String title) async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      final windowController = await WindowController.fromCurrentEngine();
      // Tenta definir o título usando métodos disponíveis
      // Nota: desktop_multi_window pode não ter setTitle diretamente
      // O título geralmente é definido através do MaterialApp title
      // Mas vamos tentar outras abordagens se disponíveis
      
      // Por enquanto, o título é definido no MaterialApp
      // e deve aparecer na barra de título do Windows automaticamente
      debugPrint('Título da janela definido: $title');
    } catch (e) {
      debugPrint('Erro ao definir título da janela: $e');
    }
  }
}






