import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de autenticação com Supabase
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Retorna o usuário atual
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream de mudanças de autenticação
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Verifica se o usuário está autenticado
  bool get isAuthenticated => currentUser != null;

  /// Faz login com email e senha
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Cria uma nova conta com nome, email e senha
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
      },
    );

    // Atualiza o perfil do usuário com o nome
    if (response.user != null) {
      await _supabase.from('profiles').upsert({
        'id': response.user!.id,
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    return response;
  }

  /// Faz logout
  /// Usa SignOutScope.global para garantir que o logout seja completo
  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.global);
  }

  /// Redefine a senha
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}

