import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';

// API Client
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Auth State
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.read(apiClientProvider));
});

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final Box _authBox = Hive.box('auth');

  AuthStateNotifier(this._api) : super(const AuthState()) {
    _checkAuth();
  }

  void _checkAuth() {
    final token = _authBox.get('accessToken');
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated);
      _loadProfile();
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _api.getProfile();
      if (response.data['success'] == true) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.data['data'],
        );
      }
    } catch (_) {
      // Token is expired and could not be refreshed — force re-login
      await _authBox.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> register(String email, String password, String fullName, String? phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.register({
        'email': email,
        'password': password,
        'full_name': fullName,
        if (phone != null) 'phone': phone,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _authBox.put('accessToken', data['access_token']);
        await _authBox.put('refreshToken', data['refresh_token']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: data['user'],
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: response.data['error'],
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.login({
        'email': email,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _authBox.put('accessToken', data['access_token']);
        await _authBox.put('refreshToken', data['refresh_token']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: data['user'],
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: response.data['error'],
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      return false;
    }
  }

  void updateUser(Map<String, dynamic> userData) {
    state = state.copyWith(user: userData);
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  Future<void> logout() async {
    final refreshToken = _authBox.get('refreshToken');
    if (refreshToken != null) {
      try {
        await _api.logout(refreshToken);
      } catch (_) {}
    }
    await _authBox.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// WebSocket
final wsProvider = Provider<WebSocketChannel?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.status != AuthStatus.authenticated) return null;

  final token = Hive.box('auth').get('accessToken');
  if (token == null) return null;

  final channel = WebSocketChannel.connect(
    Uri.parse('${AppConfig.wsUrl}?token=$token'),
  );

  ref.onDispose(() => channel.sink.close());
  return channel;
});

// Selected building
final selectedBuildingIdProvider = StateProvider<String?>((ref) => null);

// User buildings - loads all buildings and auto-selects the first one
final userBuildingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState.status != AuthStatus.authenticated) return [];

  final api = ref.read(apiClientProvider);
  try {
    final response = await api.getUserBuildings();
    if (response.data['success'] == true && response.data['data'] != null) {
      final buildings = (response.data['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      // Auto-select first building if none selected
      if (buildings.isNotEmpty) {
        final current = ref.read(selectedBuildingIdProvider);
        if (current == null) {
          // Use Future.microtask to avoid modifying provider during build
          Future.microtask(() {
            ref.read(selectedBuildingIdProvider.notifier).state =
                buildings.first['id'] as String;
          });
        }
      }
      return buildings;
    }
  } catch (_) {}
  return [];
});
