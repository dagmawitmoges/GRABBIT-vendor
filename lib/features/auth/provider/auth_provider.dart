import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final authListenerProvider = Provider<AuthListener>((ref) {
  return AuthListener(ref);
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isInitialized;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isInitialized = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isInitialized,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final token = await SecureStorage.getAccessToken();

    state = state.copyWith(
      isAuthenticated: token != null,
      isInitialized: true,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final res = await DioClient.instance.post(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      final user = res.data['user'];

      if (user == null || user['role'] != 'VENDOR') {
        throw Exception('Please sign in with a vendor account.');
      }

      await SecureStorage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearTokens();
    state = AuthState(isAuthenticated: false, isInitialized: true);
  }
}

class AuthListener extends ChangeNotifier {
  AuthListener(this.ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref ref;
}