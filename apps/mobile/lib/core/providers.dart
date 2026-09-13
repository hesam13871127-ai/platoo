import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStoreProvider)));

class SettingsController extends Notifier<({AppLocale locale, ThemeChoice theme})> {
  @override ({AppLocale locale, ThemeChoice theme}) build() => (locale: AppLocale.en, theme: ThemeChoice.system);
  void setLocale(AppLocale locale) => state = (locale: locale, theme: state.theme);
  void setTheme(ThemeChoice theme) => state = (locale: state.locale, theme: theme);
}
final settingsProvider = NotifierProvider<SettingsController, ({AppLocale locale, ThemeChoice theme})>(SettingsController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  late final ApiClient _api;
  @override Future<AuthSession?> build() async { _api = ref.watch(apiClientProvider); final cached = await ref.read(tokenStoreProvider).cachedUser(); final token = await ref.read(tokenStoreProvider).accessToken(); if (cached == null || token == null) return null; try { final data = await _api.get('/users/me') as Map; return AuthSession(accessToken: token, refreshToken: await ref.read(tokenStoreProvider).refreshToken() ?? '', expiresAt: DateTime.now().add(const Duration(minutes: 15)), user: UserProfile.fromJson(Map<String, dynamic>.from(data))); } catch (_) { await ref.read(tokenStoreProvider).clear(); return null; } }
  Future<Map<String, dynamic>> requestOtp(String phone) async => Map<String, dynamic>.from(await _api.post('/auth/otp/request', data: {'phone': phone}) as Map);
  Future<void> verifyOtp(String challengeId, String code) async { state = const AsyncLoading(); state = await AsyncValue.guard(() async { final data = await _api.post('/auth/otp/verify', data: {'challengeId': challengeId, 'code': code}) as Map; final session = AuthSession.fromJson(Map<String, dynamic>.from(data)); await ref.read(tokenStoreProvider).saveSession(session); return session; }); }
  Future<void> social(String provider, String token, {String? displayName}) async { state = const AsyncLoading(); state = await AsyncValue.guard(() async { final data = await _api.post('/auth/social', data: {'provider': provider, 'token': token, if (displayName != null) 'displayName': displayName}) as Map; final session = AuthSession.fromJson(Map<String, dynamic>.from(data)); await ref.read(tokenStoreProvider).saveSession(session); return session; }); }
  Future<void> refreshProfile() async {
    final current = state.value;
    if (current == null) return;
    try {
      final data = await _api.get('/users/me') as Map;
      final user = UserProfile.fromJson(Map<String, dynamic>.from(data));
      final refreshed = AuthSession(accessToken: current.accessToken, refreshToken: current.refreshToken, expiresAt: current.expiresAt, user: user);
      state = AsyncData(refreshed);
      await ref.read(tokenStoreProvider).saveSession(refreshed);
    } catch (_) {
      // A completed match remains valid even if the profile refresh is temporarily unavailable.
    }
  }
  Future<void> logout() async { await _api.post('/auth/logout'); await ref.read(tokenStoreProvider).clear(); state = const AsyncData(null); }
  Future<void> updatePreferences({AppLocale? locale, ThemeChoice? theme}) async { final payload = <String, dynamic>{if (locale != null) 'locale': locale == AppLocale.fa ? 'fa' : 'en', if (theme != null) 'theme': theme.name}; final data = await _api.put('/auth/preferences', data: payload) as Map; final current = state.value; if (current != null) { final user = UserProfile.fromJson(Map<String, dynamic>.from(data)); state = AsyncData(AuthSession(accessToken: current.accessToken, refreshToken: current.refreshToken, expiresAt: current.expiresAt, user: user)); await ref.read(tokenStoreProvider).saveSession(state.value!); } }
}
final authProvider = AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
