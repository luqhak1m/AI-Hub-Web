import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// Building blocks of the web pages. Each one mirrors a class in the layout
/// drafts (AI-Hub-Web/draft/drafts.css); the comment names it.

/// Makes any widget clickable with a pointer cursor.
class Clickable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Clickable({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => onTap == null
      ? child
      : MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
        );
}

/// `.eyebrow` — small uppercase label above a heading.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: context.ui.eyebrow.copyWith(color: color));
}

/// `.wordmark` — "Aid" in the surface colour, "Vise" in amber.
class Wordmark extends StatelessWidget {
  final bool onDark;
  final double size;
  const Wordmark({super.key, this.onDark = false, this.size = 20});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Aid', style: context.ui.display(size, color: onDark ? Colors.white : context.ui.brand, weight: FontWeight.w800)),
          TextSpan(text: 'Vise', style: context.ui.display(size, color: context.ui.accent, weight: FontWeight.w800)),
        ]),
      );
}

/// `.avatar` — initials on amber.
class UiAvatar extends StatelessWidget {
  final String name;
  final double size;
  /// Default: amber with dark text, from the tokens.
  final Color? background;
  final Color? foreground;
  const UiAvatar(this.name, {super.key, this.size = 34, this.background, this.foreground});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background ?? context.ui.accent, shape: BoxShape.circle),
        child: Text(initials(name),
            style: context.ui.body(size: size * 0.36, weight: FontWeight.w700, color: foreground ?? context.ui.onAccent)),
      );
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// `.logo` — a company's initials on a colour picked from its name, so the
/// same company always gets the same tile.
class LogoTile extends StatelessWidget {
  final String name;
  final double size;
  const LogoTile(this.name, {super.key, this.size = 40});

  static const _colors = [
    Color(0xFF013A63), Color(0xFFB5179E), Color(0xFF2A9D8F), Color(0xFF8D5524), Color(0xFF6A4C93),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.codeUnits.fold<int>(0, (a, c) => a + c) % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size / 4)),
      child: Text(initials(name),
          style: context.ui.display(size * 0.32, color: Colors.white, weight: FontWeight.w800)),
    );
  }
}

/// `.ico-tile` — amber icon on a grey tile.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconTile(this.icon, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.ui.surface2, borderRadius: BorderRadius.circular(Ui.radiusSm)),
        child: Icon(icon, size: size * 0.48, color: context.ui.warn),
      );
}

enum Tone { good, warn, bad, brand, plain }

/// A pill's colours. [Tone]s map to these through the palette; pass one
/// directly for a colour the tones don't cover.
class PillStyle {
  final Color background;
  final Color foreground;
  const PillStyle({required this.background, required this.foreground});

  static PillStyle of(Tone tone, UiTokens ui) => switch (tone) {
        Tone.good => PillStyle(background: ui.goodSoft, foreground: ui.good),
        Tone.warn => PillStyle(background: ui.warnSoft, foreground: ui.warn),
        Tone.bad => PillStyle(background: ui.badSoft, foreground: ui.bad),
        Tone.brand => PillStyle(background: ui.brandSoft, foreground: ui.brand),
        Tone.plain => PillStyle(background: ui.surface2, foreground: ui.muted),
      };
}

/// `.pill` — rounded status label.
class Pill extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;

  /// Overrides [tone] for one-off colours (a special case), e.g.
  /// `Pill('Beta', style: PillStyle(background: ..., foreground: ...))`.
  final PillStyle? style;
  const Pill(this.text, {super.key, this.tone = Tone.plain, this.icon, this.style});


  @override
  Widget build(BuildContext context) {
    final resolved = style ?? PillStyle.of(tone, context.ui);
    final (bg, fg) = (resolved.background, resolved.foreground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 5)],
        Text(text, style: context.ui.body(size: Ui.step_1, weight: FontWeight.w600, color: fg, height: 1.3)),
      ]),
    );
  }
}

/// `.chip` — small grey tag; navy when selected (filters).
class UiChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const UiChip(this.text, {super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: selected ? context.ui.brandFill : context.ui.surface2, borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              style: context.ui.body(size: Ui.step_1, color: selected ? context.ui.onBrand : context.ui.ink, height: 1.4)),
        ),
      );
}

