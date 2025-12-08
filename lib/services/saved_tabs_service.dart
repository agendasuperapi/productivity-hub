import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_tab.dart';

/// Serviço para gerenciar abas salvas no Supabase
class SavedTabsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtém todas as abas salvas do usuário atual, ordenadas
  Future<List<SavedTab>> getSavedTabs() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('saved_tabs')
        .select()
        .eq('user_id', userId)
        .order('tab_order', ascending: true);

    return (response as List)
        .map((tab) => SavedTab.fromMap(tab))
        .toList();
  }

  /// Salva uma nova aba
  Future<SavedTab> saveTab({
    required String name,
    String? url,
    List<String>? urls,
    int? columns,
    int? rows,
    bool? openAsWindow,
    File? iconFile,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Obtém a próxima ordem
    final existingTabs = await getSavedTabs();
    final nextOrder = existingTabs.isEmpty ? 0 : existingTabs.last.tabOrder + 1;

    // Faz upload do ícone se fornecido
    String? iconUrl;
    if (iconFile != null) {
      iconUrl = await _uploadIcon(iconFile, userId);
    }

    final now = DateTime.now();
    final newTab = SavedTab(
      userId: userId,
      name: name,
      url: url,
      urls: urls,
      columns: columns,
      rows: rows,
      iconUrl: iconUrl,
      openAsWindow: openAsWindow ?? false,
      tabOrder: nextOrder,
      createdAt: now,
      updatedAt: now,
    );

    final response = await _supabase
        .from('saved_tabs')
        .insert(newTab.toMap())
        .select()
        .single();

    return SavedTab.fromMap(Map<String, dynamic>.from(response));
  }

  /// Atualiza uma aba existente
  Future<SavedTab> updateTab({
    required String id,
    String? name,
    String? url,
    List<String>? urls,
    int? columns,
    int? rows,
    bool? openAsWindow,
    File? iconFile,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;
    if (url != null) updates['url'] = url;
    if (urls != null) updates['urls'] = urls;
    if (columns != null) updates['columns'] = columns;
    if (rows != null) updates['rows'] = rows;
    if (openAsWindow != null) updates['open_as_window'] = openAsWindow;
    // Se tem urls, remove url antiga (ou mantém primeira URL para compatibilidade)
    if (urls != null && urls.isNotEmpty) {
      updates['url'] = urls.first;
    }

    // Faz upload do novo ícone se fornecido
    if (iconFile != null) {
      final iconUrl = await _uploadIcon(iconFile, userId);
      updates['icon_url'] = iconUrl;
    }

    final response = await _supabase
        .from('saved_tabs')
        .update(updates)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();

    return SavedTab.fromMap(Map<String, dynamic>.from(response));
  }

  /// Deleta uma aba
  Future<void> deleteTab(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Obtém a aba para deletar o ícone se existir
    final tab = await _supabase
        .from('saved_tabs')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .single();

    if (tab['icon_url'] != null) {
      await _deleteIcon(tab['icon_url'] as String);
    }

    await _supabase
        .from('saved_tabs')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  /// Atualiza a ordem das abas
  Future<void> updateTabsOrder(List<String> tabIds) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Atualiza a ordem de cada aba
    for (int i = 0; i < tabIds.length; i++) {
      await _supabase
          .from('saved_tabs')
          .update({
            'tab_order': i,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tabIds[i])
          .eq('user_id', userId);
    }
  }

  /// Faz upload do ícone para o Supabase Storage
  Future<String> _uploadIcon(File iconFile, String userId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    // O caminho deve ser userId/fileName (o bucket já especifica 'tab-icons')
    final path = '$userId/$fileName';

    try {
      await _supabase.storage.from('tab-icons').upload(
        path,
        iconFile,
        fileOptions: FileOptions(
          contentType: 'image/png',
          upsert: false,
          cacheControl: '3600',
        ),
      );

      // Obtém a URL pública do arquivo
      final url = _supabase.storage.from('tab-icons').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Erro ao fazer upload do ícone: $e');
      debugPrint('Path usado: $path');
      debugPrint('UserId: $userId');
      rethrow;
    }
  }

  /// Deleta o ícone do Supabase Storage
  Future<void> _deleteIcon(String iconUrl) async {
    try {
      // Extrai o caminho da URL
      final uri = Uri.parse(iconUrl);
      final path = uri.pathSegments.last;
      final fullPath = 'tab-icons/${uri.pathSegments[uri.pathSegments.length - 2]}/$path';

      await _supabase.storage.from('tab-icons').remove([fullPath]);
    } catch (e) {
      // Ignora erros ao deletar ícone
      debugPrint('Erro ao deletar ícone: $e');
    }
  }
}

