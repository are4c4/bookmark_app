import 'dart:async';

import 'package:bookmark_app/features/object/presentation/widgets/object_inline_title_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required String value,
    required Future<void> Function(String value) onSaved,
    ValueChanged<Object>? onSaveError,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ObjectInlineTitleEditor(
          value: value,
          onSaved: onSaved,
          onSaveError: onSaveError,
        ),
      ),
    );
  }

  testWidgets('Enter commits one trimmed title and releases focus', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(
      host(value: 'Before', onSaved: (value) async => saved.add(value)),
    );

    final field = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(field);
    await tester.enterText(field, '  After  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(saved, ['After']);
    expect(find.text('After'), findsOneWidget);
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);
  });

  testWidgets('Escape restores the canonical title without saving', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(
      host(value: 'Before', onSaved: (value) async => saved.add(value)),
    );

    final field = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(field);
    await tester.enterText(field, 'Changed');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(saved, isEmpty);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('Changed'), findsNothing);
  });

  testWidgets('focus loss commits a changed title', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ObjectInlineTitleEditor(
                value: 'Before',
                onSaved: (value) async => saved.add(value),
              ),
              const TextField(key: ValueKey('next-field')),
            ],
          ),
        ),
      ),
    );

    final title = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(title);
    await tester.enterText(title, 'After');
    await tester.tap(find.byKey(const ValueKey('next-field')));
    await tester.pump();

    expect(saved, ['After']);
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('failed save restores the canonical title and reports failure', (
    tester,
  ) async {
    final errors = <Object>[];
    await tester.pumpWidget(
      host(
        value: 'Before',
        onSaved: (_) => Future<void>.error(StateError('nope')),
        onSaveError: errors.add,
      ),
    );

    final field = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(field);
    await tester.enterText(field, 'After');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(errors.single, isA<StateError>());
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save completion is safe when the host unmounts the editor', (
    tester,
  ) async {
    var showEditor = true;
    late StateSetter setHostState;
    final releaseSave = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return Scaffold(
              body: showEditor
                  ? ObjectInlineTitleEditor(
                      value: 'Before',
                      onSaved: (_) async {
                        setHostState(() => showEditor = false);
                        await releaseSave.future;
                      },
                    )
                  : const Text('Reloaded host'),
            );
          },
        ),
      ),
    );

    final field = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(field);
    await tester.enterText(field, 'After');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Reloaded host'), findsOneWidget);

    releaseSave.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('empty input fails closed without invoking persistence', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      host(value: 'Before', onSaved: (_) async => saves += 1),
    );

    final field = find.byKey(const ValueKey('object-inline-title-field'));
    await tester.tap(field);
    await tester.enterText(field, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(saves, 0);
    expect(find.text('Before'), findsOneWidget);
  });
}
