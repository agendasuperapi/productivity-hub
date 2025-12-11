import 'package:flutter/foundation.dart';
import '../models/quick_message.dart';
import 'quick_messages_service.dart';

/// Serviço global singleton para gerenciar mensagens rápidas em cache
/// Todas as abas e janelas podem acessar as mensagens rápidas através deste serviço
class GlobalQuickMessagesService extends ChangeNotifier {
  // Instância singleton
  static final GlobalQuickMessagesService _instance = GlobalQuickMessagesService._internal();
  factory GlobalQuickMessagesService() => _instance;
  GlobalQuickMessagesService._internal();

  final QuickMessagesService _service = QuickMessagesService();
  List<QuickMessage> _cachedMessages = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  /// Obtém as mensagens rápidas do cache (síncrono)
  List<QuickMessage> get messages => List.unmodifiable(_cachedMessages);

  /// Verifica se as mensagens já foram carregadas
  bool get isInitialized => _isInitialized;

  /// Carrega as mensagens rápidas do Supabase e atualiza o cache
  /// Deve ser chamado uma vez no início do aplicativo
  Future<void> loadMessages() async {
    if (_isLoading) {
      debugPrint('[GlobalQuickMessages] ⏳ Já está carregando mensagens...');
      return;
    }

    _isLoading = true;
    try {
      debugPrint('[GlobalQuickMessages] 📥 Carregando mensagens rápidas do Supabase...');
      _cachedMessages = await _service.getAllMessages();
      _isInitialized = true;
      debugPrint('[GlobalQuickMessages] ✅ Mensagens rápidas carregadas: ${_cachedMessages.length}');
      if (_cachedMessages.isNotEmpty) {
        debugPrint('[GlobalQuickMessages]   └─ Atalhos: ${_cachedMessages.map((m) => m.shortcut).join(", ")}');
      }
      notifyListeners(); // ✅ Notifica listeners sobre mudança
    } catch (e) {
      debugPrint('[GlobalQuickMessages] ❌ Erro ao carregar mensagens rápidas: $e');
      _cachedMessages = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Recarrega as mensagens rápidas (útil após criar/editar/deletar)
  Future<void> refreshMessages() async {
    _isLoading = true;
    try {
      debugPrint('[GlobalQuickMessages] 🔄 Recarregando mensagens rápidas...');
      _cachedMessages = await _service.getAllMessages();
      debugPrint('[GlobalQuickMessages] ✅ Mensagens rápidas recarregadas: ${_cachedMessages.length}');
      notifyListeners(); // ✅ Notifica listeners sobre mudança
    } catch (e) {
      debugPrint('[GlobalQuickMessages] ❌ Erro ao recarregar mensagens rápidas: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Adiciona uma mensagem ao cache (após salvar)
  void addMessage(QuickMessage message) {
    _cachedMessages.add(message);
    debugPrint('[GlobalQuickMessages] ➕ Mensagem adicionada ao cache: ${message.shortcut}');
    notifyListeners(); // ✅ Notifica listeners sobre mudança
  }

  /// Atualiza uma mensagem no cache (após editar)
  void updateMessage(QuickMessage message) {
    final index = _cachedMessages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      _cachedMessages[index] = message;
      debugPrint('[GlobalQuickMessages] ✏️ Mensagem atualizada no cache: ${message.shortcut}');
      notifyListeners(); // ✅ Notifica listeners sobre mudança
    }
  }

  /// Remove uma mensagem do cache (após deletar)
  void removeMessage(String messageId) {
    _cachedMessages.removeWhere((m) => m.id == messageId);
    debugPrint('[GlobalQuickMessages] ➖ Mensagem removida do cache: $messageId');
    notifyListeners(); // ✅ Notifica listeners sobre mudança
  }

  /// Limpa o cache (útil ao fazer logout)
  void clearCache() {
    _cachedMessages = [];
    _isInitialized = false;
    debugPrint('[GlobalQuickMessages] 🗑️ Cache limpo');
    notifyListeners(); // ✅ Notifica listeners sobre mudança
  }
}





