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
      return false;
    }

    try {
      // ✅ OTIMIZAÇÃO 2: Remove delays desnecessários
      await windowController.show();
      return true;
    } catch (e) {
      // Remove da lista se a janela não existe mais
      _openWindows.remove(tabId);
      return false;
    }
  }

  /// Registra uma nova janela aberta
  void registerWindow(String tabId, WindowController windowController) {
    _openWindows[tabId] = windowController;
  }

  /// Remove uma janela do registro (quando fechada)
  void unregisterWindow(String tabId) {
    _openWindows.remove(tabId);
  }

  /// Cria uma nova janela ou ativa uma existente
  /// Retorna o WindowController da janela (nova ou existente)
  /// Agora passa os dados do SavedTab como parâmetros para evitar dependência do Supabase
  Future<WindowController?> createOrActivateWindow({
    required String tabId,
    required String windowTitle,
    required Map<String, dynamic> savedTabData,
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
      // ✅ Passa os dados completos do SavedTab como JSON para evitar buscar do Supabase
      final window = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            'tabId': tabId,
            'savedTab': savedTabData, // Dados completos do SavedTab
          }),
          hiddenAtLaunch: false,
        ),
      );

      await window.show();
      registerWindow(tabId, window);
      // ✅ Log de abertura de janela (útil para debug)
      debugPrint('Janela criada: tabId=$tabId');
      return window;
    } catch (e) {
      // ✅ Apenas loga erros críticos
      debugPrint('Erro ao criar janela: $e');
      return null;
    }
  }

  /// Limpa todas as janelas registradas (útil para testes ou reset)
  void clearAll() {
    _openWindows.clear();
  }

  /// Retorna a lista de tabIds com janelas abertas
  List<String> getOpenWindowTabIds() {
    return _openWindows.keys.toList();
  }
}
