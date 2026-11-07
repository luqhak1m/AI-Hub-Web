import 'package:flutter/material.dart';

/// AidVise brand styling — reference mockups in docs/skeleton/AidVise Interface.
abstract final class AppTheme {
  /// Buttons and all text (headings bold, body regular).
  static const Color primary = Color(0xFF013A63);

  /// Card icons.
  static const Color accent = Color(0xFFFFB703);

  /// Errors and destructive actions.
  static const Color danger = Color(0xFFEF233C);

  /// Grey card background (unchanged from the original design).
  static const Color cardGrey = Color(0xFFF5F5F5);

  /// Tonal ramp of the card grey — same neutral hue in a few strengths so a
  /// card reads layered instead of flat: solid body, deeper icon tile,
  /// hairline edges, white status chip. No gradients.
  static const Color cardGreyDeep = Color(0xFFE4E4E4);

  /// Decorative corner wedge on grid tiles.
  static const Color cardGreyWedge = Color(0xFFEBEBEB);
  static const Color cardHairline = Color(0xFFDEDEDE);

  /// Drop shadow under every card: straight down (6 o'clock), 4pt distance,
  /// 10pt blur; negative spread pulls it in to ~90% of the card's width.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 4),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];

  /// Sidebar (drawer) background.
  static const Color sidebar = Color(0xFF457B9D);

  /// Reminder-card gradient — the one card allowed a gradient.
  static const LinearGradient reminderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1173B0), Color(0xFF89D8E9)],
  );
}
