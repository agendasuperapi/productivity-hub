import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciar configurações locais de abas
/// Armazena configurações que não devem ser sincronizadas com o Supabase
class LocalTabSettingsService {
  static const String _prefixOpenAsWindow = 'tab_open_as_window_';
  static const String _prefixPageProportions = 'tab_page_proportions_';
  static const String _prefixWindowBounds = 'tab_window_bounds_';
  static const String _prefixAlwaysOnTop = 'tab_always_on_top_';

  /// Obtém se uma aba deve abrir como janela
  /// Retorna false se não houver configuração salva
  Future<bool> getOpenAsWindow(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_prefixOpenAsWindow$tabId') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Salva se uma aba deve abrir como janela
  Future<void> setOpenAsWindow(String tabId, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefixOpenAsWindow$tabId', value);
    } catch (e) {
      // Ignora erros ao salvar
    }
  }

  /// Remove a configuração de uma aba (quando a aba é deletada)
  Future<void> removeTabSettings(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefixOpenAsWindow$tabId');
      await prefs.remove('$_prefixAlwaysOnTop$tabId');
    } catch (e) {
      // Ignora erros ao remover
    }
  }
  
  /// Obtém se uma janela deve ficar sempre no topo
  /// Retorna false se não houver configuração salva
  Future<bool> getAlwaysOnTop(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_prefixAlwaysOnTop$tabId') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Salva se uma janela deve ficar sempre no topo
  Future<void> setAlwaysOnTop(String tabId, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefixAlwaysOnTop$tabId', value);
    } catch (e) {
      // Ignora erros ao salvar
    }
  }
  
  /// Obtém todas as configurações de always on top
  /// Retorna um Map com tabId -> bool
  Future<Map<String, bool>> getAllAlwaysOnTopSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefixAlwaysOnTop));
      final Map<String, bool> settings = {};
      
      for (final key in keys) {
        final tabId = key.substring(_prefixAlwaysOnTop.length);
        final value = prefs.getBool(key) ?? false;
        settings[tabId] = value;
      }
      
      return settings;
    } catch (e) {
      return {};
    }
  }

  /// Obtém todas as configurações de abrir como janela
  /// Retorna um Map com tabId -> bool
  Future<Map<String, bool>> getAllOpenAsWindowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefixOpenAsWindow));
      final Map<String, bool> settings = {};
      
      for (final key in keys) {
        final tabId = key.substring(_prefixOpenAsWindow.length);
        final value = prefs.getBool(key) ?? false;
        settings[tabId] = value;
      }
      
      return settings;
    } catch (e) {
      return {};
    }
  }

  /// ✅ Salva as proporções das páginas de uma aba
  /// Proportions: Map com 'columns' e 'rows', cada um sendo uma lista de doubles
  Future<void> savePageProportions(String tabId, Map<String, List<double>> proportions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode({
        'columns': proportions['columns'],
        'rows': proportions['rows'],
      });
      await prefs.setString('$_prefixPageProportions$tabId', json);
    } catch (e) {
      // Ignora erros ao salvar
    }
  }

  /// ✅ Carrega as proporções das páginas de uma aba
  /// Retorna null se não houver configuração salva
  Future<Map<String, List<double>>?> getPageProportions(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_prefixPageProportions$tabId');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'columns': (json['columns'] as List).map((e) => (e as num).toDouble()).toList(),
        'rows': (json['rows'] as List).map((e) => (e as num).toDouble()).toList(),
      };
    } catch (e) {
      return null;
    }
  }

  /// ✅ Remove as proporções de uma aba (quando a aba é deletada)
  Future<void> removePageProportions(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefixPageProportions$tabId');
    } catch (e) {
      // Ignora erros ao remover
    }
  }

  /// ✅ Salva o tamanho e posição de uma janela
  /// Bounds: Map com 'x', 'y', 'width', 'height', 'isMaximized'
  /// ✅ IMPORTANTE: Sempre sobrescreve a posição anterior (garante apenas uma posição por janela)
  Future<void> saveWindowBounds(String tabId, Map<String, dynamic> bounds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(bounds);
      
      // ✅ Sempre sobrescreve a posição anterior (setString sobrescreve automaticamente)
      // ✅ Isso garante que apenas a última posição seja mantida
      await prefs.setString('$_prefixWindowBounds$tabId', json);
      
      // ✅ Verifica se foi salvo corretamente
      final saved = prefs.getString('$_prefixWindowBounds$tabId');
      if (saved == null || saved != json) {
        debugPrint('⚠️ Aviso: Posição pode não ter sido salva corretamente para $tabId');
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar posição da janela $tabId: $e');
      // ✅ Não ignora erros - loga para debug
    }
  }

  /// ✅ Carrega o tamanho e posição de uma janela
  /// Retorna null se não houver configuração salva
  Future<Map<String, dynamic>?> getWindowBounds(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_prefixWindowBounds$tabId');
      if (jsonString == null) return null;
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'x': json['x'] as double?,
        'y': json['y'] as double?,
        'width': json['width'] as double?,
        'height': json['height'] as double?,
        'isMaximized': json['isMaximized'] as bool? ?? false,
      };
    } catch (e) {
      return null;
    }
  }

  /// ✅ Remove as configurações de tamanho/posição de uma janela (quando a aba é deletada)
  Future<void> removeWindowBounds(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefixWindowBounds$tabId');
    } catch (e) {
      // Ignora erros ao remover
    }
  }

  /// ✅ Limpa TODAS as configurações locais salvas
  /// Remove: posições de telas, redimensionamento de páginas, configurações de abrir como janela, etc.
  Future<void> clearAllLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // ✅ Remove todas as chaves relacionadas a configurações locais
      for (final key in allKeys) {
        if (key.startsWith(_prefixOpenAsWindow) ||
            key.startsWith(_prefixPageProportions) ||
            key.startsWith(_prefixWindowBounds) ||
            key.startsWith(_prefixAlwaysOnTop)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('✅ Todas as configurações locais foram limpas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar configurações locais: $e');
    }
  }

  /// ✅ Limpa apenas as posições e tamanhos de janelas
  Future<void> clearWindowBounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (key.startsWith(_prefixWindowBounds)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('✅ Posições e tamanhos de janelas foram limpos');
    } catch (e) {
      debugPrint('❌ Erro ao limpar posições de janelas: $e');
    }
  }

  /// ✅ Limpa apenas as proporções de páginas
  Future<void> clearPageProportions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (key.startsWith(_prefixPageProportions)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('✅ Proporções de páginas foram limpas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar proporções de páginas: $e');
    }
  }

  /// ✅ Limpa apenas as configurações de abrir como janela
  Future<void> clearOpenAsWindowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      for (final key in allKeys) {
        if (key.startsWith(_prefixOpenAsWindow)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('✅ Configurações de abrir como janela foram limpas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar configurações de abrir como janela: $e');
    }
  }
}





