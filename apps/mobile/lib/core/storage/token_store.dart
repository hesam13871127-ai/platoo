import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? secureStorage}) : _secure = secureStorage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _secure;
  static const _accessKey = 'vibetable.access';
  static const _refreshKey = 'vibetable.refresh';
  static const _userKey = 'vibetable.user';

  Future<void> saveSession(AuthSession session) async { await _secure.write(key: _accessKey, value: session.accessToken); await _secure.write(key: _refreshKey, value: session.refreshToken); final prefs = await SharedPreferences.getInstance(); await prefs.setString(_userKey, jsonEncode({'user': _userToJson(session.user), 'expiresAt': session.expiresAt.toIso8601String()})); }
  Future<String?> accessToken() => _secure.read(key: _accessKey);
  Future<String?> refreshToken() => _secure.read(key: _refreshKey);
  Future<void> saveTokens(String access, String refresh) async { await _secure.write(key: _accessKey, value: access); await _secure.write(key: _refreshKey, value: refresh); }
  Future<void> clear() async { await _secure.delete(key: _accessKey); await _secure.delete(key: _refreshKey); final prefs = await SharedPreferences.getInstance(); await prefs.remove(_userKey); }
  Future<UserProfile?> cachedUser() async { final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString(_userKey); if (raw == null) return null; try { return UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw)['user'] as Map)); } catch (_) { return null; } }
  Map<String, dynamic> _userToJson(UserProfile user) => {'id': user.id, 'username': user.username, 'displayName': user.displayName, 'phone': user.phone, 'email': user.email, 'avatarUrl': user.avatarUrl, 'locale': user.locale == AppLocale.fa ? 'fa' : 'en', 'theme': user.theme.name, 'role': user.role, 'level': user.level, 'experience': user.experience, 'coins': user.coins, 'pips': user.pips};
}
