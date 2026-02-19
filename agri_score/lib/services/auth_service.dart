import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication service using Supabase.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Current user session
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  String? get accessToken => currentSession?.accessToken;
  bool get isLoggedIn => currentSession != null;

  String get userId => currentUser?.id ?? '';
  String get userEmail => currentUser?.email ?? '';
  String get userName =>
      currentUser?.userMetadata?['name'] as String? ?? 'User';
  String get userRole =>
      currentUser?.userMetadata?['role'] as String? ?? 'farmer';

  /// Register a new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
    String role = 'farmer',
    String? phone,
    String? state,
    String? district,
    double? farmSize,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': role},
    );

    if (response.user != null) {
      // Store profile in users table
      await _client.from('users').insert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'phone': phone,
        'state': state,
        'district': district,
        'farm_size': farmSize,
        'role': role,
      });
    }

    return response;
  }

  /// Login with email/password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Get user role from users table
  Future<String> getUserRole(String userId) async {
    try {
      final resp = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      return resp['role'] as String? ?? 'farmer';
    } catch (e) {
      return 'farmer';
    }
  }

  /// Logout
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
