import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';

/// Shared data layer for the admin console. Every provider hits the `/admin`
/// namespace, which the API restricts to moderator and admin accounts.
class AdminRepository {
  AdminRepository(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<Map<String, dynamic>> _map(Future<dynamic> request) async => Map<String, dynamic>.from(await request as Map);
  Future<List<Map<String, dynamic>>> _list(Future<dynamic> request) async =>
      (await request as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

  Future<Map<String, dynamic>> overview() => _map(_api.get('/admin/overview'));
  Future<Map<String, dynamic>> analytics({int days = 14}) => _map(_api.get('/admin/analytics', query: {'days': days}));
  Future<Map<String, dynamic>> session() => _map(_api.get('/admin/me'));

  Future<Map<String, dynamic>> users({String? query, String? status, int page = 0}) => _map(_api.get('/admin/users', query: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
      }));
  Future<Map<String, dynamic>> user(String id) => _map(_api.get('/admin/users/$id'));
  Future<void> ban(String id, String reason, {int? durationHours}) =>
      _api.post('/admin/users/$id/ban', data: {'reason': reason, if (durationHours != null) 'durationHours': durationHours});
  Future<void> unban(String id, {String? reason}) => _api.post('/admin/users/$id/unban', data: {if (reason != null && reason.isNotEmpty) 'reason': reason});
  Future<void> setRole(String id, String role) => _api.patch('/admin/users/$id', data: {'role': role});
  Future<void> adjustWallet(String id, String currency, int amount, String reason) =>
      _api.post('/admin/users/$id/wallet', data: {'currency': currency, 'amount': amount, 'reason': reason});

  Future<List<Map<String, dynamic>>> shop({String? query}) => _list(_api.get('/admin/shop', query: {if (query != null && query.isNotEmpty) 'q': query}));
  Future<void> createShopItem(Map<String, dynamic> payload) => _api.post('/admin/shop', data: payload);
  Future<void> updateShopItem(String id, Map<String, dynamic> payload) => _api.patch('/admin/shop/$id', data: payload);
  Future<void> toggleShopItem(String id, bool isActive) => _api.patch('/admin/shop/$id/active', data: {'isActive': isActive});
  Future<Map<String, dynamic>> deleteShopItem(String id) => _map(_api.delete('/admin/shop/$id'));

  Future<List<Map<String, dynamic>>> games() => _list(_api.get('/admin/games'));
  Future<void> toggleGame(String id, bool isActive) => _api.patch('/admin/games/$id', data: {'isActive': isActive});
  Future<void> bulkToggleGames(List<String> ids, bool isActive) => _api.patch('/admin/games/bulk', data: {'gameIds': ids, 'isActive': isActive});

  Future<Map<String, dynamic>> reports({String? status, int page = 0}) =>
      _map(_api.get('/admin/reports', query: {if (status != null && status.isNotEmpty) 'status': status, 'page': page}));
  Future<List<Map<String, dynamic>>> reportNotes(String id) => _list(_api.get('/admin/reports/$id/notes'));
  Future<void> addReportNote(String id, String body) => _api.post('/admin/reports/$id/notes', data: {'body': body});
  Future<void> resolveReport(String id, {required String status, String? note, String action = 'none', int? banDurationHours}) =>
      _api.patch('/admin/reports/$id', data: {
        'status': status,
        if (note != null && note.isNotEmpty) 'resolutionNote': note,
        'action': action,
        if (banDurationHours != null) 'banDurationHours': banDurationHours,
      });

  Future<List<Map<String, dynamic>>> seasons() => _list(_api.get('/admin/seasons'));
  Future<void> createSeason(String name, DateTime startsAt, DateTime endsAt) =>
      _api.post('/admin/seasons', data: {'name': name, 'startsAt': startsAt.toUtc().toIso8601String(), 'endsAt': endsAt.toUtc().toIso8601String()});
  Future<void> activateSeason(String id) => _api.post('/admin/seasons/$id/activate');
  Future<void> finishSeason(String id) => _api.post('/admin/seasons/$id/finish');
  Future<List<Map<String, dynamic>>> rewards(String seasonId) => _list(_api.get('/admin/seasons/$seasonId/rewards'));
  Future<void> createReward(String seasonId, Map<String, dynamic> payload) => _api.post('/admin/seasons/$seasonId/rewards', data: payload);
  Future<void> deleteReward(String rewardId) => _api.delete('/admin/seasons/rewards/$rewardId');

  Future<List<Map<String, dynamic>>> auditLog() => _list(_api.get('/admin/audit'));
}

final adminRepositoryProvider = Provider<AdminRepository>(AdminRepository.new);

final adminOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(adminRepositoryProvider).overview());
final adminAnalyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, days) => ref.watch(adminRepositoryProvider).analytics(days: days));

/// Search text and status filter driving the user management tab.
final adminUserQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final adminUserStatusProvider = StateProvider.autoDispose<String>((ref) => '');
final adminUsersProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) =>
    ref.watch(adminRepositoryProvider).users(query: ref.watch(adminUserQueryProvider), status: ref.watch(adminUserStatusProvider)));

final adminShopQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final adminShopProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.watch(adminRepositoryProvider).shop(query: ref.watch(adminShopQueryProvider)));

final adminGamesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.watch(adminRepositoryProvider).games());

final adminReportStatusProvider = StateProvider.autoDispose<String>((ref) => 'open');
final adminReportsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(adminRepositoryProvider).reports(status: ref.watch(adminReportStatusProvider)));

final adminSeasonsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.watch(adminRepositoryProvider).seasons());
final adminSeasonRewardsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) => ref.watch(adminRepositoryProvider).rewards(id));

/// Full profile for the detail sheet, keyed by user id so it is cached per user
/// instead of being rebuilt on every widget rebuild.
final adminUserDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) => ref.watch(adminRepositoryProvider).user(id));

final adminReportNotesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) => ref.watch(adminRepositoryProvider).reportNotes(id));

final adminAuditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.watch(adminRepositoryProvider).auditLog());
