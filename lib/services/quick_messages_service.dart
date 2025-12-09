import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quick_message.dart';

/// Serviço para gerenciar mensagens rápidas
class QuickMessagesService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'quick_messages';

  /// Busca todas as mensagens rápidas do usuário
  Future<List<QuickMessage>> getAllMessages() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => QuickMessage.fromMap(json))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar mensagens rápidas: $e');
      return [];
    }
  }

  /// Busca uma mensagem pelo atalho
  Future<QuickMessage?> getMessageByShortcut(String shortcut) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('shortcut', shortcut.toLowerCase())
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return QuickMessage.fromMap(response);
    } catch (e) {
      debugPrint('Erro ao buscar mensagem por atalho: $e');
      return null;
    }
  }

  /// Salva uma nova mensagem rápida
  Future<QuickMessage?> saveMessage(QuickMessage message) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final data = message.toMap();
      data['user_id'] = userId;

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      return QuickMessage.fromMap(response);
    } catch (e) {
      debugPrint('Erro ao salvar mensagem rápida: $e');
      return null;
    }
  }

  /// Atualiza uma mensagem rápida existente
  Future<QuickMessage?> updateMessage(QuickMessage message) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final data = message.copyWith(updatedAt: DateTime.now()).toMap();
      data.remove('id'); // Remove id do update
      data.remove('created_at'); // Não atualiza created_at

      final response = await _supabase
          .from(_tableName)
          .update(data)
          .eq('id', message.id)
          .eq('user_id', userId)
          .select()
          .single();

      return QuickMessage.fromMap(response);
    } catch (e) {
      debugPrint('Erro ao atualizar mensagem rápida: $e');
      return null;
    }
  }

  /// Deleta uma mensagem rápida
  Future<bool> deleteMessage(String messageId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', messageId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Erro ao deletar mensagem rápida: $e');
      return false;
    }
  }

  /// Verifica se um atalho já existe
  Future<bool> shortcutExists(String shortcut, {String? excludeId}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      var query = _supabase
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('shortcut', shortcut.toLowerCase());

      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Erro ao verificar se atalho existe: $e');
      return false;
    }
  }
}

