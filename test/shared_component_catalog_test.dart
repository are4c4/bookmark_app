import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/shared_component_catalog.dart';

void main() {
  Future<void> pumpCatalog(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SharedComponentCatalog());
    await tester.pump();
  }

  testWidgets('renders stable shared component states at wide width', (
    tester,
  ) async {
    await pumpCatalog(tester, const Size(900, 900));

    expect(find.text('Shared component catalog'), findsOneWidget);
    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Create item'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Shared detail-section content'), findsOneWidget);
    expect(find.byTooltip('More detail actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at narrow width', (tester) async {
    await pumpCatalog(tester, const Size(320, 900));

    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Create item'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
