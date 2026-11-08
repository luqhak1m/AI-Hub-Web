import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// A section inside a [showDetailSheet]: a grey heading band with an icon,
/// followed by its content.
class DetailSection {
  final String title;
  final IconData icon;
  final Widget child;
  const DetailSection({
    required this.title,
    this.icon = Icons.info_outline,
    required this.child,
  });
}

/// Everything a detail view shows. Built once per kind of item (job, career,
/// notification, applicant) and shown either as a bottom sheet
/// ([showDetailSpec]) or inline beside a list on wide screens ([DetailPane]).
class DetailSpec {
  final String title;
  final String? meta;
  final String? subtitle;
  final List<Widget> headerExtras;
  final List<DetailSection> sections;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final double initialSize;

  const DetailSpec({
    required this.title,
    this.meta,
    this.subtitle,
    this.headerExtras = const [],
    required this.sections,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionEnabled = true,
    this.initialSize = 0.6,
  });
}

Future<void> showDetailSpec(BuildContext context, DetailSpec spec) =>
    showDetailSheet(
      context,
      title: spec.title,
      meta: spec.meta,
      subtitle: spec.subtitle,
      headerExtras: spec.headerExtras,
      sections: spec.sections,
      actionLabel: spec.actionLabel,
      actionIcon: spec.actionIcon,
      onAction: spec.onAction,
      actionEnabled: spec.actionEnabled,
      initialSize: spec.initialSize,
    );

/// A detail view laid out inline — the right-hand side of a list + detail
/// page. Same header, sections and action as the sheet, without the grab
/// handle, and the action does not close anything.
class DetailPane extends StatelessWidget {
  final DetailSpec spec;
  const DetailPane({super.key, required this.spec});

  @override
  Widget build(BuildContext context) => _DetailSheet(
        controller: null,
        inline: true,
        title: spec.title,
        meta: spec.meta,
        subtitle: spec.subtitle,
        headerExtras: spec.headerExtras,
        sections: spec.sections,
        actionLabel: spec.actionLabel,
        actionIcon: spec.actionIcon,
        onAction: spec.onAction,
        actionEnabled: spec.actionEnabled,
      );
}

/// The app's one detail sheet: everything a card can expand into uses this so
/// job listings, career paths and notifications read the same way — grab
/// handle, header block, titled sections, and one pinned action at the foot.
Future<void> showDetailSheet(
  BuildContext context, {
  required String title,
  String? meta,
  String? subtitle,
  List<Widget> headerExtras = const [],
  required List<DetailSection> sections,
  String? actionLabel,
  IconData? actionIcon,
  VoidCallback? onAction,
  bool actionEnabled = true,
  double initialSize = 0.6,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.ui.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Ui.radius)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, controller) => _DetailSheet(
        controller: controller,
        title: title,
        meta: meta,
        subtitle: subtitle,
        headerExtras: headerExtras,
        sections: sections,
        actionLabel: actionLabel,
        actionIcon: actionIcon,
        onAction: onAction,
        actionEnabled: actionEnabled,
      ),
    ),
  );
}

class _DetailSheet extends StatelessWidget {
  final ScrollController? controller;

  /// Shown beside a list rather than in a sheet: no grab handle, and the
  /// action runs without dismissing anything.
  final bool inline;
  final String title;
  final String? meta;
  final String? subtitle;
  final List<Widget> headerExtras;
  final List<DetailSection> sections;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionEnabled;

  const _DetailSheet({
    required this.controller,
    this.inline = false,
    required this.title,
    required this.sections,
    this.meta,
    this.subtitle,
    this.headerExtras = const [],
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              if (!inline) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.ui.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _header(context),
              for (final section in sections) ...[
                const SizedBox(height: 22),
                sectionTitle(section.title, section.icon),
                const SizedBox(height: 10),
                section.child,
              ],
            ],
          ),
        ),
        if (actionLabel != null) _actionBar(context),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: context.ui.display(Ui.step2))),
            if (meta != null) ...[
              const SizedBox(width: 10),
              Text(meta!,
                  style: context.ui.body(weight: FontWeight.w700, color: context.ui.good).copyWith(fontFeatures: Ui.tabular)),
            ],
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: context.ui.meta),
        ],
        ...headerExtras,
      ],
    );
  }

  Widget _actionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.ui.surface,
        border: Border(top: BorderSide(color: context.ui.line)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: UiButton(
          actionLabel!,
          icon: actionIcon,
          onPressed: !actionEnabled || onAction == null
              ? null
              : () {
                  if (!inline) Navigator.of(context).pop();
                  onAction!();
                },
        ),
      ),
    );
  }
}

/// Section label used by every detail view — the drafts' `.eyebrow`.
Widget sectionTitle(String text, [IconData icon = Icons.info_outline]) => Eyebrow(text);
