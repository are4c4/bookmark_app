from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing patch target: {label}')
    return text.replace(old, new, 1)


bookmark_path = Path('lib/views/bookmark_unified_stage1_page.dart')
text = bookmark_path.read_text()

if "import 'dart:async';" not in text:
    text = replace_once(text, "import 'dart:io';", "import 'dart:async';\nimport 'dart:io';", 'dart async import')
if "../widgets/app_toast.dart" not in text:
    text = replace_once(
        text,
        "import '../widgets/bookmark_create_dialog.dart';",
        "import '../widgets/app_toast.dart';\nimport '../widgets/bookmark_create_dialog.dart';",
        'toast import',
    )

text = replace_once(
    text,
    "  double _detailWidth = 430;\n",
    "  double _detailWidth = 430;\n  Timer? _savedViewSaveTimer;\n",
    'autosave timer field',
)
text = replace_once(
    text,
    "  void dispose() {\n    _searchController.dispose();",
    "  void dispose() {\n    _savedViewSaveTimer?.cancel();\n    _searchController.dispose();",
    'dispose timer',
)
text = replace_once(
    text,
    "  void _resetFilters() {",
    "  void _markViewChanged() {\n"
    "    final id = _activeSavedViewId;\n"
    "    if (id == null) return;\n"
    "    _savedViewSaveTimer?.cancel();\n"
    "    _savedViewSaveTimer = Timer(const Duration(milliseconds: 550), () {\n"
    "      if (mounted && _activeSavedViewId == id) _updateActiveView();\n"
    "    });\n"
    "  }\n\n"
    "  void _resetFilters() {",
    'autosave method',
)

# A saved view behaves like Notion: edits mutate the active view instead of
# detaching from it. Debounce database writes while typing/searching.
text = text.replace('_activeSavedViewId = null;', '_markViewChanged();')
text = text.replace(
    "if (mounted && _activeSavedViewId == config.view.id) {\n      setState(() => _markViewChanged());\n    }",
    "if (mounted && _activeSavedViewId == config.view.id) {\n      _savedViewSaveTimer?.cancel();\n      setState(() => _activeSavedViewId = null);\n    }",
)

text = text.replace("                    if (value == 'update') _updateActiveView();\n", '')
text = text.replace(
    "                    if (_activeSavedViewId != null)\n"
    "                      const PopupMenuItem(\n"
    "                        value: 'update',\n"
    "                        child: Text('保存ビューを上書き'),\n"
    "                      ),\n",
    '',
)
text = text.replace(
    "                        if (value == 'update') {\n"
    "                          _applySavedView(config);\n"
    "                          _updateActiveView();\n"
    "                        }\n",
    '',
)
text = text.replace(
    "                        PopupMenuItem(\n"
    "                          value: 'update',\n"
    "                          child: Text('現在の設定で上書き'),\n"
    "                        ),\n",
    '',
)

old_delete = """      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: const Text('ブックマークをゴミ箱へ移動しました'),\n          action: SnackBarAction(\n            label: '元に戻す',\n            onPressed: () => widget.repository.restoreFromTrash(bookmark),\n          ),\n        ),\n      );"""
new_delete = """      showAppToast(\n        context,\n        'ブックマークをゴミ箱へ移動しました',\n        actionLabel: '元に戻す',\n        onAction: () => widget.repository.restoreFromTrash(bookmark),\n      );"""
if old_delete in text:
    text = text.replace(old_delete, new_delete, 1)

old_batch = """      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text('${selectedItems.length}件をゴミ箱へ移動しました'),\n          action: SnackBarAction(\n            label: '元に戻す',\n            onPressed: () async {\n              for (final bookmark in selectedItems) {\n                await widget.repository.restoreFromTrash(bookmark);\n              }\n            },\n          ),\n        ),\n      );"""
new_batch = """      showAppToast(\n        context,\n        '${selectedItems.length}件をゴミ箱へ移動しました',\n        actionLabel: '元に戻す',\n        onAction: () async {\n          for (final bookmark in selectedItems) {\n            await widget.repository.restoreFromTrash(bookmark);\n          }\n        },\n      );"""
if old_batch in text:
    text = text.replace(old_batch, new_batch, 1)

bookmark_path.write_text(text)


tag_path = Path('lib/views/tag_management_page.dart')
tag = tag_path.read_text()
if "../widgets/app_toast.dart" not in tag:
    tag = replace_once(
        tag,
        "import '../widgets/bookmark_reverse_lookup_dialog.dart';",
        "import '../widgets/app_toast.dart';\nimport '../widgets/bookmark_reverse_lookup_dialog.dart';",
        'tag toast import',
    )

old_drop = """      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(\n          content: Text('「${dragged.name}」を$destinationへ移動しました'),\n          action: SnackBarAction(\n            label: '元に戻す',\n            onPressed: () => _store.restoreMove(snapshot),\n          ),\n        ),\n      );"""
new_drop = """      showAppToast(\n        context,\n        '「${dragged.name}」を$destinationへ移動しました',\n        actionLabel: '元に戻す',\n        onAction: () => _store.restoreMove(snapshot),\n      );"""
tag = replace_once(tag, old_drop, new_drop, 'drag undo toast')

old_move = """    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(\n        content: Text('「${tag.name}」を移動しました'),\n        action: SnackBarAction(\n          label: '元に戻す',\n          onPressed: () => _store.restoreMove(snapshot),\n        ),\n      ),\n    );"""
new_move = """    showAppToast(\n      context,\n      '「${tag.name}」を移動しました',\n      actionLabel: '元に戻す',\n      onAction: () => _store.restoreMove(snapshot),\n    );"""
tag = replace_once(tag, old_move, new_move, 'move dialog undo toast')

tag_path.write_text(tag)
