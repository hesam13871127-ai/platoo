import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

// ---------------------------------------------------------------------------
// Parsing helpers (the API returns MySQL-flavoured numbers/booleans/dates).
// ---------------------------------------------------------------------------

int intOf(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool boolOf(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return value == '1' || lower == 'true';
  }
  return fallback;
}

String strOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

String dateLabel(dynamic value) {
  final text = strOf(value);
  if (text.length >= 10) return text.substring(0, 10);
  return text.isEmpty ? '—' : text;
}

/// Accepts both the paginated `{items: [...]}` shape and a legacy raw list.
List<Map<String, dynamic>> asItemList(dynamic data) {
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (data is Map) {
    final items = data['items'];
    if (items is List) {
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }
  return const [];
}

List<Map<String, dynamic>> asSeries(dynamic data) {
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return const [];
}

// ---------------------------------------------------------------------------
// Role helpers.
// ---------------------------------------------------------------------------

bool isAdminRole(String? role) => role == 'admin';

bool isStaffRole(String? role) => role == 'admin' || role == 'moderator';

// ---------------------------------------------------------------------------
// Mutation helper: runs an admin call and surfaces API errors as a snackbar.
// Returns the response on success, null on failure.
// ---------------------------------------------------------------------------

Future<T?> guardAdmin<T>(BuildContext context, Future<dynamic> Function() call) async {
  try {
    return await call();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return null;
  }
}

void showAdminMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// ---------------------------------------------------------------------------
// Providers.
// ---------------------------------------------------------------------------

final adminOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/overview') as Map;
  return Map<String, dynamic>.from(data);
});

final adminDaysProvider = StateProvider<int>((ref) => 30);

final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final days = ref.watch(adminDaysProvider);
  final data = await ref.watch(apiClientProvider).get('/admin/analytics', query: {'days': days}) as Map;
  return Map<String, dynamic>.from(data);
});

final adminRecentMatchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/matches/recent', query: {'limit': 12});
  return asItemList(data);
});

class AdminPage {
  const AdminPage({required this.items, required this.total, required this.page, required this.totalPages});
  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int totalPages;
}

// --- Users ---------------------------------------------------------------

final adminUserSearchProvider = StateProvider<String>((ref) => '');
final adminUserStatusProvider = StateProvider<String?>((ref) => null);
final adminUserRoleProvider = StateProvider<String?>((ref) => null);
final adminUserPageProvider = StateProvider<int>((ref) => 0);

final adminUsersProvider = FutureProvider<AdminPage>((ref) async {
  final q = ref.watch(adminUserSearchProvider);
  final status = ref.watch(adminUserStatusProvider);
  final role = ref.watch(adminUserRoleProvider);
  final page = ref.watch(adminUserPageProvider);
  final data = await ref.watch(apiClientProvider).get('/admin/users', query: {
    'q': q,
    'page': page,
    'limit': 20,
    if (status != null) 'status': status,
    if (role != null) 'role': role,
  }) as Map;
  final map = Map<String, dynamic>.from(data);
  return AdminPage(
    items: asItemList(map),
    total: intOf(map['total']),
    page: intOf(map['page']),
    totalPages: intOf(map['totalPages'], 1),
  );
});

final adminUserDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final data = await ref.watch(apiClientProvider).get('/admin/users/$userId') as Map;
  return Map<String, dynamic>.from(data);
});

// --- Shop ----------------------------------------------------------------

final adminShopProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/shop');
  return asItemList(data);
});

// --- Games ---------------------------------------------------------------

final adminGamesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/games');
  return asItemList(data);
});

// --- Reports -------------------------------------------------------------

final adminReportStatusProvider = StateProvider<String?>((ref) => 'open');
final adminReportPageProvider = StateProvider<int>((ref) => 0);

final adminReportsProvider = FutureProvider<AdminPage>((ref) async {
  final status = ref.watch(adminReportStatusProvider);
  final page = ref.watch(adminReportPageProvider);
  final data = await ref.watch(apiClientProvider).get('/admin/reports', query: {
    'page': page,
    'limit': 20,
    if (status != null) 'status': status,
  });
  if (data is List) {
    return AdminPage(items: asItemList(data), total: data.length, page: 0, totalPages: 1);
  }
  final map = Map<String, dynamic>.from(data as Map);
  return AdminPage(
    items: asItemList(map),
    total: intOf(map['total']),
    page: intOf(map['page']),
    totalPages: intOf(map['totalPages'], 1),
  );
});

final adminReportDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, reportId) async {
  final data = await ref.watch(apiClientProvider).get('/admin/reports/$reportId') as Map;
  return Map<String, dynamic>.from(data);
});

// --- Seasons -------------------------------------------------------------

final adminSeasonsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/seasons');
  return asItemList(data);
});

final adminSeasonDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, seasonId) async {
  final data = await ref.watch(apiClientProvider).get('/admin/seasons/$seasonId') as Map;
  return Map<String, dynamic>.from(data);
});

// --- Audit log -----------------------------------------------------------

final adminAuditPageProvider = StateProvider<int>((ref) => 0);

final adminAuditProvider = FutureProvider<AdminPage>((ref) async {
  final page = ref.watch(adminAuditPageProvider);
  final data = await ref.watch(apiClientProvider).get('/admin/audit-log', query: {'page': page, 'limit': 25}) as Map;
  final map = Map<String, dynamic>.from(data);
  return AdminPage(
    items: asItemList(map),
    total: intOf(map['total']),
    page: intOf(map['page']),
    totalPages: intOf(map['totalPages'], 1),
  );
});
