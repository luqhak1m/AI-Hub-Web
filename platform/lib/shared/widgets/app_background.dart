import 'package:flutter/material.dart';

/// App-wide page background: the white plaster texture from the design kit
/// (docs/skeleton "background.jpg"), full-bleed behind the content. It does
/// not scroll.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
            // The source is 2959x4438 — decode at screen-ish width so the
            // texture doesn't cost ~50 MB of RAM.
            cacheWidth: 1200,
          ),
        ),
        child,
      ],
    );
  }
}
