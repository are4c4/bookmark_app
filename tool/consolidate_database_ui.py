from pathlib import Path

# Bookmark toolbar: use the single shared DatabasePageToolbar implementation.
page = Path('lib/views/bookmark_unified_stage1_page.dart')
text = page.read_text()
text = text.replace(
    "import '../features/database/presentation/widgets/database_toolbar.dart';",
    "import '../features/database/presentation/widgets/database_page_toolbar.dart';",
)
text = text.replace('    return DatabaseToolbar(\n', '    return DatabasePageToolbar(\n', 1)
text = text.replace(
    "      searchController: _searchController,\n      onSearchChanged: (value) => setState(() {",
    "      searchHint: '検索',\n      searchValue: _query,\n      onSearchChanged: (value) => setState(() {",
    1,
)
page.write_text(text)

# Shared view tabs should use its sibling create widgets, not compatibility exports.
tabs = Path('lib/features/database/presentation/widgets/database_view_tabs.dart')
t = tabs.read_text()
t = t.replace("import '../../../../widgets/database_create_tiles.dart';", "import 'database_create_tiles.dart';")
tabs.write_text(t)

# Generic DB: use the shared property formatter for compact/gallery/table values.
generic = Path('lib/views/generic_database_page.dart')
g = generic.read_text()
marker = "import '../database/database_definition.dart';\n"
shared_import = "import '../features/database/presentation/database_property_presenter.dart';\n"
if shared_import not in g:
    if marker not in g:
        raise SystemExit('generic import marker not found')
    g = g.replace(marker, marker + shared_import, 1)
start = g.index('  String _displayValue(GenericPropertyRecord property, dynamic value) {')
end = g.index('\n  Widget _gallery', start)
g = g[:start] + "  String _displayValue(GenericPropertyRecord property, dynamic value) =>\n      formatDatabasePropertyValue(_databasePropertyType(property.type), value);\n" + g[end:]
generic.write_text(g)

# Widget test: use the consolidated shared toolbar API.
test = Path('test/database_interaction_widgets_test.dart')
s = test.read_text()
s = s.replace(
    "import 'package:bookmark_app/features/database/presentation/widgets/database_toolbar.dart';",
    "import 'package:bookmark_app/features/database/presentation/widgets/database_page_toolbar.dart';",
)
s = s.replace("    final controller = TextEditingController();\n    addTearDown(controller.dispose);\n\n", "")
s = s.replace('            body: DatabaseToolbar(\n', '            body: DatabasePageToolbar(\n')
s = s.replace("              searchController: controller,\n", "              searchHint: '検索',\n              searchValue: query,\n")
test.write_text(s)
