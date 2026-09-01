from pathlib import Path
import re


def patch(path, transform):
    p = Path(path)
    text = p.read_text()
    new = transform(text)
    if new == text:
        raise SystemExit(f'no changes for {path}')
    p.write_text(new)


def clean_bookmark_page(text):
    new, count = re.subn(
        r"\n  String _roleValue\(List<PersonRoleAssignment> assignments, String role\) =>\n      assignments\n          \.where\(\(assignment\) => assignment\.role == role\)\n          \.map\(\(assignment\) => assignment\.person\.name\)\n          \.join\(', '\);\n",
        "\n",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit('roleValue target not found')
    return new


def clean_detail(text):
    text2, count = re.subn(
        r"\nconst _statusLabels = <String, String>\{.*?\};\n",
        "\n",
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise SystemExit('status labels target not found')
    text3, count = re.subn(
        r"\nextension _FirstOrNull<T> on Iterable<T> \{\n  T\? get firstOrNull => isEmpty \? null : first;\n\}\n?",
        "\n",
        text2,
        count=1,
    )
    if count != 1:
        raise SystemExit('detail firstOrNull target not found')
    return text3


def clean_reorder(text):
    old = """              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
"""
    new = """              onReorderItem: (oldIndex, newIndex) {
"""
    if old not in text:
        raise SystemExit('reorder target not found')
    return text.replace(old, new, 1)


patch('lib/views/bookmark_unified_stage1_page.dart', clean_bookmark_page)
patch('lib/widgets/bookmark_detail_panel.dart', clean_detail)
patch('lib/widgets/bookmark_reorderable_properties.dart', clean_reorder)
