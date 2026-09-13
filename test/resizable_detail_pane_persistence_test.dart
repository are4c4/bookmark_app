import 'package:bookmark_app/features/database/presentation/widgets/resizable_detail_pane.dart';
import 'package:bookmark_app/services/ui_layout_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingPreferences extends UiLayoutPreferences {
  var saves = 0;

  @override
  Future<double?> loadDetailPaneWidth(String storageKey) async => null;

  @override
  Future<void> saveDetailPaneWidth(String storageKey, double width) async {
    saves += 1;
  }
}

Future<void> _pumpPane(
  WidgetTester tester, {
  required String storageKey,
  double initialWidth = 400,
  double minWidth = 320,
  double maxWidth = 720,
  UiLayoutPreferences preferences = const UiLayoutPreferences(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: ResizableDetailPane(
            storageKey: storageKey,
            initialWidth: initialWidth,
            minWidth: minWidth,
            maxWidth: maxWidth,
            preferences: preferences,
            child: const SizedBox.expand(
              key: ValueKey('persisted-detail-content'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'generic Database pane width persists by presentation key across recreation',
    (tester) async {
      await _pumpPane(tester, storageKey: 'generic-db-12-detail');

      final divider = find.byType(GestureDetector).first;
      await tester.drag(divider, const Offset(-80, 0));
      await tester.pumpAndSettle();
      final resized = tester
          .getSize(find.byKey(const ValueKey('persisted-detail-content')))
          .width;
      expect(resized, greaterThan(400));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpPane(tester, storageKey: 'generic-db-999-detail');
      final restored = tester
          .getSize(find.byKey(const ValueKey('persisted-detail-content')))
          .width;
      expect(restored, resized);
    },
  );

  testWidgets('persisted width is clamped to current pane bounds', (
    tester,
  ) async {
    const preferences = UiLayoutPreferences();
    await preferences.saveDetailPaneWidth('collection-detail-pane', 1200);

    await _pumpPane(
      tester,
      storageKey: 'collection-detail-pane',
      maxWidth: 500,
    );

    final restored = tester
        .getSize(find.byKey(const ValueKey('persisted-detail-content')))
        .width;
    expect(restored, 500);
  });

  testWidgets('malformed persisted width falls back to initial width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ui.layout.detailPaneWidth.v1.test-corrupt': 'old-format',
    });

    await _pumpPane(tester, storageKey: 'test-corrupt', initialWidth: 410);

    final restored = tester
        .getSize(find.byKey(const ValueKey('persisted-detail-content')))
        .width;
    expect(restored, 410);
  });

  testWidgets('drag updates do not persist until gesture completion', (
    tester,
  ) async {
    final preferences = _RecordingPreferences();
    await _pumpPane(
      tester,
      storageKey: 'recording-detail-pane',
      preferences: preferences,
    );

    final divider = find.byType(GestureDetector).first;
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(preferences.saves, 0);

    await gesture.up();
    await tester.pump();
    expect(preferences.saves, 1);
  });
}
