import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avijit_sahyog/features/impact/presentation/impact_page.dart';

void main() {
  testWidgets('announces a beneficiary placeholder as a named image', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: beneficiaryImage(
            null,
            height: 120,
            borderRadius: BorderRadius.zero,
            semanticLabel: 'Photo of Alice',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Photo of Alice'), findsOneWidget);
  });
}
