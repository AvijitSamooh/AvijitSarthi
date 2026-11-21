import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avijit_sahyog/core/network/api_client.dart';
import 'package:avijit_sahyog/features/admin/data/admin_users_repository.dart';
import 'package:avijit_sahyog/features/admin/models/admin_user.dart';
import 'package:avijit_sahyog/features/admin/models/paginated_admin_users.dart';
import 'package:avijit_sahyog/features/admin/presentation/admin_users_page.dart';
import 'package:avijit_sahyog/features/admin/providers/admin_users_providers.dart';
import 'package:avijit_sahyog/features/community/models/city.dart';
import 'package:avijit_sahyog/features/community/providers/city_providers.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

AdminUser _user(String id, String name, {String role = 'ADMIN', List<String> cityIds = const []}) => AdminUser(
      id: id,
      displayName: name,
      email: '$id@example.com',
      photoUrl: null,
      role: role,
      cityIds: cityIds,
      createdAt: DateTime.utc(2026, 9, 14),
    );

class _FakeAdminUsersRepository extends AdminUsersRepository {
  _FakeAdminUsersRepository({this.failRoleChange = false}) : super(ApiClient());

  bool failRoleChange;
  final Map<String, AdminUser> users = {
    'nikita-user': _user('nikita-user', 'Nikita Manoriya', role: 'USER'),
    'nikita-admin': _user('nikita-admin', 'Nikita Sharma', role: 'ADMIN'),
  };
  final List<(String userId, String role)> roleChanges = [];
  final List<(String userId, List<String> cityIds)> cityAssignmentChanges = [];

