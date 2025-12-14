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
  /// Agora também mostra janelas que foram ocultadas (ao invés de fechadas)
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
      // ✅ Oculta a janela brevemente e mostra novamente para forçar foco
      // Isso garante que a janela seja trazida para frente mesmo se já estiver visível
      try {
        await controller.hide();
        await Future.delayed(const Duration(milliseconds: 10));
      } catch (e) {
        // Se falhar ao ocultar, continua normalmente
      }
      
      // ✅ Mostra a janela novamente (força foco)
      await controller.show();
      
      debugPrint('✅ Janela ativada/mostrada: tabId=$tabId');
      return true;
    } catch (e) {
      // ✅ Se falhar ao mostrar, pode ser que a janela foi realmente fechada
      // ✅ Remove do registro apenas se o erro indicar que a janela não existe mais
      debugPrint('⚠️ Erro ao ativar janela existente: $e');
      // ✅ Não remove do registro automaticamente - pode estar apenas oculta
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

    // ✅ Primeiro, tenta ativar uma janela existente (pode estar oculta)
    final existingController = WindowRegistry.getController(tabId);
    if (existingController != null) {
      try {
        // ✅ Oculta a janela brevemente e mostra novamente para forçar foco
        // Isso garante que a janela seja trazida para frente mesmo se já estiver visível
        try {
          await existingController.hide();
          await Future.delayed(const Duration(milliseconds: 10));
        } catch (e) {
          // Se falhar ao ocultar, continua normalmente
        }
        
        // ✅ Mostra a janela novamente (força foco)
        await existingController.show();
        
        debugPrint('✅ Janela existente ativada/mostrada: tabId=$tabId');
        return existingController;
      } catch (e) {
        // ✅ Se falhou ao mostrar, pode ser que a janela foi realmente fechada
        // ✅ Remove do registro e cria nova apenas se necessário
        debugPrint('⚠️ Falha ao mostrar janela existente — recriando: $e');
        WindowRegistry.unregister(tabId);
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

      // ✅ CRÍTICO: NÃO chama window.show() aqui - deixa o main.dart controlar quando mostrar
      // ✅ O main.dart aplicará a posição ANTES de mostrar usando window_manager
      // ✅ Log de criação de janela (ainda oculta)
      debugPrint('Janela criada (oculta): tabId=$tabId');
      
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
