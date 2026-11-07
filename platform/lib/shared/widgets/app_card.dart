import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

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

  /// Standalone, non-reminder cards get the label treatment: a tracked
  /// uppercase title over the sentence-case description.
  bool get _labelled => !compact && shell != CardShell.accent;
  Color get _fg => _dark ? Colors.white : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: _decoration(),
        child: tile
            // The wedge has to bleed to the card edges, so it sits under the
            // padding rather than outside it.
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(painter: _TileWedge()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: _buildTile(),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: compact
                    ? const EdgeInsets.all(14)
                    // Title-only cards (e.g. the home tools) sit tighter —
                    // there is no paragraph to give the card its height.
                    : _hasBody
                        ? const EdgeInsets.fromLTRB(20, 20, 20, 22)
                        : const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: compact ? _buildCompact() : _buildRegular(),
              ),
      ),
    );
  }

  BoxDecoration _decoration() {
    final radius = BorderRadius.circular(compact ? 18 : (tile ? 20 : 24));
    return switch (shell) {
      CardShell.standard => BoxDecoration(
          color: AppTheme.cardGrey,
          borderRadius: radius,
          border: Border.all(
            color: highlighted ? AppTheme.primary : AppTheme.cardHairline,
            width: highlighted ? 1.2 : 0.8,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
      CardShell.accent => BoxDecoration(
          gradient: AppTheme.reminderGradient,
          borderRadius: radius,
          boxShadow: AppTheme.cardShadow,
        ),
      CardShell.emphasis => BoxDecoration(
          color: AppTheme.primary,
          borderRadius: radius,
          boxShadow: AppTheme.cardShadow,
        ),
    };
  }

  /// Standalone density: header row, then description/details full-width,
  /// then the optional footer.
  Widget _buildRegular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_leading() != null) ...[_leading()!, const SizedBox(width: 16)],
            Expanded(child: _titleAndTag()),
            if (titleMeta != null) _meta(),
          ],
        ),
        if (tags != null && tags!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _tagsRow(),
        ],
        if (_hasBody) ...[
          SizedBox(height: _leading() == null ? 12 : 14),
          _body(),
        ],
        if (status != null) ...[
          SizedBox(height: _hasBody ? 20 : 12),
          Align(alignment: Alignment.centerRight, child: _statusChip()),
        ],
        if (buttonLabel != null) ...[const SizedBox(height: 18), _button()],
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _actionsRow(),
        ],
      ],
    );
  }

  /// Grid density: icon, then a wrapping title, with the status pinned to
  /// the bottom so every tile in a row lines up.
  Widget _buildTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_leading() != null) _leading()!,
        const SizedBox(height: 12),
        Text(
          title.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _fg,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            height: 1.25,
          ),
        ),
        const Spacer(),
        if (status != null) _statusChip(),
      ],
    );
  }

  /// List-item density: leading beside a column of title row + description.
  Widget _buildCompact() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_leading() != null) ...[_leading()!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _titleAndTag()),
                  if (titleMeta != null) _meta(),
                ],
              ),
              if (tags != null && tags!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _tagsRow(),
              ],
              if (_hasBody) ...[
                const SizedBox(height: 4),
                _body(),
              ],
              if (status != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: _statusChip()),
              ],
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _actionsRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget? _leading() {
    if (image != null) return image;
    if (icon == null) return null;
    if (shell == CardShell.accent) {
      return Icon(icon, size: compact ? 24 : 30, color: Colors.white);
    }
    final box = compact ? 40.0 : (tile ? 42.0 : (_hasBody ? 54.0 : 44.0));
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: switch (shell) {
          CardShell.emphasis => Colors.white.withValues(alpha: 0.15),
          _ => highlighted ? AppTheme.primary : AppTheme.cardGreyDeep,
        },
        borderRadius: BorderRadius.circular(compact || tile ? 12 : 16),
      ),
      child: Icon(icon,
          size: compact ? 22 : (tile ? 23 : (_hasBody ? 30 : 25)),
          color: highlighted ? Colors.white : AppTheme.accent),
    );
  }

  Widget _titleAndTag() {
    // Standalone cards set the title in tracked uppercase so it reads as a
    // label against the sentence-case description. List items keep their
    // natural casing — job titles and company names must stay readable.
    final text = Text(
      _labelled ? title.toUpperCase() : title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _fg,
        fontSize: compact ? 15.5 : (_labelled ? 17 : 19),
        fontWeight: FontWeight.bold,
        letterSpacing: _labelled ? 1.1 : 0,
      ),
    );
    if (inlineTag == null) return text;
    return Row(
      children: [
        Flexible(child: text),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _dark ? Colors.white : AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            inlineTag!,
            style: TextStyle(
              color: _dark ? AppTheme.primary : Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        titleMeta!,
        style: TextStyle(
          color: _fg,
          fontSize: compact ? 11.5 : 14,
          fontWeight: compact ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
    );
  }

  bool get _hasBody => description != null || details != null;

  Widget _body() {
    if (description != null) {
      return Text(
        description!,
        // Standalone cards show the whole paragraph; list items stay tidy.
        maxLines: compact ? 3 : null,
        overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
        style: TextStyle(
          // Same navy, held back so the title stays the loudest thing.
          color: _fg.withValues(alpha: _dark ? 0.85 : 0.72),
          fontSize: compact ? 12.5 : 14.5,
          height: 1.55,
        ),
      );
    }
    if (details == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in details!)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(d.icon,
                    size: 15, color: _fg.withValues(alpha: _dark ? 0.8 : 1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _fg, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tagsRow() {
    final chips = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              // Both states stay grey: navy is reserved for actions, so a tag
              // is never mistaken for a button.
              color: tag.filled ? AppTheme.cardGreyDeep : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: tag.filled ? AppTheme.cardGreyDeep : AppTheme.cardHairline,
              ),
            ),
            child: Text(
              tag.label,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 11,
                fontWeight: tag.filled ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
      ],
    );
    if (tagsMeta == null) return chips;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: chips),
        const SizedBox(width: 10),
        Text(
          tagsMeta!,
          // Monospace, like the status chip — figures read as data, not prose.
          style: TextStyle(
            color: _fg,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Courier'],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _actionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < actions!.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions![i],
        ],
      ],
    );
  }

  Widget _statusChip() {
    final chip = Container(
      width: tile ? double.infinity : null,
      padding: tile
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusIcon != null) ...[
            Icon(statusIcon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              status!,
              maxLines: tile ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              // Monospace "terminal" styling sets the status apart from the
              // title and description; same navy as everything else.
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: tile ? 10.5 : 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New', 'Courier'],
                letterSpacing: 0.4,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
    if (onStatusTap == null) return chip;
    return GestureDetector(onTap: onStatusTap, child: chip);
  }

  Widget _button() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        buttonLabel!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shading on grid tiles: a triangle spanning top-left, top-right and
/// bottom-right, a half step darker than the card body.
class _TileWedge extends CustomPainter {
  const _TileWedge();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.cardGreyWedge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
