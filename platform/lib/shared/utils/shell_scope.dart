import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Tells a screen how the shell around it is laid out. With the sidebar
/// always open (wide screens) a section's first page needs no back arrow;
/// with the sidebar as a drawer, back on a section's first page goes home.
class ShellScope extends InheritedWidget {
  final bool wide;
  final VoidCallback goHome;

  const ShellScope({
    super.key,
    required this.wide,
    required this.goHome,
    required super.child,
  });

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => wide != oldWidget.wide;
}

/// The AppBar leading for a page that may be a section's first page: a back
/// arrow only when there is a page to go back to. The sidebar (or the top
/// bar on narrow windows) is always visible, so a section's first page needs
/// none — and popping it would leave the section empty.
Widget? sectionLeading(BuildContext context) {
  if (!Navigator.of(context).canPop()) return null;
  return IconButton(
    icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
    onPressed: () => Navigator.of(context).pop(),
  );
}
