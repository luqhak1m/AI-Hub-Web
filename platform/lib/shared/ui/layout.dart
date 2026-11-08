import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// Width below which every layout collapses to one column, as in the drafts'
/// `@container (max-width: 860px)` rules.
const double kUiNarrow = 860;

bool isNarrow(BuildContext context) => MediaQuery.of(context).size.width < kUiNarrow;

// ── Shell: `.a-wrap` / `.a-side` ────────────────────────────────────────────

class UiNavItem {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;
  const UiNavItem({required this.icon, required this.label, required this.onTap, this.badge = 0});
}

/// The app frame from the drafts: a steel-blue sidebar with the wordmark and
/// navigation, content on the page background. Narrow windows get the same
/// navigation as a bar across the top.
class UiShell extends StatelessWidget {
  final List<UiNavItem> items;
  final int selected;
  final Widget child;
  const UiShell({super.key, required this.items, required this.selected, required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrow(context);
    final nav = [
      for (var i = 0; i < items.length; i++) _NavLink(item: items[i], on: i == selected, compact: narrow),
    ];
    if (narrow) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: context.ui.steel,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: Row(children: [
              const Wordmark(onDark: true),
              const SizedBox(width: 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [for (final n in nav) Padding(padding: const EdgeInsets.only(right: 4), child: n)]),
                ),
              ),
            ]),
          ),
        ),
        Expanded(child: ColoredBox(color: context.ui.bg, child: child)),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 220,
        color: context.ui.steel,
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: SafeArea(
          right: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(left: 4), child: Wordmark(onDark: true)),
            const SizedBox(height: 22),
            for (final n in nav) Padding(padding: const EdgeInsets.only(bottom: 2), child: n),
          ]),
        ),
      ),
      Expanded(child: ColoredBox(color: context.ui.bg, child: child)),
    ]);
  }
}

class _NavLink extends StatelessWidget {
  final UiNavItem item;
  final bool on;
  final bool compact;
  const _NavLink({required this.item, required this.on, required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = on ? Colors.white : Colors.white.withValues(alpha: 0.82);
    return Clickable(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(Ui.radiusSm),
        ),
        child: Row(mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max, children: [
          Icon(item.icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(item.label,
              style: context.ui.body(color: color, weight: on ? FontWeight.w700 : FontWeight.w500, height: 1.3)),
          if (item.badge > 0) ...[
            if (compact) const SizedBox(width: 8) else const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: context.ui.accent, borderRadius: BorderRadius.circular(999)),
              child: Text('${item.badge}',
                  style: context.ui.body(size: 11, weight: FontWeight.w700, color: context.ui.onAccent, height: 1.4)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Page: `.a-main` ─────────────────────────────────────────────────────────

/// Content area padding and spacing. [fill] pages (list + detail, board)
/// take the remaining height; others scroll.
class UiPage extends StatelessWidget {
  final List<Widget> children;
  final bool fill;
  const UiPage({super.key, required this.children, this.fill = false});

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.all(isNarrow(context) ? 16 : 24);
    if (fill) {
      return Padding(
        padding: pad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(children)),
      );
    }
    return SingleChildScrollView(
      padding: pad,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gapped(children)),
    );
  }

  static List<Widget> _gapped(List<Widget> children) => [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 20), children[i]],
      ];
}

// ── List + detail: `.c-wrap` ────────────────────────────────────────────────

/// List on the left (white), detail on the right (page background), inside
/// one bordered frame. Narrow windows show the list only — the page opens
/// details on their own screen (see [openDetailPage]).
class UiListDetail extends StatelessWidget {
  final Widget? header; // e.g. filter chips above the list
  final List<Widget> rows;
  final Widget? detail;
  final String emptyDetail;
  final double listWidth;
  const UiListDetail({
    super.key,
    this.header,
    required this.rows,
    required this.detail,
    this.emptyDetail = 'Select an item to see its details.',
    this.listWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    final list = Container(
      color: context.ui.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.ui.line))),
            child: header,
          ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: rows)),
      ]),
    );
    Widget framed(Widget child) => Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.ui.line),
            borderRadius: BorderRadius.circular(Ui.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
    if (isNarrow(context)) return framed(list);
    return framed(Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: listWidth, child: list),
      VerticalDivider(width: 1, color: context.ui.line),
      Expanded(
        child: ColoredBox(
          color: context.ui.bg,
          child: detail == null
              ? Center(child: Text(emptyDetail, style: context.ui.body(color: context.ui.muted)))
              : SingleChildScrollView(padding: const EdgeInsets.all(26), child: detail),
        ),
      ),
    ]));
  }
}

/// Narrow windows: show a detail on its own screen with a back arrow.
Future<void> openDetailPage(BuildContext context, String title, Widget detail) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: context.ui.bg,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: detail),
    ),
  ));
}

// ── Board: `.e-board` / `.e-col` ────────────────────────────────────────────

class UiBoardColumn {
  final String title;
  final List<Widget> cards;
  final String emptyText;
  const UiBoardColumn(this.title, this.cards, {this.emptyText = 'Nothing here yet.'});
}

/// Columns on a grey ground; scrolls sideways when they don't fit.
class UiBoard extends StatelessWidget {
  final List<UiBoardColumn> columns;
  const UiBoard({super.key, required this.columns});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // 170 lets six stages fit beside the sidebar on a 1440 px screen.
        const gap = 12.0, minWidth = 170.0;
        final fit = (box.maxWidth - gap * (columns.length - 1)) / columns.length;
        final width = fit < minWidth ? minWidth : fit;
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(width: width, child: _column(context, columns[i])),
              ],
            ]),
          ),
        );
      });

  Widget _column(BuildContext context, UiBoardColumn c) => Container(
        constraints: const BoxConstraints(minHeight: 380),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.ui.surface2, borderRadius: BorderRadius.circular(Ui.radius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Row(children: [
              Expanded(child: Eyebrow(c.title)),
              Pill('${c.cards.length}'),
            ]),
          ),
          if (c.cards.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text(c.emptyText, style: context.ui.meta)),
          for (final card in c.cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
        ]),
      );
}

// ── Table: `.table-scroll table` ────────────────────────────────────────────

class UiTableRow {
  final List<Widget> cells;
  final VoidCallback? onTap;
  const UiTableRow(this.cells, {this.onTap});
}

/// Uppercase grey headings on a grey band, hairline rows, white surface.
class UiTable extends StatelessWidget {
  final List<String> columns;
  final List<UiTableRow> rows;
  final Set<int> numeric;
  const UiTable({super.key, required this.columns, required this.rows, this.numeric = const {}});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.ui.surface,
          border: Border.all(color: context.ui.line),
          borderRadius: BorderRadius.circular(Ui.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              // DataTable draws its row lines with the nearest DividerTheme.
              child: DividerTheme(
                data: DividerThemeData(color: context.ui.line, thickness: 1),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStatePropertyAll(context.ui.surface2),
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  horizontalMargin: 14,
                  columnSpacing: 28,
                  dividerThickness: 1,
                  headingTextStyle: context.ui.eyebrow.copyWith(fontWeight: FontWeight.w700),
                  dataTextStyle: context.ui.body(),
                  columns: [
                    for (var i = 0; i < columns.length; i++)
                      DataColumn(label: Text(columns[i].toUpperCase()), numeric: numeric.contains(i)),
                  ],
                  rows: [
                    for (final r in rows)
                      DataRow(
                        onSelectChanged: r.onTap == null ? null : (_) => r.onTap!(),
                        cells: [for (final c in r.cells) DataCell(c)],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