enum ButtonKind { primary, accent, ghost }

/// A button's colours. [ButtonKind]s map to these through the palette; pass
/// one directly for a special case (e.g. a destructive button).
class UiButtonStyle {
  final Color background;
  final Color foreground;
  final Color border;
  const UiButtonStyle({required this.background, required this.foreground, this.border = Colors.transparent});

  static UiButtonStyle of(ButtonKind kind, UiTokens ui) => switch (kind) {
        ButtonKind.primary => UiButtonStyle(background: ui.brandFill, foreground: ui.onBrand),
        ButtonKind.accent => UiButtonStyle(background: ui.accent, foreground: ui.onAccent),
        ButtonKind.ghost => UiButtonStyle(background: Colors.transparent, foreground: ui.brand, border: ui.line),
      };

  /// Red fill for actions that delete or withdraw.
  static UiButtonStyle danger(UiTokens ui) => UiButtonStyle(background: ui.bad, foreground: ui.onBrand);
}

/// `.btn` — primary (navy), accent (amber) or ghost (outlined), or any
/// [UiButtonStyle].
class UiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonKind kind;

  /// Overrides [kind] for colours the kinds don't cover.
  final UiButtonStyle? style;
  final IconData? icon;
  final bool busy;
  final bool dense;
  const UiButton(this.label,
      {super.key,
      this.onPressed,
      this.kind = ButtonKind.primary,
      this.style,
      this.icon,
      this.busy = false,
      this.dense = false});

  const UiButton.ghost(this.label, {super.key, this.onPressed, this.icon, this.busy = false, this.dense = false})
      : kind = ButtonKind.ghost,
        style = null;

  const UiButton.accent(this.label, {super.key, this.onPressed, this.icon, this.busy = false, this.dense = false})
      : kind = ButtonKind.accent,
        style = null;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? UiButtonStyle.of(kind, context.ui);
    final (bg, fg, border) = (resolved.background, resolved.foreground, resolved.border);
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: Clickable(
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 5 : 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Ui.radiusSm),
            border: Border.all(color: border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else if (icon != null)
              Icon(icon, size: 16, color: fg),
            if (busy || icon != null) const SizedBox(width: 8),
            Text(label, style: context.ui.body(weight: FontWeight.w600, color: fg, height: 1.3)),
          ]),
        ),
      ),
    );
  }
}

/// `.panel` / `.g-card` — white surface with a hairline border.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Default: the palette's surface.
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Ui.radius,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? context.ui.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? context.ui.line),
          ),
          child: child,
        ),
      );
}

/// `.bar` — thin progress bar; amber for highlighted values.
class ScoreBar extends StatelessWidget {
  final double value; // 0..1
  final bool amber;
  final double? width;
  const ScoreBar(this.value, {super.key, this.amber = false, this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 6,
            backgroundColor: context.ui.surface2,
            valueColor: AlwaysStoppedAnimation(amber ? context.ui.accent : context.ui.brandFill),
          ),
        ),
      );
}

/// `.stat` — label over a big number.
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  const StatBox(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        radius: 12,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.ui.meta),
          Text(value, style: context.ui.display(Ui.step2).copyWith(fontFeatures: Ui.tabular)),
        ]),
      );
}

/// `.f-stats` — a row of stat boxes sharing the width.
class StatsRow extends StatelessWidget {
  final List<(String, String)> stats;
  const StatsRow(this.stats, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final perRow = box.maxWidth < 520 ? 2 : stats.length;
        final width = (box.maxWidth - 10 * (perRow - 1)) / perRow;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (label, value) in stats) SizedBox(width: width, child: StatBox(label, value)),
        ]);
      });
}

/// `.content-head` — eyebrow, big title, actions on the right.
class ContentHead extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final List<Widget> actions;
  final double titleSize;
  const ContentHead(
      {super.key, this.eyebrow, required this.title, this.actions = const [], this.titleSize = Ui.step3});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (eyebrow != null) Eyebrow(eyebrow!),
            Text(title, style: context.ui.display(titleSize)),
          ]),
          if (actions.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ],
      );
}

