import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResizableDatabaseTableColumn {
  const ResizableDatabaseTableColumn({
    required this.keyName,
    required this.label,
    this.semanticLabel,
    this.defaultWidth = 180,
    this.minWidth = 120,
    this.maxWidth = 640,
    this.resizable = true,
  }) : assert(defaultWidth > 0),
       assert(minWidth > 0),
       assert(maxWidth >= minWidth);

  final String keyName;
  final Widget label;
  final String? semanticLabel;
  final double defaultWidth;
  final double minWidth;
  final double maxWidth;
  final bool resizable;
}

class ResizableDatabaseTableCell {
  const ResizableDatabaseTableCell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;
}

class ResizableDatabaseTableRow {
  const ResizableDatabaseTableRow({
    required this.cells,
    this.selected = false,
    this.onSelectChanged,
  });

  final List<ResizableDatabaseTableCell> cells;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;
}

class ResizableDatabaseTable extends StatefulWidget {
  const ResizableDatabaseTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.onWidthCommitted,
    this.initialWidths = const <String, dynamic>{},
  });

  final List<ResizableDatabaseTableColumn> columns;
  final List<ResizableDatabaseTableRow> rows;
  final Map<String, dynamic> initialWidths;
  final Future<void> Function(String key, double width) onWidthCommitted;

  @override
  State<ResizableDatabaseTable> createState() => _ResizableDatabaseTableState();
}

class _ResizableDatabaseTableState extends State<ResizableDatabaseTable> {
  static const _keyboardStep = 16.0;

  late Map<String, double> _widths;
  Future<void> _commitTail = Future<void>.value();
  final Map<String, double> _pendingWidths = <String, double>{};
  String? _draggingKey;
  bool _dragDirty = false;

  @override
  void initState() {
    super.initState();
    _widths = _resolvedInitialWidths(widget.initialWidths);
  }

  @override
  void didUpdateWidget(covariant ResizableDatabaseTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = oldWidget.columns.map((column) => column.keyName).toList();
    final newKeys = widget.columns.map((column) => column.keyName).toList();
    final keysChanged = !_sameKeys(oldKeys, newKeys);
    final externalWidthsChanged = _externalWidthsChanged(oldWidget);
    if (!keysChanged && !externalWidthsChanged) return;

    final next = <String, double>{};
    for (final column in widget.columns) {
      final key = column.keyName;
      final current = _widths[key];
      if (key == _draggingKey) {
        next[key] = current ?? _initialWidth(column, widget.initialWidths);
        continue;
      }
      if (externalWidthsChanged) {
        final external = _initialWidth(column, widget.initialWidths);
        final pending = _pendingWidths[key];
        next[key] = pending != null && pending != external
            ? current ?? pending
            : external;
        continue;
      }
      next[key] = current ?? _initialWidth(column, widget.initialWidths);
    }
    _widths = next;
    _pendingWidths.removeWhere((key, _) => !newKeys.contains(key));
  }

