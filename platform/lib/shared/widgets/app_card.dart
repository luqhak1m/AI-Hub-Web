import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// Card shells. [standard] is the grey tonal gradient used almost everywhere.
/// [accent] is the blue reminder gradient — Reminder cards only.
/// [emphasis] is solid navy with white text, for singling one card out of a
/// group (e.g. the Pro plan).
enum CardShell { standard, accent, emphasis }

/// A small chip under the title (e.g. RIASEC dimensions on assessment
/// results). Filled = emphasized (navy), outlined = muted (white).
class CardTag {
  final String label;
  final bool filled;
  const CardTag(this.label, {this.filled = false});
}

/// One icon + text row in a detail-rows description. Detail rows are for
/// structured data only (email, phone, quotas, feature lists) — sentences
/// belong in a paragraph description.
class CardDetail {
  final IconData icon;
  final String text;
  const CardDetail(this.icon, this.text);
}

/// The one card used across the app — see docs/card-system.md for the full
/// contract. Slots:
///
///   leading      [icon] on a tile (bare white icon on accent), or an [image]
///   title        required, bold, one line
///   [inlineTag]  small chip right after the title (e.g. "CURRENT PLAN")
///   [titleMeta]  right end of the title row: post age or price — never both
///   description  optional, at most one of [description] (paragraph, no
///                icons) or [details] (icon + text rows)
///   footer       at most one of [status] (white chip) or [buttonLabel]
///                (navy pill, accent shell only)
///
/// [compact] is the list-item density (notifications, job lists).
/// [highlighted] marks unread: navy hairline + filled navy icon tile.
class AppCard extends StatelessWidget {
  final CardShell shell;
  final bool compact;

  /// Square grid tile (home 2x2): icon on top, title under it, status at the
  /// bottom. Fixed-size by the grid, so no description.
  final bool tile;
  final bool highlighted;
  final IconData? icon;
  final Widget? image;
  final String title;
  final String? inlineTag;
  final String? titleMeta;

  /// Optional chip row under the title (e.g. Holland-code dimensions).
  final List<CardTag>? tags;

  /// Value pinned to the right end of the tag row (e.g. a match score).
  /// Lives here rather than on the title row so a long title keeps its space.
  final String? tagsMeta;
  final String? description;
  final List<CardDetail>? details;
  final String? status;
  final IconData? statusIcon;
  final VoidCallback? onStatusTap;
  final String? buttonLabel;

