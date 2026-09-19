import 'package:bookmark_app/features/object/presentation/widgets/object_detail_property_reveal_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collapses and reveals empty Property rows with keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertyRevealSection(
            visibleChildren: [Text('Title')],
            emptyChildren: [Text('Site name'), Text('Published date')],
          ),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Site name'), findsNothing);
    expect(find.text('Published date'), findsNothing);
    expect(find.text('空のプロパティを表示 (2)'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('object-detail-show-empty-properties')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Site name'), findsOneWidget);
    expect(find.text('Published date'), findsOneWidget);
    expect(find.text('空のプロパティを隠す'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('object-detail-hide-empty-properties')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('Site name'), findsNothing);
    expect(find.text('Published date'), findsNothing);
    expect(find.text('空のプロパティを表示 (2)'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('object-detail-show-empty-properties')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('does not render a reveal control when there are no empty rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectDetailPropertyRevealSection(
            visibleChildren: [Text('Title')],
            emptyChildren: [],
          ),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('object-detail-show-empty-properties')),
      findsNothing,
    );
  });
}
