import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Serviço para gerenciar configurações locais de abas
/// Armazena configurações que não devem ser sincronizadas com o Supabase
class LocalTabSettingsService {
  static const String _prefixOpenAsWindow = 'tab_open_as_window_';
  static const String _prefixPageProportions = 'tab_page_proportions_';
  static const String _prefixWindowBounds = 'tab_window_bounds_';

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
    } catch (e) {
      // Ignora erros ao remover
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
  Future<void> saveWindowBounds(String tabId, Map<String, dynamic> bounds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(bounds);
      await prefs.setString('$_prefixWindowBounds$tabId', json);
    } catch (e) {
      // Ignora erros ao salvar
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
}