  /// Small action buttons rendered bottom-right (list-item cards like
  /// applications). Mutually exclusive with [buttonLabel].
  final List<Widget>? actions;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.title,
    this.shell = CardShell.standard,
    this.compact = false,
    this.tile = false,
    this.highlighted = false,
    this.icon,
    this.image,
    this.inlineTag,
    this.titleMeta,
    this.tags,
    this.tagsMeta,
    this.description,
    this.details,
    this.status,
    this.statusIcon,
    this.onStatusTap,
    this.buttonLabel,
    this.actions,
    this.onTap,
  })  : assert(description == null || details == null,
            'A card has at most one description form: paragraph OR detail rows'),
        assert(icon == null || image == null,
            'Leading visual is an icon or an image, never both'),
        assert(status == null || buttonLabel == null,
            'Footer is a status chip or a button, never both'),
        assert(buttonLabel == null || shell == CardShell.accent,
            'Buttons are only allowed on the accent (reminder) card'),
        assert(actions == null || buttonLabel == null,
            'Footer has either an actions row or an accent button, not both'),
        assert(!(tile && compact), 'A card is either a tile or a list item'),
        assert(!tile || (description == null && details == null),
            'Tiles are title + status only — there is no room for a body');

  bool get _dark => shell != CardShell.standard;
  Color _fg(UiTokens ui) => _dark ? Colors.white : ui.ink;
  bool get _hasBody => description != null || details != null;

  // Drawn in the web design system (shared/ui): white panel with a hairline
  // border, amber icon on a grey tile, pills for status — the drafts' `.panel`,
  // `.a-tool` and `.c-row`. The slot contract above is unchanged.

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Clickable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: tile
            ? const EdgeInsets.all(16)
            : compact
                ? const EdgeInsets.all(14)
                : EdgeInsets.all(18),
        decoration: _decoration(ui),
        child: tile ? _buildTile(ui) : compact ? _buildCompact(ui) : _buildRegular(ui),
      ),
    );
  }

  BoxDecoration _decoration(UiTokens ui) {
    final radius = BorderRadius.circular(compact ? 12 : Ui.radius);
    return switch (shell) {
      CardShell.standard => BoxDecoration(
          color: highlighted ? ui.brandSoft : ui.surface,
          borderRadius: radius,
          border: Border.all(color: highlighted ? ui.brandFill : ui.line),
        ),
      CardShell.accent => BoxDecoration(
          borderRadius: radius,
          gradient: ui.banner,
        ),
      CardShell.emphasis => BoxDecoration(color: ui.brandFill, borderRadius: radius),
    };
  }

  /// `.a-tool`: icon tile, uppercase title, status pill.
  Widget _buildTile(UiTokens ui) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_leading(ui) != null) _leading(ui)!,
          const SizedBox(height: 14),
          Text(title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ui.body(weight: FontWeight.w800, color: _dark ? Colors.white : ui.brand)
                  .copyWith(letterSpacing: 0.06 * Ui.step0)),
          const Spacer(),
          if (status != null) _statusChip(ui),
        ],
      );

  /// Standalone card: header row, then body, then one footer.
  Widget _buildRegular(UiTokens ui) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (_leading(ui) != null) ...[_leading(ui)!, const SizedBox(width: 14)],
            Expanded(child: _titleAndTag(ui, Ui.step1)),
            if (titleMeta != null) _meta(ui),
          ]),
          if (tags != null && tags!.isNotEmpty) ...[const SizedBox(height: 10), _tagsRow(ui)],
          if (_hasBody) ...[const SizedBox(height: 12), _body(ui)],
          if (status != null) ...[const SizedBox(height: 14), _statusChip(ui)],
          if (buttonLabel != null) ...[const SizedBox(height: 16), _button(ui)],
          if (actions != null && actions!.isNotEmpty) ...[const SizedBox(height: 14), _actionsRow()],
        ],
      );

  /// `.c-row` density for lists.
  Widget _buildCompact(UiTokens ui) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_leading(ui) != null) ...[_leading(ui)!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _titleAndTag(ui, Ui.step0)),
                if (titleMeta != null) _meta(ui),
              ]),
              if (tags != null && tags!.isNotEmpty) ...[const SizedBox(height: 6), _tagsRow(ui)],
              if (_hasBody) ...[const SizedBox(height: 2), _body(ui)],
              if (status != null) ...[const SizedBox(height: 8), _statusChip(ui)],
              if (actions != null && actions!.isNotEmpty) ...[const SizedBox(height: 10), _actionsRow()],
            ]),
          ),
        ],
      );

  Widget? _leading(UiTokens ui) {
    if (image != null) return image;
    if (icon == null) return null;
    if (shell == CardShell.accent) return Icon(icon, size: 24, color: Colors.white);
    if (highlighted) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: ui.brandFill, borderRadius: BorderRadius.circular(Ui.radiusSm)),
        child: Icon(icon, size: 19, color: Colors.white),
      );
    }
    if (shell == CardShell.emphasis) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(Ui.radiusSm)),
        child: Icon(icon, size: 19, color: ui.accent),
      );
    }
    return IconTile(icon!);
  }

  Widget _titleAndTag(UiTokens ui, double size) {
    final text = Text(title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: compact ? ui.body(size: size, weight: FontWeight.w700, color: _fg(ui)) : ui.display(size, color: _fg(ui)));
    if (inlineTag == null) return text;
    return Row(children: [
      Flexible(child: text),
      const SizedBox(width: 8),
      Pill(inlineTag!, tone: _dark ? Tone.plain : Tone.brand),
    ]);
  }

  Widget _meta(UiTokens ui) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text(titleMeta!,
            style: ui.body(
                size: compact ? Ui.step_1 : Ui.step0,
                weight: compact ? FontWeight.w400 : FontWeight.w700,
                color: _dark ? Colors.white.withValues(alpha: 0.85) : (compact ? ui.muted : ui.ink))),
      );

  Widget _body(UiTokens ui) {
    final muted = _dark ? Colors.white.withValues(alpha: 0.85) : ui.muted;
    if (description != null) {
      return Text(description!,
          maxLines: compact ? 3 : null,
          overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
          style: ui.body(size: compact ? Ui.step_1 : Ui.step0, color: muted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final d in details!)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(d.icon, size: 16, color: _dark ? ui.accent : ui.good),
            const SizedBox(width: 8),
            Expanded(
              child: Text(d.text,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ui.body(color: _dark ? Colors.white : ui.ink)),
            ),
          ]),
        ),
    ]);
  }

  Widget _tagsRow(UiTokens ui) {
    final chips = Wrap(spacing: 6, runSpacing: 6, children: [
      for (final tag in tags!) Pill(tag.label, tone: tag.filled ? Tone.brand : Tone.plain),
    ]);
    if (tagsMeta == null) return chips;
    return Row(children: [
      Expanded(child: chips),
      const SizedBox(width: 10),
      Text(tagsMeta!, style: ui.body(weight: FontWeight.w700, color: _dark ? Colors.white : ui.good)
          .copyWith(fontFeatures: Ui.tabular)),
    ]);
  }

  /// Wraps onto a second line when the card is narrow instead of overflowing.
  Widget _actionsRow() => Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions!);

  Widget _statusChip(UiTokens ui) {
    final chip = Pill(status!, tone: _dark ? Tone.plain : Tone.brand, icon: statusIcon);
    return Clickable(onTap: onStatusTap, child: chip);
  }

  Widget _button(UiTokens ui) => UiButton.accent(buttonLabel!, onPressed: onTap);
}
