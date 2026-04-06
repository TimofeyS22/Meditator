import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditator/core/api/api_client.dart';
import 'package:meditator/core/storage/local_storage.dart';

enum AuthStatus { unknown, unauthenticated, onboarding, authenticated }

class AuthState {
  final AuthStatus status;
  final bool isOnboarded;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isOnboarded = false,
  });

  AuthState copyWith({AuthStatus? status, bool? isOnboarded}) {
    return AuthState(
      status: status ?? this.status,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}

class AuthService extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  Future<void> _init() async {
    final storage = ref.read(localStorageProvider);
    final api = ref.read(apiClientProvider);

    final onboarded = await storage.hasOnboarded;

    bool hasToken = false;
    try {
      hasToken = await api.hasTokens;
    } catch (_) {
      // Keychain unavailable (simulator / first launch)
    }

    if (!onboarded) {
      state = const AuthState(status: AuthStatus.onboarding);
    } else if (hasToken) {
      state = AuthState(status: AuthStatus.authenticated, isOnboarded: true);
    } else {
      state = AuthState(status: AuthStatus.unauthenticated, isOnboarded: true);
    }
  }

  Future<void> completeOnboarding() async {
    final storage = ref.read(localStorageProvider);
    await storage.setOnboarded();

    // Preserve authenticated status if user just registered/logged in
    final api = ref.read(apiClientProvider);
    bool hasToken = false;
    try { hasToken = await api.hasTokens; } catch (_) {}

    state = state.copyWith(
      status: hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      isOnboarded: true,
    );
  }

  Future<String?> login(String email, String password) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.login(email, password);
      state = state.copyWith(status: AuthStatus.authenticated);
      return null;
    } catch (e) {
      return 'Неверный email или пароль';
    }
  }

  Future<String?> register(String email, String password, {String? name}) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.register(email, password, name: name);
      state = state.copyWith(status: AuthStatus.authenticated);
      return null;
    } catch (e) {
      return 'Ошибка регистрации';
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    await api.logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthService, AuthState>(AuthService.new);
