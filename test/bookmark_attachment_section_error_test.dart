import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_attachment_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/pdf_metadata_service.dart';
import 'package:bookmark_app/widgets/bookmark_attachment_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkLifecycleStore lifecycleStore;
  late BookmarkRepository repository;
  late BookmarkItem bookmark;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
      profileDirectoryPath: '/tmp/bookmark-attachment-test',
    );
    await repository.create(
      url: 'https://example.com',
      title: 'Original title',
    );
    bookmark = (await repository.watchAll().firstWhere(
      (items) => items.isNotEmpty,
    ))
        .single;
  });

  tearDown(() async {
    await lifecycleStore.dispose();
    await database.close();
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    Future<List<BookmarkAttachment>> Function()? importAttachments,
    Future<PdfFileMetadata> Function(String path)? readPdfMetadata,
    Future<void> Function(String name)? createPerson,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: BookmarkAttachmentSection(
              repository: repository,
              bookmark: bookmark,
              importAttachments: importAttachments,
              readPdfMetadata: readPdfMetadata,
              createPerson: createPerson,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeSection(WidgetTester tester) async {
    // Unsubscribe Drift-backed StreamBuilders before tearDown closes the DB,
    // then advance fake time once so Drift's zero-duration close timer drains.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> pumpUntilImportCompletes(WidgetTester tester) async {
    // The section intentionally shows an indeterminate progress indicator while
    // import/enrichment is active, so pumpAndSettle cannot be used here.
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    fail('Attachment import did not complete within the bounded test pumps.');
  }

  testWidgets('attachment import failure hides raw implementation details',
      (tester) async {
    await pumpSection(
      tester,
      importAttachments: () async {
        throw StateError('secret-path:/Users/private/document.pdf');
      },
    );

    await tester.tap(find.byTooltip('PDF / 動画を添付'));
    await pumpUntilImportCompletes(tester);

    expect(
      find.text('ファイルを添付できませんでした。もう一度お試しください。'),
      findsOneWidget,
    );
    expect(find.textContaining('secret-path'), findsNothing);
    expect(find.textContaining('/Users/private'), findsNothing);

    await disposeSection(tester);
  });

  testWidgets('PDF author enrichment stays best-effort when person creation fails',
      (tester) async {
    var createPersonCalls = 0;
    final attachment = BookmarkAttachment(
      id: 1,
      bookmarkId: bookmark.id,
      fileName: 'sample.pdf',
      path: '/tmp/private/sample.pdf',
      kind: 'pdf',
      sizeBytes: 42,
      createdAt: DateTime.utc(2026, 9, 6),
    );

    await pumpSection(
      tester,
      importAttachments: () async => [attachment],
      readPdfMetadata: (_) async => const PdfFileMetadata(
        title: 'Updated from PDF',
        authors: ['Example Author'],
      ),
      createPerson: (_) async {
        createPersonCalls++;
        throw StateError('author-secret-error');
      },
    );

    await tester.tap(find.byTooltip('PDF / 動画を添付'));
    // The import remains active while the metadata confirmation dialog is open,
    // so an indeterminate progress indicator keeps scheduling frames. Use fixed
    // pumps here instead of pumpAndSettle to avoid waiting on that intentional
    // animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PDFの情報を反映しますか？'), findsOneWidget);
    await tester.tap(find.text('反映'));
    await pumpUntilImportCompletes(tester);

    expect(createPersonCalls, 1);
    final updated = (await repository.watchAll().first).single;
    expect(updated.title, 'Updated from PDF');
    expect(find.textContaining('author-secret-error'), findsNothing);

    await disposeSection(tester);
  });
}
