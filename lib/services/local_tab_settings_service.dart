import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para gerenciar configurações locais de abas
/// Armazena configurações que não devem ser sincronizadas com o Supabase
class LocalTabSettingsService {
  static const String _prefixOpenAsWindow = 'tab_open_as_window_';

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
}





