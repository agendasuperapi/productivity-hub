import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciar perfil do usuário
class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtém o perfil do usuário atual
  Future<Map<String, dynamic>?> getProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      // Se não encontrar perfil, retorna dados básicos do usuário
      return {
        'id': user.id,
        'name': user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'Usuário',
        'email': user.email ?? '',
        'avatar_url': null,
      };
    }
  }

  /// Atualiza o nome do usuário
  Future<void> updateName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    await _supabase.from('profiles').upsert({
      'id': user.id,
      'name': name,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Atualiza também no userMetadata
    await _supabase.auth.updateUser(
      UserAttributes(data: {'name': name}),
    );
  }

  /// Faz upload da foto de perfil
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    try {
      // Gera nome único para o arquivo
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Faz upload para o storage do Supabase
      await _supabase.storage.from('avatars').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      // Obtém URL pública da imagem
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName).replaceAll(' ', '%20');

      // Atualiza o perfil com a URL da foto
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      throw Exception('Erro ao fazer upload da foto: $e');
    }
  }

  /// Remove a foto de perfil
  Future<void> removeProfilePhoto() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final profile = await getProfile();
    if (profile?['avatar_url'] != null) {
      // Extrai o nome do arquivo da URL
      final url = profile!['avatar_url'] as String;
      // Tenta extrair o nome do arquivo da URL
      final parts = url.split('/avatars/');
      if (parts.length > 1) {
        final fileName = parts[1].split('?').first;
        
        // Remove do storage
        try {
          await _supabase.storage.from('avatars').remove([fileName]);
        } catch (e) {
          // Ignora erro se arquivo não existir
          debugPrint('Erro ao remover arquivo do storage: $e');
        }
      }
    }

    // Remove URL do perfil
    await _supabase.from('profiles').upsert({
      'id': user.id,
      'avatar_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Seleciona imagem da galeria
  Future<File?> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return null;
    return File(image.path);
  }

  /// Seleciona imagem da câmera
  Future<File?> pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return null;
    return File(image.path);
  }

  /// Redefine a senha do usuário
  Future<void> updatePassword(String newPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}

