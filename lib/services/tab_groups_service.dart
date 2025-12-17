import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tab_group.dart';

/// Serviço para gerenciar grupos de abas no Supabase
class TabGroupsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtém todos os grupos do usuário atual, ordenados
  Future<List<TabGroup>> getTabGroups() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('tab_groups')
        .select()
        .eq('user_id', userId)
        .order('group_order', ascending: true);

    return (response as List)
        .map((group) => TabGroup.fromMap(group))
        .toList();
  }

  /// Obtém um grupo por ID
  Future<TabGroup?> getTabGroupById(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('tab_groups')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .single();

      return TabGroup.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Cria um grupo padrão para o usuário (se não existir)
  Future<TabGroup> createDefaultGroup() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Verifica se já existe um grupo padrão
    final existingGroups = await getTabGroups();
    final defaultGroup = existingGroups.firstWhere(
      (group) => group.name == 'Geral',
      orElse: () => TabGroup(
        userId: userId,
        name: 'Geral',
        groupOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (defaultGroup.id == null) {
      // Cria o grupo padrão
      return await createGroup(name: 'Geral');
    }

    return defaultGroup;
  }

  /// Cria um novo grupo
  Future<TabGroup> createGroup({required String name}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Obtém a próxima ordem
    final existingGroups = await getTabGroups();
    final nextOrder = existingGroups.isEmpty ? 0 : existingGroups.last.groupOrder + 1;

    final now = DateTime.now();
    final newGroup = TabGroup(
      userId: userId,
      name: name,
      groupOrder: nextOrder,
      createdAt: now,
      updatedAt: now,
    );

    final response = await _supabase
        .from('tab_groups')
        .insert(newGroup.toMap())
        .select()
        .single();

    return TabGroup.fromMap(Map<String, dynamic>.from(response));
  }

  /// Atualiza um grupo existente
  Future<TabGroup> updateGroup({
    required String id,
    String? name,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;

    final response = await _supabase
        .from('tab_groups')
        .update(updates)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();

    return TabGroup.fromMap(Map<String, dynamic>.from(response));
  }

  /// Deleta um grupo
  Future<void> deleteGroup(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Primeiro, move todas as abas do grupo para o grupo padrão (Geral)
    final defaultGroup = await createDefaultGroup();
    
    await _supabase
        .from('saved_tabs')
        .update({'group_id': defaultGroup.id})
        .eq('group_id', id)
        .eq('user_id', userId);

    // Depois, deleta o grupo
    await _supabase
        .from('tab_groups')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// Reordena os grupos
  Future<void> reorderGroups(List<String> groupIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    for (int i = 0; i < groupIds.length; i++) {
      await _supabase
          .from('tab_groups')
          .update({'group_order': i})
          .eq('id', groupIds[i])
          .eq('user_id', userId);
    }
  }
}

