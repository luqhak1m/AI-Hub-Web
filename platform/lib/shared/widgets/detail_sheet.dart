import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
  final ScrollController controller;
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _header(),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardGreyDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3),
                ),
              ),
              if (meta != null) ...[
                const SizedBox(width: 10),
                Text(
                  meta!,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Courier New', 'Courier'],
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                  color: AppTheme.primary, fontSize: 13.5, height: 1.5),
            ),
          ],
          ...headerExtras,
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          icon: Icon(actionIcon ?? Icons.arrow_forward, size: 18),
          label: Text(actionLabel!,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: const Color(0xFFE0E0E0),
            disabledForegroundColor: const Color(0xFF888888),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: !actionEnabled || onAction == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  onAction!();
                },
        ),
      ),
    );
  }
}

/// Grey heading band used by every detail sheet. Never navy — navy fills are
/// buttons, and a heading is not tappable.
Widget sectionTitle(String text, [IconData icon = Icons.info_outline]) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ],
      ),
    ),
  );
}
