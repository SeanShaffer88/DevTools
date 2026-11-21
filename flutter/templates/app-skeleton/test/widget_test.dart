// Widget test for the skeleton home page.
// Run with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_skeleton/app.dart';
import 'package:app_skeleton/data/sample_repository.dart';
import 'package:app_skeleton/features/home/home_page.dart';

void main() {
  testWidgets('app shows the home page with sample items', (tester) async {
    await tester.pumpWidget(const AppSkeletonApp());

    expect(find.text('App Skeleton'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('home page renders an empty state for no items',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(repository: _EmptyRepository())),
    );

    expect(find.text('No items yet'), findsOneWidget);
  });
}

class _EmptyRepository extends SampleRepository {
  const _EmptyRepository();

  @override
  List<SampleItem> loadItems() => const [];
}
