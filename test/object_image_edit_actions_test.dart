import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_edit_actions.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables mutations when canonical Image is not safely editable',
      (tester) async {
    final service = _FakeCanonicalImageEditService(
      canEditValue: false,
      canRestoreValue: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageEditActions(
            editService: service,
            workspaceId: 1,
            objectId: 10,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_iconButton(tester, 'object-image-rotate-left').onPressed, isNull);
    expect(_iconButton(tester, 'object-image-rotate-right').onPressed, isNull);
    expect(
      _iconButton(tester, 'object-image-flip-horizontal').onPressed,
      isNull,
    );
    expect(_cropButton(tester).enabled, isFalse);
    expect(_restoreButton(tester).onPressed, isNull);
  });

  testWidgets('routes edits, crop presets and restore through CanonicalImageEditService',
      (tester) async {
    final service = _FakeCanonicalImageEditService(
      canEditValue: true,
      canRestoreValue: true,
    );
    var changed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageEditActions(
            editService: service,
            workspaceId: 7,
            objectId: 42,
            onChanged: () => changed += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('object-image-rotate-right')));
    await tester.pumpAndSettle();
    expect(service.lastWorkspaceId, 7);
    expect(service.lastObjectId, 42);
    expect(service.lastQuarterTurns, 1);

    await tester.tap(find.byKey(const ValueKey('object-image-flip-horizontal')));
    await tester.pumpAndSettle();
    expect(service.lastFlipHorizontal, isTrue);

    await tester.tap(find.byKey(const ValueKey('object-image-crop-aspect-ratio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('正方形 1:1'));
    await tester.pumpAndSettle();
    expect(service.lastCropAspectRatio, 1.0);

    await tester.tap(find.byKey(const ValueKey('object-image-restore-original')));
    await tester.pumpAndSettle();
    expect(service.restoreCalls, 1);
    expect(changed, 4);
  });
}

IconButton _iconButton(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(ValueKey(key)));

PopupMenuButton<double> _cropButton(WidgetTester tester) =>
    tester.widget<PopupMenuButton<double>>(
      find.byKey(const ValueKey('object-image-crop-aspect-ratio')),
    );

OutlinedButton _restoreButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('object-image-restore-original')),
    );

class _FakeCanonicalImageEditService extends CanonicalImageEditService {
  _FakeCanonicalImageEditService({
    required this.canEditValue,
    required this.canRestoreValue,
  }) : super(
          resolveStoredFile: ({required workspaceId, required objectId}) async =>
              null,
          resolveExclusiveManagedPath:
              ({required objectId, required filePath}) async => null,
          geometryUpdater: ({
            required workspaceId,
            required objectId,
            required pixelWidth,
            required pixelHeight,
          }) async => _object(objectId),
        );

  final bool canEditValue;
  final bool canRestoreValue;
  int? lastWorkspaceId;
  int? lastObjectId;
  int? lastQuarterTurns;
  bool? lastFlipHorizontal;
  double? lastCropAspectRatio;
  int restoreCalls = 0;

  @override
  Future<bool> canEdit({required int workspaceId, required int objectId}) async =>
      canEditValue;

  @override
  Future<bool> canRestoreOriginal({
    required int workspaceId,
    required int objectId,
  }) async =>
      canRestoreValue;

  @override
  Future<AppObject> edit({
    required int workspaceId,
    required int objectId,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    double? cropAspectRatio,
    Rect? normalizedCropRect,
  }) async {
    lastWorkspaceId = workspaceId;
    lastObjectId = objectId;
    lastQuarterTurns = quarterTurns;
    lastFlipHorizontal = flipHorizontal;
    lastCropAspectRatio = cropAspectRatio;
    return _object(objectId);
  }

  @override
  Future<AppObject> restoreOriginal({
    required int workspaceId,
    required int objectId,
  }) async {
    restoreCalls += 1;
    return _object(objectId);
  }
}

AppObject _object(int id) {
  final now = DateTime(2026, 9, 7);
  return AppObject(
    id: id,
    objectTypeId: 1,
    title: 'Image',
    createdAt: now,
    updatedAt: now,
  );
}
