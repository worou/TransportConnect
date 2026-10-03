import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import 'common.dart';

class TableColumn {
  const TableColumn(this.label, this.cell, {this.flex = 1, this.alignRight = false});

  final String label;
  final Widget Function(Map<String, dynamic> row) cell;
  final int flex;
  final bool alignRight;
}

/// Tableau paginé d'une collection API Platform (20 lignes par page, total Hydra).
class ResourceTable extends StatefulWidget {
  const ResourceTable({
    super.key,
    required this.path,
    required this.columns,
    this.query = const {},
    this.onTap,
    this.emptyMessage = 'Aucun élément.',
    this.bare = false,
  });

  final String path;
  final Map<String, String> query;
  final List<TableColumn> columns;
  final void Function(Map<String, dynamic> row)? onTap;
  final String emptyMessage;

  /// Sans carte autour (tableau intégré dans une carte existante).
  final bool bare;

  @override
  State<ResourceTable> createState() => ResourceTableState();
}

class ResourceTableState extends State<ResourceTable> {
  static const perPage = 20;

  int _page = 1;
  Future<ApiPage>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(ResourceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || !_sameQuery(oldWidget.query, widget.query)) {
      _page = 1;
      reload();
    }
  }

  void reload() => setState(() => _future = _load());

  Future<ApiPage> _load() => context.api.list(widget.path, query: {
        ...{for (final e in widget.query.entries) if (e.value.isNotEmpty) e.key: e.value},
        'page': '$_page',
      });

  static bool _sameQuery(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  Widget build(BuildContext context) {
    final table = FutureBuilder<ApiPage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorBox('${snapshot.error}', onRetry: reload);
            }
            if (!snapshot.hasData) {
              return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            }
            final page = snapshot.data!;
            final pages = (page.total / perPage).ceil().clamp(1, 1 << 30);

            return Column(
              children: [
                _header(),
                if (page.items.isEmpty)
                  Padding(padding: const EdgeInsets.all(40), child: Text(widget.emptyMessage, style: TC.caption)),
                for (final row in page.items) _row(row),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('${page.total} élément(s)', style: TC.caption),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Page précédente',
                        onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Page $_page / $pages', style: TC.caption),
                      IconButton(
                        tooltip: 'Page suivante',
                        onPressed: _page < pages ? () => _goTo(_page + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
    return widget.bare ? table : TcCard(padding: EdgeInsets.zero, child: table);
  }

  void _goTo(int page) {
    _page = page;
    reload();
  }

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: TC.gray100,
          borderRadius: widget.bare ? null : const BorderRadius.vertical(top: Radius.circular(TC.radiusLg)),
        ),
        child: Row(
          children: [
            for (final c in widget.columns)
              Expanded(
                flex: c.flex,
                child: Padding(
                  padding: EdgeInsets.only(right: c.alignRight ? 24 : 12),
                  child: Text(c.label.toUpperCase(), style: TC.tableHeader, textAlign: c.alignRight ? TextAlign.right : null),
                ),
              ),
          ],
        ),
      );

  Widget _row(Map<String, dynamic> row) => InkWell(
        onTap: widget.onTap == null ? null : () => widget.onTap!(row),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.gray200))),
          child: Row(
            children: [
              for (final c in widget.columns)
                Expanded(
                  flex: c.flex,
                  child: Padding(
                    padding: EdgeInsets.only(right: c.alignRight ? 24 : 12),
                    child: Align(alignment: c.alignRight ? Alignment.centerRight : Alignment.centerLeft, child: c.cell(row)),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// Texte de cellule tronqué proprement.
Widget cellText(Object? value, {bool bold = false}) => Text(
      '${value ?? '—'}',
      overflow: TextOverflow.ellipsis,
      style: bold ? TC.body.copyWith(fontWeight: FontWeight.w600) : TC.body,
    );