  @override
  Future<PaginatedAdminUsers> getUsers({
    String? search,
    String role = 'ADMIN',
    int page = 1,
    int pageSize = 3,
  }) async {
    final normalizedSearch = search?.trim().toLowerCase() ?? '';
    final matching = users.values
        .where((user) =>
            (role == 'ALL' || user.role == role) &&
            (normalizedSearch.isEmpty ||
                user.label.toLowerCase().contains(normalizedSearch) ||
                (user.email?.toLowerCase().contains(normalizedSearch) ?? false)))
        .toList(growable: false);
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
  Future<AdminUser> changeRole(String userId, String role, {List<String> cityIds = const []}) async {
    roleChanges.add((userId, role));
    if (role == 'CITY_ADMIN') cityAssignmentChanges.add((userId, cityIds));
    if (failRoleChange) {
      throw Exception('role change failed');
    }
    final user = users[userId]!;
    final updated = AdminUser(id: user.id, displayName: user.displayName, email: user.email, photoUrl: user.photoUrl, role: role, cityIds: cityIds, createdAt: user.createdAt);
    users[userId] = updated;
    return updated;
  }
}

Widget _buildPage(_FakeAdminUsersRepository repository) {
  return ProviderScope(
    overrides: [
      adminUsersRepositoryProvider.overrideWithValue(repository),
      cityCatalogueProvider('en').overrideWith((ref) async => const [City(id: 'pune', name: 'Pune'), City(id: 'mumbai', name: 'Mumbai')]),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const AdminUsersPage(),
    ),
  );
}

void main() {
  testWidgets('editing a City Admin saves only changed canonical city assignments', (tester) async {
    final repository = _FakeAdminUsersRepository();
    repository.users['city-admin'] = _user(
      'city-admin',
      'City Administrator',
      role: 'CITY_ADMIN',
      cityIds: const ['pune'],
    );
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_location_alt_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('city_assignment_pune'))).value, isTrue);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save assignments')).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('city_assignment_mumbai')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignments'));
    await tester.pumpAndSettle();

    expect(repository.roleChanges, [('city-admin', 'CITY_ADMIN')]);
    expect(repository.cityAssignmentChanges.single.$2, ['mumbai', 'pune']);
  });

  testWidgets('city assignment catalogue errors can be retried', (tester) async {
    var shouldFail = true;
    final repository = _FakeAdminUsersRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersRepositoryProvider.overrideWithValue(repository),
          cityCatalogueProvider('en').overrideWith((ref) async {
            if (shouldFail) throw StateError('offline');
            return const [City(id: 'pune', name: 'Pune')];
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign City Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikita Manoriya'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load the city list.'), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text('Retry').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('city_assignment_pune')), findsOneWidget);
  });

  testWidgets('Super Admin can assign a user to multiple localized city scopes', (tester) async {
    final repository = _FakeAdminUsersRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersRepositoryProvider.overrideWithValue(repository),
          adminUsersProvider.overrideWith((ref, query) async => const PaginatedAdminUsers(items: [], page: 1, pageSize: 3, total: 0)),
          adminAuditHistoryProvider.overrideWith((ref) async => const []),
          cityAdminsProvider.overrideWith((ref) async => const PaginatedAdminUsers(items: [], page: 1, pageSize: 20, total: 0)),
          cityCatalogueProvider('en').overrideWith((ref) async => const [City(id: 'pune', name: 'Pune'), City(id: 'mumbai', name: 'Mumbai')]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Assign City Admin'));
    await tester.tap(find.text('Assign City Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikita Manoriya'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the cities Nikita Manoriya can manage.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('city_assignment_pune')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('city_assignment_mumbai')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('city_assignment_pune'))).value, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('city_assignment_mumbai'))).value, isTrue);
    await tester.ensureVisible(find.text('Save assignments'));
    await tester.tap(find.text('Save assignments'));
    await tester.pumpAndSettle();

    expect(repository.roleChanges, [('nikita-user', 'CITY_ADMIN')]);
    expect(repository.cityAssignmentChanges.single.$1, 'nikita-user');
    expect(repository.cityAssignmentChanges.single.$2, ['mumbai', 'pune']);
    expect(repository.users['nikita-user']!.role, 'CITY_ADMIN');
  });

  testWidgets('shows only the current server page of administrators', (tester) async {
    final pageOne = PaginatedAdminUsers(
      items: [_user('one', 'Admin One'), _user('two', 'Admin Two'), _user('three', 'Admin Three')],
      page: 1,
      pageSize: 3,
      total: 4,
    );
    final pageTwo = PaginatedAdminUsers(
      items: [_user('four', 'Admin Four')],
      page: 2,
      pageSize: 3,
      total: 4,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersProvider.overrideWith((ref, query) async {
            if (query.page == 2) return pageTwo;
            return pageOne;
          }),
          adminAuditHistoryProvider.overrideWith((ref) async => const []),
          cityAdminsProvider.overrideWith((ref) async => const PaginatedAdminUsers(items: [], page: 1, pageSize: 20, total: 0)),
          cityCatalogueProvider('en').overrideWith((ref) async => const [City(id: 'pune', name: 'Pune')]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AdminUsersPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Admin One'), findsOneWidget);
    expect(find.text('Admin Two'), findsOneWidget);
    expect(find.text('Admin Three'), findsOneWidget);
    expect(find.text('Admin Four'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    final nextPage = find.byIcon(Icons.chevron_right).first;
    await tester.ensureVisible(nextPage);
    await tester.tap(nextPage);
    await tester.pumpAndSettle();

    expect(find.text('Admin One'), findsNothing);
    expect(find.text('Admin Four'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('search resets pagination and asks the provider for the search term', (tester) async {
    ({String? search, int page})? observed;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersProvider.overrideWith((ref, query) async {
            observed = (search: query.search, page: query.page);
            return PaginatedAdminUsers(
              items: query.search == 'nikita' ? [_user('nikita', 'Nikita')] : const [],
              page: query.page,
              pageSize: 3,
              total: query.search == 'nikita' ? 1 : 0,
            );
          }),
          adminAuditHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AdminUsersPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'nikita');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(observed, (search: 'nikita', page: 1));
    expect(find.text('Nikita'), findsOneWidget);
  });

  testWidgets('shows a genuine no-results state when no user matches the search', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersProvider.overrideWith((ref, query) async => PaginatedAdminUsers(
                items: const [],
                page: query.page,
                pageSize: 3,
                total: 0,
              )),
          adminAuditHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const AdminUsersPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'does-not-exist');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No users found.'), findsOneWidget);
    expect(find.text('Make admin'), findsNothing);
  });

  testWidgets('search shows multiple matching users with details and allows selecting the correct user', (tester) async {
    final repository = _FakeAdminUsersRepository();
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nikita');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('2 matching users'), findsOneWidget);
    expect(find.text('Nikita Manoriya'), findsOneWidget);
    expect(find.text('Nikita Sharma'), findsOneWidget);
    expect(find.text('nikita-user@example.com'), findsOneWidget);
    expect(find.text('nikita-admin@example.com'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    final promoteButtons = find.widgetWithText(FilledButton, 'Make admin');
    expect(promoteButtons, findsOneWidget);

    await tester.tap(promoteButtons);
    await tester.pumpAndSettle();
    final confirmation = find.byType(AlertDialog).last;
    final confirmButton = find.descendant(
      of: confirmation,
      matching: find.byType(FilledButton),
    );
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(repository.roleChanges, [('nikita-user', 'ADMIN')]);
    expect(repository.users['nikita-user']!.role, 'ADMIN');
    expect(find.text('User is now an administrator and the change was recorded.'), findsOneWidget);
  });

  testWidgets('cancelling promotion leaves the user unchanged', (tester) async {
    final repository = _FakeAdminUsersRepository();
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikita Manoriya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.roleChanges, isEmpty);
    expect(repository.users['nikita-user']!.role, 'USER');
  });

  testWidgets('promotion failure keeps the user as a normal user and shows the error', (tester) async {
    final repository = _FakeAdminUsersRepository(failRoleChange: true);
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nikita Manoriya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin').last);
    await tester.pumpAndSettle();

    expect(repository.users['nikita-user']!.role, 'USER');
    expect(repository.roleChanges, [('nikita-user', 'ADMIN')]);
    expect(find.textContaining('role change failed'), findsOneWidget);
  });

  testWidgets('cancelling demotion keeps the administrator unchanged', (tester) async {
    final repository = _FakeAdminUsersRepository();
    repository.users['nikita-user'] = _user('nikita-user', 'Nikita Manoriya');
    repository.users.remove('nikita-admin');
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.roleChanges, isEmpty);
    expect(repository.users['nikita-user']!.role, 'ADMIN');
    expect(find.text('Nikita Manoriya'), findsOneWidget);
  });

  testWidgets('successful demotion removes the administrator from the refreshed list', (tester) async {
    final repository = _FakeAdminUsersRepository();
    repository.users['nikita-user'] = _user('nikita-user', 'Nikita Manoriya');
    repository.users.remove('nikita-admin');
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove admin').last);
    await tester.pumpAndSettle();

    expect(repository.roleChanges, [('nikita-user', 'USER')]);
    expect(repository.users['nikita-user']!.role, 'USER');
    expect(find.text('Nikita Manoriya'), findsNothing);
  });

  testWidgets('demotion failure keeps the administrator visible', (tester) async {
    final repository = _FakeAdminUsersRepository(failRoleChange: true);
    repository.users['nikita-user'] = _user('nikita-user', 'Nikita Manoriya');
    repository.users.remove('nikita-admin');
    await tester.pumpWidget(_buildPage(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove admin').last);
    await tester.pumpAndSettle();

    expect(repository.users['nikita-user']!.role, 'ADMIN');
    expect(repository.roleChanges, [('nikita-user', 'USER')]);
    expect(find.text('Nikita Manoriya'), findsOneWidget);
    expect(find.textContaining('role change failed'), findsOneWidget);
  });
}
