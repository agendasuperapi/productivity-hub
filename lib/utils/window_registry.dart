import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Registro de WindowControllers das janelas abertas
/// Permite focar janelas existentes usando o WindowController guardado
class WindowRegistry {
  // Guarda WindowController diretamente para poder focar janelas existentes
  static final Map<String, WindowController> _windows = {};

  /// Registra uma janela aberta associando tabId ao WindowController
  static void register(String tabId, WindowController controller) {
    _windows[tabId] = controller;
  }

  /// Obtém o WindowController de uma janela pelo tabId
  static WindowController? getController(String tabId) {
    return _windows[tabId];
  }

  /// Verifica se uma janela está registrada
  static bool isRegistered(String tabId) {
    return _windows.containsKey(tabId);
  }

  /// Remove o registro de uma janela (quando fechada)
  static void unregister(String tabId) {
    _windows.remove(tabId);
  }

  /// Limpa todos os registros
  static void clear() {
    _windows.clear();
  }
}