/// `.section-title` — heading with a link on the right.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? link;
  final VoidCallback? onLink;
  const SectionTitle(this.title, {super.key, this.link, this.onLink});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: context.ui.display(Ui.step2))),
          if (link != null)
            Clickable(
              onTap: onLink,
              child: Text(link!, style: context.ui.body(size: Ui.step_1, weight: FontWeight.w600, color: context.ui.brand)),
            ),
        ],
      );
}

/// `.match` — green match percentage.
class MatchText extends StatelessWidget {
  final num? percent;
  final String suffix;
  const MatchText(this.percent, {super.key, this.suffix = ''});

  @override
  Widget build(BuildContext context) => Text(
        percent == null ? '—' : '${percent!.round()}%$suffix',
        style: context.ui.body(weight: FontWeight.w700, color: context.ui.good).copyWith(fontFeatures: Ui.tabular),
      );
}

/// `.c-row` — one row of a list + detail list.
class ListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? sub;
  final Widget? trailing;
  final bool selected;
  final bool unread;
  final VoidCallback? onTap;
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.sub,
    this.trailing,
    this.selected = false,
    this.unread = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? context.ui.brandSoft : context.ui.surface,
            border: Border(
              bottom: BorderSide(color: context.ui.line),
              left: BorderSide(color: selected ? context.ui.brandFill : Colors.transparent, width: 3),
            ),
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ui.body(weight: unread ? FontWeight.w800 : FontWeight.w700)),
                if (sub != null && sub!.isNotEmpty)
                  Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ui.meta),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      );
}

/// `.c-facts` — a row of label/value boxes.
class FactsRow extends StatelessWidget {
  final List<(String, Widget)> facts;
  const FactsRow(this.facts, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final stacked = box.maxWidth < 480;
        final width = stacked ? box.maxWidth : (box.maxWidth - 10 * (facts.length - 1)) / facts.length;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (label, value) in facts)
            SizedBox(
              width: width,
              child: Panel(
                padding: const EdgeInsets.all(12),
                radius: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: context.ui.meta),
                  DefaultTextStyle(style: context.ui.body(size: Ui.step1, weight: FontWeight.w700), child: value),
                ]),
              ),
            ),
        ]);
      });
}

/// `.c-score .line` — label, bar, value.
class ScoreLine extends StatelessWidget {
  final String label;
  final String? hint;
  final double value; // 0..1
  final String valueText;
  final bool amber;
  final bool bold;
  const ScoreLine(this.label, this.value, this.valueText,
      {super.key, this.hint, this.amber = false, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 140,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: label, style: context.ui.body(size: Ui.step_1, weight: bold ? FontWeight.w700 : FontWeight.w400)),
            if (hint != null) TextSpan(text: ' $hint', style: context.ui.meta),
          ])),
        ),
        const SizedBox(width: 12),
        Expanded(child: ScoreBar(value, amber: amber)),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(valueText,
              textAlign: TextAlign.right,
              style: context.ui.body(size: Ui.step_1, weight: bold ? FontWeight.w700 : FontWeight.w400)
                  .copyWith(fontFeatures: Ui.tabular)),
        ),
      ]);
}

/// Loading / error / empty states, in the page's voice.
class UiState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final bool empty;
  final String emptyText;
  final Widget Function() builder;
  const UiState({
    super.key,
    required this.loading,
    this.error,
    this.onRetry,
    this.empty = false,
    this.emptyText = 'Nothing here yet.',
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator(color: context.ui.brandFill));
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, style: context.ui.body(color: context.ui.muted)),
          if (onRetry != null) ...[const SizedBox(height: 12), UiButton.ghost('Try again', onPressed: onRetry)],
        ]),
      );
    }
    if (empty) return Center(child: Text(emptyText, style: context.ui.body(color: context.ui.muted)));
    return builder();
  }
}

/// Date helpers shared by the pages.
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October',
  'November', 'December'
];

String shortDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  return d == null ? '' : '${d.day} ${_months[d.month - 1]}';
}

String longToday() {
  final d = DateTime.now();
  return '${_days[d.weekday - 1]}, ${d.day} ${_longMonths[d.month - 1]}';
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
}

String timeAgo(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return shortDate(iso);
}
