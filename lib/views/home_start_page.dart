import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/canonical_weblink_capture_service.dart';
import '../data/generic_database_store.dart';
import '../data/home_recent_service.dart';
import '../data/object_store.dart';
import '../data/object_type_defaults_store.dart';
import '../data/system_object_store.dart';
import '../data/weblink_object_service.dart';
import '../ui/ui_tokens.dart';
import 'object_inspector_page.dart';

class HomeStartPage extends StatefulWidget {
  const HomeStartPage({
    super.key,
    required this.store,
    required this.workspaceId,
    this.recentLimit = 12,
  });

  final GenericDatabaseStore store;
  final int workspaceId;
  final int recentLimit;

  @override
  State<HomeStartPage> createState() => _HomeStartPageState();
}

class _HomeStartPageState extends State<HomeStartPage> {
  final TextEditingController _captureController = TextEditingController();
  late ObjectStore _objectStore;
  late SystemObjectStore _systemObjects;
  late CanonicalWeblinkCaptureService _weblinkCapture;
  List<HomeRecentObject> _recent = const <HomeRecentObject>[];
  bool _loading = true;
  bool _loadFailed = false;
  bool _captureBusy = false;
  String? _captureError;

  @override
  void initState() {
    super.initState();
    _configureStores();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeStartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.recentLimit != widget.recentLimit) {
      _configureStores();
      _load();
    }
  }

  @override
  void dispose() {
    _captureController.dispose();
    super.dispose();
  }

  void _configureStores() {
    _objectStore = ObjectStore(widget.store);
    _systemObjects = SystemObjectStore(
      database: widget.store.database,
      objectStore: _objectStore,
    );
    _weblinkCapture = CanonicalWeblinkCaptureService(
      weblinks: WeblinkObjectService(
        systemObjects: _systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(widget.store),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final recent =
          await HomeRecentService(
            objectStore: _objectStore,
            systemObjects: _systemObjects,
          ).listRecentlyChanged(
            workspaceId: widget.workspaceId,
            limit: widget.recentLimit,
          );
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recent = const <HomeRecentObject>[];
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _captureWeblink() async {
    if (_captureBusy) return;
    final rawUrl = _captureController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _captureError = 'URLを入力してください。');
      return;
    }

    setState(() {
      _captureBusy = true;
      _captureError = null;
    });
    try {
      final object = await _weblinkCapture.capture(
        workspaceId: widget.workspaceId,
        url: rawUrl,
      );
      if (!mounted) return;
      _captureController.clear();
      await _load();
      if (!mounted) return;
      setState(() => _captureBusy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Weblinkを保存しました。'),
            action: SnackBarAction(
              label: '開く',
              onPressed: () {
                _openObject(object.id);
              },
            ),
          ),
        );
    } on ArgumentError {
      if (!mounted) return;
      setState(() {
        _captureBusy = false;
        _captureError = '有効なURLを入力してください。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captureBusy = false;
        _captureError = 'Weblinkを保存できませんでした。';
      });
    }
  }

  Future<void> _open(HomeRecentObject item) => _openObject(item.object.id);

  Future<void> _openObject(int objectId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: widget.store,
          objectStore: _objectStore,
          objectId: objectId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ホーム',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: UiTokens.space6),
                  Text(
                    '最近更新したオブジェクトから作業を再開できます。',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  _captureCard(context),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Icon(Icons.history, size: UiTokens.iconNormal),
                      const SizedBox(width: UiTokens.space8),
                      Text(
                        '最近のオブジェクト',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiTokens.space12),
                  _recentBody(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _captureCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_link, size: UiTokens.iconNormal),
                const SizedBox(width: UiTokens.space8),
                Text(
                  'Weblinkを保存',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: UiTokens.space6),
            Text(
              'URLだけで保存できます。整理はあとから行えます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: UiTokens.space12),
            TextField(
              key: const ValueKey('home-weblink-url-field'),
              controller: _captureController,
              enabled: !_captureBusy,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                errorText: _captureError,
                prefixIcon: const Icon(Icons.link),
              ),
              onChanged: (_) {
                if (_captureError != null) {
                  setState(() => _captureError = null);
                }
              },
              onSubmitted: (_) {
                _captureWeblink();
              },
            ),
            const SizedBox(height: UiTokens.space12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('home-weblink-capture-button'),
                onPressed: _captureBusy ? null : _captureWeblink,
                icon: _captureBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link),
                label: Text(_captureBusy ? '保存中…' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadFailed) {
      return _HomeMessageCard(
        icon: Icons.error_outline,
        message: '最近のオブジェクトを読み込めませんでした。',
        action: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: UiTokens.iconSmall),
          label: const Text('再試行'),
        ),
      );
    }
    if (_recent.isEmpty) {
      return const _HomeMessageCard(
        icon: Icons.history_toggle_off,
        message: '最近更新したオブジェクトはありません。',
      );
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < _recent.length; index++) ...[
              _recentTile(_recent[index], index: index),
              if (index != _recent.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recentTile(HomeRecentObject item, {required int index}) {
    final open = () => _open(item);
    return FocusTraversalOrder(
      order: NumericFocusOrder(index.toDouble()),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): open,
          const SingleActivator(LogicalKeyboardKey.space): open,
        },
        child: ListTile(
          key: ValueKey('home-recent-object-${item.object.id}'),
          autofocus: index == 0,
          leading: SizedBox(
            width: 32,
            child: Center(
              child: Text(
                item.objectType.icon,
                style: const TextStyle(fontSize: UiTokens.iconNormal),
              ),
            ),
          ),
          title: Text(
            item.object.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.objectType.name} ・ ${_formatUpdatedAt(item.object.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: open,
        ),
      ),
    );
  }

  String _formatUpdatedAt(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _HomeMessageCard extends StatelessWidget {
  const _HomeMessageCard({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(UiTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(height: UiTokens.space8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[
            const SizedBox(height: UiTokens.space8),
            action!,
          ],
        ],
      ),
    );
  }
}
