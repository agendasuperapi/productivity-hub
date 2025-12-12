import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'window_registry.dart';
import '../services/local_tab_settings_service.dart';

/// Gerenciador de janelas secundárias para evitar duplicatas
class WindowManagerHelper {
  static final WindowManagerHelper _instance = WindowManagerHelper._internal();
  factory WindowManagerHelper() => _instance;
  WindowManagerHelper._internal();

  /// Verifica se uma janela para o tabId já está aberta e a ativa/traz para frente
  /// Retorna true se a janela foi encontrada e ativada, false caso contrário
  Future<bool> activateWindowIfOpen(String tabId) async {
    if (!Platform.isWindows) {
      return false;
    }

    // ✅ Busca o WindowController do registro
    final controller = WindowRegistry.getController(tabId);
    if (controller == null) {
      return false;
    }

    try {
      // ✅ Força a janela a vir para frente no Windows usando múltiplas estratégias
      // Estratégia 1: hide() + show() para forçar atualização
      await controller.hide();
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.show();
      
      // Estratégia 2: Chama show() múltiplas vezes para garantir foco
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.show();
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.show();
      
      debugPrint('Janela ativada: tabId=$tabId');
      return true;
    } catch (e) {
      // Remove do registro se a janela não existe mais
      WindowRegistry.unregister(tabId);
      debugPrint('Erro ao ativar janela existente: $e');
      return false;
    }
  }

  /// Remove uma janela do registro (quando fechada)
  void unregisterWindow(String tabId) {
    WindowRegistry.unregister(tabId);
  }

  /// Cria uma nova janela ou ativa uma existente
  /// Retorna o WindowController da janela (nova ou existente)
  /// Agora passa os dados do SavedTab e mensagens rápidas como parâmetros para evitar dependência do Supabase
  Future<WindowController?> createOrActivateWindow({
    required String tabId,
    required String windowTitle,
    required Map<String, dynamic> savedTabData,
    List<Map<String, dynamic>>? quickMessagesData,
  }) async {
    if (!Platform.isWindows) {
      return null;
    }

    // ✅ Primeiro, tenta ativar uma janela existente
    final existingController = WindowRegistry.getController(tabId);
    if (existingController != null) {
      try {
        // ✅ Força a janela a vir para frente no Windows usando múltiplas estratégias
        // Estratégia 1: hide() + show() para forçar atualização
        await existingController.hide();
        await Future.delayed(const Duration(milliseconds: 30));
        await existingController.show();
        
        // Estratégia 2: Chama show() múltiplas vezes para garantir foco
        await Future.delayed(const Duration(milliseconds: 30));
        await existingController.show();
        await Future.delayed(const Duration(milliseconds: 30));
        await existingController.show();
        
        debugPrint('Janela ativada: tabId=$tabId');
        return existingController;
      } catch (e) {
        // Se falhou ao focar, remove do registro e cria nova
        WindowRegistry.unregister(tabId);
        debugPrint('Falha ao focar janela existente — recriando: $e');
      }
    }

    // Se não encontrou ou falhou ao focar, cria uma nova janela
    try {
      // ✅ Carrega tamanho e posição salvos antes de criar a janela
      // Para janelas de PDF, usa uma chave fixa para compartilhar posição/tamanho
      final localSettings = LocalTabSettingsService();
      final boundsKey = tabId.startsWith('pdf_') ? 'pdf_window' : tabId;
      final savedBounds = await localSettings.getWindowBounds(boundsKey);
      
      // ✅ Usa WindowController.create() para criar nova janela
      // ✅ Cria oculta primeiro para poder aplicar tamanho/posição antes de mostrar
      final window = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            'tabId': tabId,
            'windowTitle': windowTitle, // ✅ Passa o título nos argumentos
            'savedTab': savedTabData, // Dados completos do SavedTab
            'quickMessages': quickMessagesData ?? [], // ✅ Passa mensagens rápidas
            'savedBounds': savedBounds, // ✅ Passa tamanho/posição salvos
          }),
          hiddenAtLaunch: true, // ✅ Cria oculta para aplicar tamanho/posição antes
        ),
      );

      // ✅ Salva o WindowController no registro para poder focar depois
      WindowRegistry.register(tabId, window);

      // ✅ A aplicação de tamanho/posição será feita no main.dart ANTES de mostrar
      // Isso garante que a janela já abra na posição correta
      
      await window.show(); // show() já traz a janela para frente automaticamente
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
    WindowRegistry.clear();
  }

  /// Retorna a lista de tabIds com janelas abertas
  List<String> getOpenWindowTabIds() {
    // WindowRegistry não expõe isso diretamente, então retornamos vazio
    // Se necessário, podemos adicionar um método em WindowRegistry
    return [];
  }
}
