import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// Older colour names, kept so screens written before the web design system
/// still compile. Every value now comes from the drafts' tokens ([Ui]);
/// new code uses [Ui] directly.
abstract final class AppTheme {
  static const Color primary = Ui.brand;
  static const Color accent = Ui.accent;
  static const Color danger = Ui.bad;
  static const Color cardGrey = Ui.surface;
  static const Color cardGreyDeep = Ui.surface2;
  static const Color cardGreyWedge = Ui.surface2;
  static const Color cardHairline = Ui.line;

  /// The drafts mark surfaces with a hairline border, not a shadow.
  static const List<BoxShadow> cardShadow = [];
  static const Color sidebar = Ui.steel;
  static const LinearGradient reminderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D5A8F), Ui.brandFill], // = DraftLightPalette.bannerGradient
  );
}
