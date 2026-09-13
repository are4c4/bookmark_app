import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_identity_search.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_body_document_view.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/repositories/object_search_result_resolver.dart';
import 'package:bookmark_app/views/object_global_search_page.dart';
import 'package:bookmark_app/widgets/object_relation_picker_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = Size(1440, 900);
const _devicePixelRatio = 1.0;
const _captureBoundaryKey = ValueKey<String>('ui-audit-capture-boundary');
const _profileName = 'desktop-dark-1440x900';

final List<Map<String, Object?>> _scenarioRecords = <Map<String, Object?>>[];

String? get _captureRoot {
  final value = Platform.environment['UI_AUDIT_OUTPUT_DIR']?.trim();
  return value == null || value.isEmpty ? null : value;
}

String get _sourceSha {
  final value = Platform.environment['UI_AUDIT_SOURCE_SHA']?.trim();
  return value == null || value.isEmpty ? 'local' : value;
}

Future<void> _initializeCaptureOutput() async {
  final root = _captureRoot;
  if (root == null) return;
  final directory = Directory(root);
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
  await Directory('$root/screenshots').create(recursive: true);
  await _writeManifest();
}

Future<void> _writeManifest() async {
  final root = _captureRoot;
  if (root == null) return;
  final manifest = <String, Object?>{
    'schemaVersion': 1,
    'sourceSha': _sourceSha,
    'profile': <String, Object?>{
      'name': _profileName,
      'viewport': <String, Object?>{
        'width': _viewport.width.toInt(),
        'height': _viewport.height.toInt(),
      },
      'devicePixelRatio': _devicePixelRatio,
      'theme': 'dark',
      'renderer': 'flutter-widget-test',
    },
    'scenarios': _scenarioRecords,
  };
  await File('$root/manifest.json').writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    flush: true,
  );
}

Future<void> _configureDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = _devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _auditHost(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: RepaintBoundary(
        key: _captureBoundaryKey,
        child: child,
      ),
    );

Future<void> _captureScenario(
  WidgetTester tester, {
  required String name,
  required bool contractSatisfied,
}) async {
  final exception = tester.takeException();
  String? screenshotPath;
  final root = _captureRoot;
  if (root != null) {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureBoundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: _devicePixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('UI audit PNG encoding returned no bytes.');
      }
      screenshotPath = 'screenshots/$name.png';
      await File('$root/$screenshotPath').writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );
    } finally {
      image.dispose();
    }

    _scenarioRecords.add(<String, Object?>{
      'name': name,
      'file': screenshotPath,
      'status': exception == null && contractSatisfied ? 'passed' : 'failed',
    });
    await _writeManifest();
  }

  expect(exception, isNull, reason: 'UI audit surface emitted a Flutter exception.');
  expect(
    contractSatisfied,
    isTrue,
    reason: 'UI audit surface lost its deterministic contract marker.',
  );
}

AppObject _relationObject(int id, int typeId, String title) => AppObject(
      id: id,
      objectTypeId: typeId,
      title: title,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

RelationSelectionContext _relationSelection() {
  const sourceTypeId = 10;
  const targetTypeId = 20;
  final candidates = <AppObject>[
    _relationObject(101, targetTypeId, 'Alice'),
    _relationObject(102, targetTypeId, 'Bob'),
    _relationObject(103, targetTypeId, 'Carol'),
  ];
  return RelationSelectionContext(
    sourceObject: _relationObject(1, sourceTypeId, 'Reading list'),
    property: ObjectPropertyDefinition(
      id: 30,
      objectTypeId: sourceTypeId,
      name: 'Authors',
      type: ObjectPropertyType.objectRelation,
      sortOrder: 0,
      config: const <String, dynamic>{
        'targetObjectTypeId': targetTypeId,
        'multiple': true,
      },
    ),
    targetObjectType: const AppObjectType(
      id: targetTypeId,
      workspaceId: 1,
      name: 'Person',
      icon: '👤',
      kind: ObjectTypeKind.custom,
      sortOrder: 0,
    ),
    candidates: candidates,
    selectedObjectIds: const <int>[102],
    selectedObjects: <AppObject>[candidates[1]],
    missingTargetObjectIds: const <int>[],
    hasCardinalityViolation: false,
  );
}

List<ObjectIdentitySearchResult> _relationSearchResults(
  RelationSelectionContext context,
) =>
    context.candidates
        .map(
          (object) => ObjectIdentitySearchResult(
            object: object,
            objectType: context.targetObjectType,
            aliases: const <String>[],
          ),
        )
        .toList(growable: false);

class _UiAuditSearchService extends ObjectGlobalSearchService {
  _UiAuditSearchService(super.store);

  @override
  Future<void> rebuildWorkspace(int workspaceId) async {}

  @override
  Future<List<ResolvedObjectSearchHit>> search({
    required int workspaceId,
    required String rawQuery,
    int? objectTypeId,
    int limit = 100,
  }) async =>
      const <ResolvedObjectSearchHit>[];
}

void main() {
  setUpAll(_initializeCaptureOutput);

  testWidgets('UI audit: populated shared Body document', (tester) async {
    await _configureDesktopSurface(tester);
    const factory = ObjectBodyBlockFactory();
    final document = ObjectBodyDocument(
      version: 1,
      blocks: <ObjectBodyBlock>[
        factory.heading(id: 'heading-1', level: 2, text: 'Research notes'),
        factory.paragraph(
          id: 'paragraph-1',
          text: 'Keep the shared Body readable across every Object host.',
        ),
        factory.checklist(
          id: 'check-1',
          text: 'Review canonical Relation links',
          checked: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _auditHost(
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: SizedBox(
                width: 760,
                child: ObjectBodyDocumentView(document: document),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _captureScenario(
      tester,
      name: 'body-populated',
      contractSatisfied: find.text('Research notes').evaluate().length == 1 &&
          find.text('Review canonical Relation links').evaluate().length == 1,
    );
  });

  testWidgets('UI audit: generic Person Relation picker', (tester) async {
    await _configureDesktopSurface(tester);
    final selection = _relationSelection();

    await tester.pumpWidget(
      _auditHost(
        Scaffold(
          body: ObjectRelationPickerDialog(
            selection: selection,
            onSearch: ({required context, required query}) async =>
                _relationSearchResults(context)
                    .where(
                      (result) => result.canonicalTitle
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                    )
                    .toList(growable: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _captureScenario(
      tester,
      name: 'relation-picker-person',
      contractSatisfied: find.text('Authors').evaluate().length == 1 &&
          find.text('Bob').evaluate().length == 1 &&
          find.text('1件選択').evaluate().length == 1,
    );
  });

  testWidgets('UI audit: canonical Global Search empty state', (tester) async {
    await _configureDesktopSurface(tester);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    await tester.pumpWidget(
      _auditHost(
        ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
          searchService: _UiAuditSearchService(store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _captureScenario(
      tester,
      name: 'global-search-empty',
      contractSatisfied:
          find.text('オブジェクトを横断検索').evaluate().length == 1,
    );
  });
}
