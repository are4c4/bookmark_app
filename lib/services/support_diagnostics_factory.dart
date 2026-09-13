import '../data/bookmark_repository.dart';
import 'build_provenance.dart';
import 'support_diagnostics.dart';

SupportDiagnosticsService createSupportDiagnosticsService({
  required BookmarkRepository repository,
  required BuildProvenance buildProvenance,
  DiagnosticEventBuffer? events,
  SupportDiagnosticsRuntime? runtime,
  Iterable<SupportDiagnosticProvider> providers = const <SupportDiagnosticProvider>[],
  DateTime Function()? clock,
}) {
  final vaultPath = repository.profileDirectoryPath?.trim();
  return SupportDiagnosticsService(
    buildProvenance: buildProvenance,
    databaseSchemaVersion: repository.workspaceStore.database.schemaVersion,
    vaultConfigured: vaultPath != null && vaultPath.isNotEmpty,
    events: events,
    runtime: runtime,
    providers: providers,
    clock: clock,
  );
}
