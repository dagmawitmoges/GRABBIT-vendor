import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/login_identifier.dart';
import '../../../core/config/env.dart';
import '../../../core/data/supabase_vendor_data.dart';
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
    if (Env.hasSupabase) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await SecureStorage.saveTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
        );
        state = state.copyWith(
          isAuthenticated: true,
          isInitialized: true,
        );
        return;
      }
    }

    final token = await SecureStorage.getAccessToken();

    state = state.copyWith(
      isAuthenticated: token != null,
      isInitialized: true,
    );
  }

  Future<void> login(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final trimmed = emailOrPhone.trim();

      if (Env.hasSupabase) {
        final AuthResponse res;
        if (LoginIdentifier.isEmail(trimmed)) {
          res = await Supabase.instance.client.auth.signInWithPassword(
            email: trimmed,
            password: password,
          );
        } else {
          final phone = LoginIdentifier.normalizeToE164(trimmed);
          if (phone == null) {
            state = state.copyWith(isLoading: false);
            throw Exception(
              LoginIdentifier.validationError(trimmed) ?? 'Invalid phone number.',
            );
          }
          res = await Supabase.instance.client.auth.signInWithPassword(
            phone: phone,
            password: password,
          );
        }

        final session = res.session;
        if (session == null) {
          throw Exception('Sign-in did not return a session.');
        }

        final u = res.user;
        if (!await _isVendorAccount(u)) {
          await Supabase.instance.client.auth.signOut();
          throw Exception(
            'This account is not a vendor. Set `profiles.role` to VENDOR for this '
            'user in Supabase (SQL or Dashboard), or set role in Auth user_metadata.',
          );
        }

        await SecureStorage.saveTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
        );
      } else {
        final body = <String, dynamic>{'password': password};
        if (LoginIdentifier.isEmail(trimmed)) {
          body['email'] = trimmed;
        } else {
          final phone = LoginIdentifier.normalizeToE164(trimmed);
          if (phone == null) {
            state = state.copyWith(isLoading: false);
            throw Exception(
              LoginIdentifier.validationError(trimmed) ?? 'Invalid phone number.',
            );
          }
          body['phone'] = phone;
        }

        final res = await DioClient.instance.post(
          '/api/auth/login',
          data: body,
        );

        final user = res.data['user'];

        if (user == null || user['role'] != 'VENDOR') {
          throw Exception('Please sign in with a vendor account.');
        }

        await SecureStorage.saveTokens(
          accessToken: res.data['accessToken'],
          refreshToken: res.data['refreshToken'],
        );
      }

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        isInitialized: true,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception(e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      if (e is DioException && e.type == DioExceptionType.connectionError) {
        if (kIsWeb) {
          throw Exception(
            'Could not reach ${Env.baseUrl} (REST / Node login, not Supabase). '
            'On web, enable CORS on that server, or set SUPABASE_URL and '
            'SUPABASE_ANON_KEY in .env.example to use Supabase auth. '
            'Confirm the API process is running.',
          );
        }
        throw Exception(
          'Could not reach the API (${Env.baseUrl}). '
          'Is the backend running and reachable from this device?',
        );
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    if (Env.hasSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
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

Future<bool> _isVendorAccount(User? user) async {
  final id = user?.id;
  if (id == null) return false;
  try {
    if (await SupabaseVendorData.isVendorProfile(id)) return true;
  } catch (_) {}
  return _metadataSaysVendor(user);
}

bool _metadataSaysVendor(User? u) {
  if (u == null) return false;
  const keys = ['role', 'user_role', 'userType', 'type', 'account_type'];
  for (final key in keys) {
    final raw = u.appMetadata[key] ?? u.userMetadata?[key];
    if (raw == null) continue;
    final normalized = raw.toString().toUpperCase().replaceAll(RegExp(r'[\s-]'), '_');
    if (normalized == 'VENDOR' || normalized == 'VENDORS') return true;
  }
  return false;
}