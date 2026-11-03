import 'package:attendance/widgets/admin/admin_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows counts and selection and reports each filter', (
    WidgetTester tester,
  ) async {
    final selectedFilters = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminFilterBar(
            selected: 'present',
            total: 12,
            present: 8,
            absent: 4,
            onSelected: selectedFilters.add,
          ),
        ),
      ),
    );

    expect(find.text('All (12)'), findsOneWidget);
    expect(find.text('Present (8)'), findsOneWidget);
    expect(find.text('Absent (4)'), findsOneWidget);
    expect(
      tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .map((chip) => chip.selected)
          .toList(),
      [false, true, false],
    );

    await tester.tap(find.text('All (12)'));
    await tester.tap(find.text('Present (8)'));
    await tester.tap(find.text('Absent (4)'));

    expect(selectedFilters, ['all', 'present', 'absent']);
  });
}
