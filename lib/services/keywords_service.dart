import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/keyword.dart';

/// Serviço para gerenciar palavras-chave customizáveis
class KeywordsService {
  /// ✅ Getter lazy que verifica se Supabase está inicializado antes de acessar
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase não inicializado: $e');
      return null;
    }
  }

  /// Obtém todas as palavras-chave do usuário
  Future<List<Keyword>> getAllKeywords() async {
    try {
      final supabase = _supabase;
      if (supabase == null) return [];
      
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('keywords')
          .select()
          .eq('user_id', userId)
          .order('key', ascending: true);

      if (response == null) return [];

      return (response as List)
          .map((item) => Keyword.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar palavras-chave: $e');
      return [];
    }
  }

  /// Salva uma nova palavra-chave
  Future<Keyword?> saveKeyword(Keyword keyword) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        throw Exception('Supabase não inicializado');
      }
      
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final response = await supabase
          .from('keywords')
          .insert({
            'user_id': userId, // ✅ Inclui user_id explicitamente
            'key': keyword.key.toUpperCase(), // Sempre salva em maiúsculas
            'value': keyword.value,
          })
          .select()
          .single();

      if (response == null) return null;

      return Keyword.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erro ao salvar palavra-chave: $e');
      return null;
    }
  }

  /// Atualiza uma palavra-chave existente
  Future<Keyword?> updateKeyword(Keyword keyword) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        throw Exception('Supabase não inicializado');
      }
      
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final response = await supabase
          .from('keywords')
          .update({
            'key': keyword.key.toUpperCase(), // Sempre salva em maiúsculas
            'value': keyword.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', keyword.id)
          .eq('user_id', userId) // ✅ Garante que só atualiza palavras-chave do usuário
          .select()
          .single();

      if (response == null) return null;

      return Keyword.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erro ao atualizar palavra-chave: $e');
      return null;
    }
  }

  /// Deleta uma palavra-chave
  Future<bool> deleteKeyword(String id) async {
    try {
      final supabase = _supabase;
      if (supabase == null) {
        throw Exception('Supabase não inicializado');
      }
      
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      await supabase
          .from('keywords')
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // ✅ Garante que só deleta palavras-chave do usuário
      return true;
    } catch (e) {
      debugPrint('Erro ao deletar palavra-chave: $e');
      return false;
    }
  }

  /// Verifica se uma chave já existe (para validação)
  Future<bool> keyExists(String key, {String? excludeId}) async {
    try {
      final supabase = _supabase;
      if (supabase == null) return false;
      
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      var query = supabase
          .from('keywords')
          .select('id')
          .eq('user_id', userId) // ✅ Filtra por usuário
          .eq('key', key.toUpperCase());

      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      final response = await query;
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Erro ao verificar se chave existe: $e');
      return false;
    }
  }

  /// Obtém todas as palavras-chave como um Map para substituição rápida
  Future<Map<String, String>> getKeywordsMap() async {
    try {
      final keywords = await getAllKeywords();
      final map = <String, String>{};
      
      for (final keyword in keywords) {
        // Armazena com < > para facilitar busca (formato usado nas mensagens)
        map['<${keyword.key.toUpperCase()}>'] = keyword.value;
      }
      
      return map;
    } catch (e) {
      debugPrint('Erro ao obter mapa de palavras-chave: $e');
      return {};
    }
  }
}

