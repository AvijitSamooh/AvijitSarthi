import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/core/navigation/app_shell_scope.dart';
import 'package:avijit_sahyog/features/admin/models/admin_cause.dart';
import 'package:avijit_sahyog/features/causes/models/cause.dart';
import 'package:avijit_sahyog/features/causes/presentation/cause_detail_page.dart';
import 'package:avijit_sahyog/features/causes/providers/causes_providers.dart';
import 'package:avijit_sahyog/features/donations/presentation/donation_page.dart';
import 'package:avijit_sahyog/l10n/app_localizations.dart';

const _educationAssistance = Cause(
  id: 'education-assistance-id',
  slug: 'education-assistance',
  name: 'Education Assistance',
  parentId: 'education-id',
);

const _pratibhaSamman = Cause(
  id: 'pratibha-samman-id',
  slug: 'pratibha-samman',
  name: 'Pratibha Samman',
  parentId: 'education-id',
);

const _education = Cause(
  id: 'education-id',
  slug: 'education',
  name: 'Education',
  hasChildren: true,
  children: [_educationAssistance, _pratibhaSamman],
);

void main() {
  test('parent state is preserved when all children are inactive', () {
    final parent = Cause.fromJson({
      'id': 'education-id',
      'slug': 'education',
      'name': 'Education',
      'hasChildren': true,
      'children': <dynamic>[],
    });

    expect(parent.isParent, isTrue);
    expect(parent.isLeaf, isFalse);
    expect(parent.leafCauses, isEmpty);
  });

  test('leaf traversal returns only terminal causes', () {
    expect(
      _education.leafCauses.map((cause) => cause.id).toList(),
      ['education-assistance-id', 'pratibha-samman-id'],
    );
  });

  test('admin beneficiary selection traverses only active leaf causes', () {
    final parent = AdminCause(
      id: 'education',
      slug: 'education',
      isActive: true,
      displayOrder: 1,
      translations: const [],
      hasChildren: true,
      children: [
        AdminCause(
          id: 'education-assistance',
          slug: 'education-assistance',
          isActive: true,
          displayOrder: 1,
          translations: const [],
          parentId: 'education',
        ),
        AdminCause(
          id: 'pratibha-samman',
          slug: 'pratibha-samman',
          isActive: false,
          displayOrder: 2,
          translations: const [],
          parentId: 'education',
        ),
      ],
    );

    expect(parent.activeLeafCauses.map((cause) => cause.id), ['education-assistance']);
  });

  testWidgets('parent detail guides users to child causes instead of donation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          causeProvider((slug: 'education', languageCode: 'en'))
              .overrideWith((ref) async => _education),
          causeProvider((slug: 'education-assistance', languageCode: 'en'))
              .overrideWith((ref) async => _educationAssistance),
          causeProvider((slug: 'pratibha-samman', languageCode: 'en'))
              .overrideWith((ref) async => _pratibhaSamman),
        ],
        child: AppShellScope(
          onLocaleChanged: (_) {},
          navigation: AppNavigationController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: ThemeData(useMaterial3: true),
            home: const CauseDetailPage(slug: 'education'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Specific causes'), findsOneWidget);
    expect(find.text('Choose a specific cause below to support this area.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cause_support_education-id')), findsNothing);
    expect(find.byKey(const ValueKey('cause_apply_EDUCATION_ASSISTANCE')), findsNothing);
    expect(find.byKey(const ValueKey('cause_child_card_education-assistance-id')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cause_child_card_education-assistance-id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cause_support_education-assistance-id')), findsOneWidget);
    expect(find.byKey(const ValueKey('cause_apply_EDUCATION_ASSISTANCE')), findsOneWidget);
  });


}
