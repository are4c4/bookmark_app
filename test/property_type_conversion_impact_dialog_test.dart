import 'package:bookmark_app/data/database_view_property_type_conversion_service.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/widgets/property_type_conversion_impact_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _property = ObjectPropertyDefinition(
  id: 4,
  objectTypeId: 2,
  name: 'Labels',
  type: ObjectPropertyType.multiSelect,
  sortOrder: 0,
);

Widget _host({
  required PropertyTypeConversionImpact impact,
  required ValueChanged<PropertyTypeConversionConfirmation?> onResult,
  Map<int, String> objectLabels = const <int, String>{},
}) =>
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onResult(
                await showPropertyTypeConversionImpactDialog(
                  context: context,
                  impact: impact,
                  objectLabels: objectLabels,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('preserving conversion can be explicitly confirmed', (tester) async {
    PropertyTypeConversionConfirmation? result;
    const impact = PropertyTypeConversionImpact(
      property: ObjectPropertyDefinition(
        id: 4,
        objectTypeId: 2,
        name: 'URL',
        type: ObjectPropertyType.url,
        sortOrder: 0,
      ),
      nextType: ObjectPropertyType.text,
      mode: PropertyTypeConversionMode.preserveStoredValues,
      objectsWithStoredValue: 3,
    );

    await tester.pumpWidget(
      _host(impact: impact, onResult: (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('URL  →  Text'), findsOneWidget);
    expect(find.text('3件のObject'), findsOneWidget);
    expect(find.textContaining('既存の保存値はそのまま保持'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-type-conversion-confirm')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.explicitChoices, isEmpty);
  });

  testWidgets('narrowing MultiSelect requires every explicit Object choice', (tester) async {
    PropertyTypeConversionConfirmation? result;
    const impact = PropertyTypeConversionImpact(
      property: _property,
      nextType: ObjectPropertyType.select,
      mode: PropertyTypeConversionMode.requiresExplicitChoice,
      objectsWithStoredValue: 4,
      explicitChoiceOptions: <int, List<String>>{
        100: <String>['alpha', 'beta'],
        101: <String>['gamma', 'delta'],
      },
    );

    await tester.pumpWidget(
      _host(
        impact: impact,
        onResult: (value) => result = value,
        objectLabels: const <int, String>{100: 'Paper A', 101: 'Paper B'},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    FilledButton confirm() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('property-type-conversion-confirm')),
        );
    expect(confirm().onPressed, isNull);
    expect(find.text('Paper A'), findsOneWidget);
    expect(find.text('Paper B'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('property-type-choice-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('beta').last);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('property-type-choice-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gamma').last);
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.text('変更を続ける'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.explicitChoices, <int, String>{100: 'beta', 101: 'gamma'});
  });

  testWidgets('migration-required impact is visible and cannot be confirmed', (tester) async {
    PropertyTypeConversionConfirmation? result;
    const impact = PropertyTypeConversionImpact(
      property: ObjectPropertyDefinition(
        id: 4,
        objectTypeId: 2,
        name: 'Score',
        type: ObjectPropertyType.number,
        sortOrder: 0,
      ),
      nextType: ObjectPropertyType.rating,
      mode: PropertyTypeConversionMode.requiresMigration,
      objectsWithStoredValue: 2,
      objectsRequiringMigration: <int>[201, 202],
    );

    await tester.pumpWidget(
      _host(
        impact: impact,
        onResult: (value) => result = value,
        objectLabels: const <int, String>{201: 'Entry A', 202: 'Entry B'},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('暗黙の変換や値の破棄は行いません'), findsOneWidget);
    expect(find.text('• Entry A'), findsOneWidget);
    expect(find.text('• Entry B'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-type-conversion-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(result, isNull);
  });

  testWidgets('incompatible Value to Relation conversion remains blocked', (tester) async {
    PropertyTypeConversionConfirmation? result;
    const impact = PropertyTypeConversionImpact(
      property: ObjectPropertyDefinition(
        id: 4,
        objectTypeId: 2,
        name: 'Text',
        type: ObjectPropertyType.text,
        sortOrder: 0,
      ),
      nextType: ObjectPropertyType.objectRelation,
      mode: PropertyTypeConversionMode.incompatible,
      objectsWithStoredValue: 0,
    );

    await tester.pumpWidget(
      _host(impact: impact, onResult: (value) => result = value),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Text  →  Relation'), findsOneWidget);
    expect(find.textContaining('専用の移行手順が必要'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('property-type-conversion-confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(result, isNull);
  });
}
