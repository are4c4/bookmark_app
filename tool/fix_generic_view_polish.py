from pathlib import Path

p = Path('lib/views/bookmark_unified_stage1_page.dart')
s = p.read_text()
old = "if (width is num) _detailWidth = width.toDouble().clamp(320.0, 720.0);"
new = "if (width is num) {\n        _detailWidth = width.toDouble().clamp(320.0, 720.0).toDouble();\n      }"
if old not in s:
    raise RuntimeError('bookmark detail width anchor missing')
p.write_text(s.replace(old, new, 1))

p = Path('lib/widgets/database_page_toolbar.dart')
s = p.read_text()
old = """                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
"""
new = """                onChanged: (value) {
                  widget.onSearchChanged(value);
                  setState(() {});
                },
                decoration: InputDecoration(
"""
if old not in s:
    raise RuntimeError('toolbar search anchor missing')
p.write_text(s.replace(old, new, 1))

print('generic view polish applied')
