import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// The AidVise wordmark: "Aid" navy + "Vise" amber, bold italic
/// (docs/skeleton "Login page.png"). Never re-typeset it inline — use this so
/// the brand reads the same everywhere.
class AidViseWordmark extends StatelessWidget {
  final double fontSize;

  /// Colour of "Aid". Defaults to navy; pass white on dark surfaces such as
  /// the sidebar. "Vise" is always amber.
  final Color? aidColor;

  /// Shows the "Hack the Hustle" tagline underneath.
  final bool showTagline;

  const AidViseWordmark({
    super.key,
    this.fontSize = 42,
    this.aidColor,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    final aid = aidColor ?? AppTheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Aid', style: TextStyle(color: aid)),
              const TextSpan(
                  text: 'Vise', style: TextStyle(color: AppTheme.accent)),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: fontSize * 0.18),
          Text(
            'Hack the Hustle',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: aid,
              fontSize: fontSize * 0.42,
              fontWeight: FontWeight.w700,
              letterSpacing: fontSize * 0.055,
            ),
          ),
        ],
      ],
    );
  }
}
