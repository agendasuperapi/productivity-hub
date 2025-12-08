import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

/// Gerenciador de janelas secundárias para evitar duplicatas
class WindowManagerHelper {
  static final WindowManagerHelper _instance = WindowManagerHelper._internal();
  factory WindowManagerHelper() => _instance;
  WindowManagerHelper._internal();

  // Mapa que armazena os WindowControllers das janelas abertas
  // Chave: tabId, Valor: WindowController
  final Map<String, WindowController> _openWindows = {};

  /// Verifica se uma janela para o tabId já está aberta e a ativa
  /// Retorna true se a janela foi encontrada e ativada, false caso contrário
  Future<bool> activateWindowIfOpen(String tabId) async {
    if (!Platform.isWindows) {
      return false;
    }

    final windowController = _openWindows[tabId];
    if (windowController == null) {
      debugPrint('WindowManagerHelper: Nenhuma janela encontrada para tabId: $tabId');
      return false;
    }

    try {
      // Verifica se a janela ainda existe e está válida
      // Tenta mostrar a janela e trazê-la para frente
      // O método show() do desktop_multi_window deve trazer a janela para frente
      
      // Primeiro, tenta esconder e mostrar novamente para garantir que está ativa
      try {
        await windowController.hide();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Se hide() não existir ou falhar, continua
        debugPrint('WindowManagerHelper: hide() não disponível ou falhou: $e');
      }
      
      // Mostra a janela
      await windowController.show();
      
      // Aguarda um pouco para garantir que a janela foi mostrada
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Tenta mostrar novamente para garantir que está na frente
      // Isso ajuda a garantir que a janela seja trazida para frente mesmo se outras janelas estiverem na frente
      await windowController.show();
      
      // Aguarda mais um pouco e tenta novamente
      await Future.delayed(const Duration(milliseconds: 100));
      await windowController.show();
      
      debugPrint('WindowManagerHelper: ✅ Janela ativada e trazida para frente para tabId: $tabId');
      return true;
    } catch (e) {
      debugPrint('WindowManagerHelper: ❌ Erro ao ativar janela (pode ter sido fechada): $e');
      // Remove da lista se a janela não existe mais
      _openWindows.remove(tabId);
      return false;
    }
  }

  /// Registra uma nova janela aberta
  void registerWindow(String tabId, WindowController windowController) {
    _openWindows[tabId] = windowController;
    // Tenta obter o windowId para comunicação futura
    try {
      // O windowId pode ser obtido através do windowController se disponível
      debugPrint('WindowManagerHelper: Janela registrada para tabId: $tabId');
    } catch (e) {
      debugPrint('WindowManagerHelper: Erro ao obter windowId: $e');
    }
  }

  /// Remove uma janela do registro (quando fechada)
  void unregisterWindow(String tabId) {
    _openWindows.remove(tabId);
    debugPrint('WindowManagerHelper: Janela removida do registro para tabId: $tabId');
  }

  /// Cria uma nova janela ou ativa uma existente
  /// Retorna o WindowController da janela (nova ou existente)
  Future<WindowController?> createOrActivateWindow({
    required String tabId,
    required String windowTitle,
  }) async {
    if (!Platform.isWindows) {
      return null;
    }

    // Primeiro, tenta ativar uma janela existente
    final wasActivated = await activateWindowIfOpen(tabId);
    if (wasActivated) {
      return _openWindows[tabId];
    }

    // Se não encontrou, cria uma nova janela
    try {
      debugPrint('WindowManagerHelper: Criando nova janela para tabId: $tabId');
      final window = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({'tabId': tabId}),
          hiddenAtLaunch: false,
        ),
      );

      // Configura a janela usando a API do desktop_multi_window
      // Nota: desktop_multi_window tem API limitada, então apenas mostramos a janela
      // O tamanho e posição são definidos no WindowConfiguration se disponível
      await window.show();

      // Registra a janela
      registerWindow(tabId, window);

      // Listener para quando a janela for fechada
      // Nota: desktop_multi_window pode não ter evento de fechamento direto,
      // mas podemos tentar detectar quando a janela não existe mais
      _setupWindowCloseListener(tabId, window);

      return window;
    } catch (e) {
      debugPrint('WindowManagerHelper: ❌ Erro ao criar janela: $e');
      return null;
    }
  }

  /// Configura um listener para detectar quando a janela é fechada
  void _setupWindowCloseListener(String tabId, WindowController windowController) {
    // Como desktop_multi_window pode não ter evento de fechamento direto,
    // vamos tentar detectar quando a janela não existe mais na próxima vez
    // que tentarmos ativá-la (isso será feito em activateWindowIfOpen)
    // Por enquanto, apenas registramos
    debugPrint('WindowManagerHelper: Listener configurado para tabId: $tabId');
  }

  /// Limpa todas as janelas registradas (útil para testes ou reset)
  void clearAll() {
    _openWindows.clear();
    debugPrint('WindowManagerHelper: Todas as janelas foram removidas do registro');
  }

  /// Retorna a lista de tabIds com janelas abertas
  List<String> getOpenWindowTabIds() {
    return _openWindows.keys.toList();
  }
}
