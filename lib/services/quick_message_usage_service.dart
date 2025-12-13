import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_message.dart';
import 'quick_messages_service.dart';

/// Serviço para gerenciar contadores locais de uso de mensagens rápidas
/// Incrementa localmente e só salva no banco quando chega a 10
class QuickMessageUsageService {
  static const String _prefix = 'qm_usage_local_';
  static const int _batchSize = 10; // ✅ Tamanho do lote para salvar no banco
  
  /// Incrementa o contador de uso de uma mensagem
  /// Retorna true se salvou no banco (quando chegou a 10), false caso contrário
  Future<bool> incrementUsage(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$messageId';
      
      // ✅ Lê contador local atual
      final currentLocalCount = prefs.getInt(key) ?? 0;
      final newLocalCount = currentLocalCount + 1;
      
      // ✅ Salva novo contador local
      await prefs.setInt(key, newLocalCount);
      
      debugPrint('[QuickMessageUsage] 📊 Mensagem $messageId: contador local = $newLocalCount');
      
      // ✅ Se chegou ao tamanho do lote, salva no banco
      if (newLocalCount >= _batchSize) {
        await _saveToDatabase(messageId, newLocalCount);
        // ✅ Reseta contador local após salvar
        await prefs.remove(key);
        debugPrint('[QuickMessageUsage] ✅ Salvo no banco: $messageId (+$newLocalCount)');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[QuickMessageUsage] ❌ Erro ao incrementar uso: $e');
      return false;
    }
  }
  
  /// Salva o contador no banco de dados
  Future<void> _saveToDatabase(String messageId, int countToAdd) async {
    try {
      final service = QuickMessagesService();
      
      // ✅ Usa método otimizado para incrementar contador
      final success = await service.incrementUsageCount(messageId, countToAdd);
      
      if (success) {
        debugPrint('[QuickMessageUsage] 💾 Banco atualizado: $messageId (+$countToAdd)');
      } else {
        debugPrint('[QuickMessageUsage] ⚠️ Falha ao atualizar banco: $messageId');
        // ✅ Se falhar, mantém o contador local para tentar novamente depois
      }
    } catch (e) {
      debugPrint('[QuickMessageUsage] ❌ Erro ao salvar no banco: $e');
      // ✅ Se falhar, mantém o contador local para tentar novamente depois
    }
  }
  
  /// Obtém o contador total (banco + local) de uma mensagem
  Future<int> getTotalUsageCount(QuickMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix${message.id}';
      final localCount = prefs.getInt(key) ?? 0;
      return message.usageCount + localCount;
    } catch (e) {
      debugPrint('[QuickMessageUsage] ❌ Erro ao obter contador total: $e');
      return message.usageCount;
    }
  }
  
  /// Obtém contadores locais de todas as mensagens
  Future<Map<String, int>> getAllLocalCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
      final Map<String, int> counts = {};
      
      for (final key in keys) {
        final messageId = key.substring(_prefix.length);
        final count = prefs.getInt(key) ?? 0;
        if (count > 0) {
          counts[messageId] = count;
        }
      }
      
      return counts;
    } catch (e) {
      debugPrint('[QuickMessageUsage] ❌ Erro ao obter contadores locais: $e');
      return {};
    }
  }
  
  /// Força salvamento de todos os contadores locais no banco
  Future<void> flushAllLocalCounts() async {
    try {
      final localCounts = await getAllLocalCounts();
      if (localCounts.isEmpty) return;
      
      final service = QuickMessagesService();
      final messages = await service.getAllMessages();
      
      for (final entry in localCounts.entries) {
        final messageId = entry.key;
        final localCount = entry.value;
        
        try {
          // ✅ Usa método otimizado para incrementar contador
          final success = await service.incrementUsageCount(messageId, localCount);
          
          if (success) {
            // ✅ Remove contador local após salvar
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('$_prefix$messageId');
            debugPrint('[QuickMessageUsage] 💾 Flush: $messageId (+$localCount)');
          }
        } catch (e) {
          debugPrint('[QuickMessageUsage] ⚠️ Erro ao fazer flush de $messageId: $e');
        }
      }
    } catch (e) {
      debugPrint('[QuickMessageUsage] ❌ Erro ao fazer flush de contadores: $e');
    }
  }
}

