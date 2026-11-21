import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:avijit_sahyog/core/network/api_client.dart';
import 'package:avijit_sahyog/features/admin/data/admin_users_repository.dart';
import 'package:avijit_sahyog/features/admin/models/admin_audit_entry.dart';
import 'package:avijit_sahyog/features/admin/models/admin_user.dart';
import 'package:avijit_sahyog/features/admin/models/paginated_admin_users.dart';
import 'package:avijit_sahyog/features/admin/presentation/admin_users_page.dart';
import 'package:avijit_sahyog/features/admin/providers/admin_users_providers.dart';
import 'package:avijit_sahyog/features/community/models/city.dart';
import 'package:avijit_sahyog/features/community/providers/city_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

class _FakeAdminUsersRepository extends AdminUsersRepository {
  _FakeAdminUsersRepository() : super(ApiClient());

  final Map<String, AdminUser> users = {
    'city-user': AdminUser(
      id: 'city-user',
      displayName: 'Nikita Manoriya',
      email: 'nikita@example.com',
      role: 'USER',
      createdAt: DateTime.utc(2026, 9, 14),
    ),
  };
  final List<(String, List<String>)> cityAssignments = [];

  @override
  Future<PaginatedAdminUsers> getUsers({
    String? search,
    String role = 'ADMIN',
    int page = 1,
    int pageSize = 3,
  }) async {
    final query = search?.trim().toLowerCase() ?? '';
    final matching = users.values.where((user) {
      final roleMatches = role == 'ALL' || user.role == role;
      final searchMatches = query.isEmpty ||
          user.label.toLowerCase().contains(query) ||
          (user.email?.toLowerCase().contains(query) ?? false);
      return roleMatches && searchMatches;
    }).toList(growable: false);
    final start = (page - 1) * pageSize;
    final items = start >= matching.length
        ? const <AdminUser>[]
        : matching.skip(start).take(pageSize).toList(growable: false);
    return PaginatedAdminUsers(
      items: items,
      page: page,
      pageSize: pageSize,
      total: matching.length,
    );
  }

  @override
  Future<AdminUser> changeRole(
    String userId,
    String role, {
    List<String> cityIds = const [],
  }) async {
    final user = users[userId]!;
    final updated = AdminUser(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoUrl,
      role: role,
      cityIds: cityIds,
      createdAt: user.createdAt,
    );
    users[userId] = updated;
    if (role == 'CITY_ADMIN') cityAssignments.add((userId, cityIds));
    return updated;
  }

  @override
  Future<List<AdminAuditEntry>> getAuditHistory() async => const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Super Admin assigns a user to multiple localized cities', (tester) async {
    final repository = _FakeAdminUsersRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersRepositoryProvider.overrideWithValue(repository),
          adminUsersProvider.overrideWith(
            (ref, query) => repository.getUsers(
              search: query.search,
              role: query.role,
              page: query.page,
              pageSize: 3,
            ),
          ),
          adminAuditHistoryProvider.overrideWith((ref) => repository.getAuditHistory()),
          cityAdminsProvider.overrideWith(
            (ref) => repository.getUsers(role: 'CITY_ADMIN', page: 1, pageSize: 20),
          ),
          cityCatalogueProvider('hi').overrideWith(
            (ref) async => const [
              City(id: 'pune', name: 'पुणे'),
              City(id: 'mumbai', name: 'मुंबई'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('hi'),
          home: const AdminUsersPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.add_location_alt_rounded));
    await tester.tap(find.byIcon(Icons.add_location_alt_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikita Manoriya'));
    await tester.pumpAndSettle();

    expect(find.text('पुणे'), findsOneWidget);
    expect(find.text('मुंबई'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('city_assignment_pune')));
    await tester.tap(find.byKey(const ValueKey('city_assignment_mumbai')));
    await tester.pumpAndSettle();

    final saveButton = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(FilledButton),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.users['city-user']!.role, 'CITY_ADMIN');
    expect(repository.cityAssignments.single.$1, 'city-user');
    expect(repository.cityAssignments.single.$2, ['mumbai', 'pune']);
    expect(find.textContaining('मुंबई, पुणे'), findsOneWidget);
  });
}
