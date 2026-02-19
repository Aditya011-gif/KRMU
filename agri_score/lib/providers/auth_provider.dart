import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

/// Global auth service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Global API service provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String role;
  final String? error;
  final String? accessToken;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.email,
    this.role = 'farmer',
    this.error,
    this.accessToken,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? role,
    String? error,
    String? accessToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      error: error,
      accessToken: accessToken ?? this.accessToken,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = _authService.currentSession;
    if (session != null) {
      final role = await _authService.getUserRole(_authService.userId);
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: _authService.userId,
        email: _authService.userEmail,
        role: role,
        accessToken: session.accessToken,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    String role = 'farmer',
    String? phone,
    String? state_,
    String? district,
    double? farmSize,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
        state: state_,
        district: district,
        farmSize: farmSize,
      );
      if (response.session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          userId: response.user?.id,
          email: email,
          role: role,
          accessToken: response.session!.accessToken,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Please verify your email to login.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      if (response.session != null) {
        final role = await _authService.getUserRole(response.user!.id);
        state = AuthState(
          status: AuthStatus.authenticated,
          userId: response.user?.id,
          email: email,
          role: role,
          accessToken: response.session!.accessToken,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Invalid email or password',
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});
