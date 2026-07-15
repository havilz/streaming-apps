import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State representasi status autentikasi pengguna.
class AuthState {
  const AuthState({
    required this.isLoggedIn,
    this.username,
    this.email,
  });

  factory AuthState.initial() => const AuthState(isLoggedIn: false);

  final bool isLoggedIn;
  final String? username;
  final String? email;

  AuthState copyWith({
    bool? isLoggedIn,
    String? username,
    String? email,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      email: email ?? this.email,
    );
  }
}

/// Notifier untuk mengelola alur state autentikasi di memori (frontend).
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.initial();

  void login(String username, String email) {
    state = AuthState(
      isLoggedIn: true,
      username: username,
      email: email,
    );
  }

  void signUp(String username, String email) {
    state = AuthState(
      isLoggedIn: true,
      username: username,
      email: email,
    );
  }

  void logout() {
    state = AuthState.initial();
  }
}

/// Provider global untuk memantau status autentikasi pengguna.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