  bool _sameKeys(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _externalWidthsChanged(ResizableDatabaseTable oldWidget) {
    for (final column in widget.columns) {
      final oldColumn = oldWidget.columns
          .where((candidate) => candidate.keyName == column.keyName)
          .firstOrNull;
      if (oldColumn == null) continue;
      final oldWidth = _initialWidth(oldColumn, oldWidget.initialWidths);
      final newWidth = _initialWidth(column, widget.initialWidths);
      if (oldWidth != newWidth) return true;
    }
    return false;
  }

  Map<String, double> _resolvedInitialWidths(Map<String, dynamic> widths) => {
    for (final column in widget.columns)
      column.keyName: _initialWidth(column, widths),
  };

  double _initialWidth(
    ResizableDatabaseTableColumn column,
    Map<String, dynamic> widths,
  ) {
    final raw = widths[column.keyName];
    final stored = raw is num ? raw.toDouble() : null;
    final candidate = stored != null && stored.isFinite
        ? stored
        : column.defaultWidth;
    return candidate.clamp(column.minWidth, column.maxWidth).toDouble();
  }

  double _widthFor(ResizableDatabaseTableColumn column) =>
      _widths[column.keyName] ?? _initialWidth(column, widget.initialWidths);

  void _beginDrag(ResizableDatabaseTableColumn column) {
    _draggingKey = column.keyName;
    _dragDirty = false;
  }

  void _updateWidth(ResizableDatabaseTableColumn column, double delta) {
    final current = _widthFor(column);
    final next = (current + delta)
        .clamp(column.minWidth, column.maxWidth)
        .toDouble();
    if (next == current) return;
    setState(() => _widths[column.keyName] = next);
    if (_draggingKey == column.keyName) _dragDirty = true;
  }

  void _enqueueCommit(String key, double width) {
    _pendingWidths[key] = width;
    _commitTail = _commitTail.then((_) async {
      await widget.onWidthCommitted(key, width);
      if (_pendingWidths[key] == width) {
        _pendingWidths.remove(key);
      }
    });
    unawaited(_commitTail.catchError((Object _) {}));
  }

  void _finishDrag(ResizableDatabaseTableColumn column) {
    final shouldCommit = _draggingKey == column.keyName && _dragDirty;
    _draggingKey = null;
    _dragDirty = false;
    if (shouldCommit) {
      _enqueueCommit(column.keyName, _widthFor(column));
    }
  }

  void _resizeFromKeyboard(ResizableDatabaseTableColumn column, double delta) {
    final before = _widthFor(column);
    _updateWidth(column, delta);
    final after = _widthFor(column);
    if (after != before) {
      _enqueueCommit(column.keyName, after);
    }
  }

  Widget _header(ResizableDatabaseTableColumn column) {
    final width = _widthFor(column);
    final label = SizedBox(
      key: ValueKey<String>('database-table-column-${column.keyName}'),
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(right: column.resizable ? 12 : 0),
          child: column.label,
        ),
      ),
    );
    if (!column.resizable) return label;

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: label),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 12,
            child: Semantics(
              button: true,
              label: '${column.semanticLabel ?? column.keyName} 列の幅を変更',
              child: FocusableActionDetector(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowLeft):
                      _ResizeColumnIntent(-_keyboardStep),
                  SingleActivator(LogicalKeyboardKey.arrowRight):
                      _ResizeColumnIntent(_keyboardStep),
                },
                actions: <Type, Action<Intent>>{
                  _ResizeColumnIntent: CallbackAction<_ResizeColumnIntent>(
                    onInvoke: (intent) {
                      _resizeFromKeyboard(column, intent.delta);
                      return null;
                    },
                  ),
                },
                child: Builder(
                  builder: (handleContext) => MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      key: ValueKey<String>(
                        'database-table-resize-${column.keyName}',
                      ),
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) => Focus.of(handleContext).requestFocus(),
                      onHorizontalDragStart: (_) => _beginDrag(column),
                      onHorizontalDragUpdate: (details) =>
                          _updateWidth(column, details.delta.dx),
                      onHorizontalDragEnd: (_) => _finishDrag(column),
                      onHorizontalDragCancel: () => _finishDrag(column),
                      child: const Center(
                        child: VerticalDivider(width: 1, thickness: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    ResizableDatabaseTableColumn column,
    ResizableDatabaseTableCell cell,
  ) => SizedBox(width: _widthFor(column), child: cell.child);

  @override
  Widget build(BuildContext context) {
    assert(
      widget.rows.every((row) => row.cells.length == widget.columns.length),
      'Every Table row must provide one cell for every column.',
    );
    return DataTable(
      columnSpacing: 0,
      columns: widget.columns
          .map((column) => DataColumn(label: _header(column)))
          .toList(growable: false),
      rows: widget.rows
          .map(
            (row) => DataRow(
              selected: row.selected,
              onSelectChanged: row.onSelectChanged,
              cells: List<DataCell>.generate(widget.columns.length, (index) {
                final cell = row.cells[index];
                return DataCell(
                  _cell(widget.columns[index], cell),
                  onTap: cell.onTap,
                );
              }, growable: false),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ResizeColumnIntent extends Intent {
  const _ResizeColumnIntent(this.delta);

  final double delta;
}
