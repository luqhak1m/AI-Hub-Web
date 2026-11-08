import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// The web design system's tokens, taken one-to-one from the layout drafts
// (AI-Hub-Web/draft/drafts.css).
//
// How it fits together:
//
//   UiPalette      interface: every colour a component may use
//   UiTypography   interface: the fonts and type scale
//   UiShape        corner radii
//   UiTokens       the three together, published to the widget tree as a
//                  ThemeExtension. Components read them with `context.ui`.
//
// To change the look everywhere, edit a palette or typography class. To
// restyle one part of the screen (a special case), wrap it in
// `UiScope(tokens: ...)` — every component inside follows. To add a palette
// (a brand variant, dark mode), implement UiPalette.

// ── Colour ──────────────────────────────────────────────────────────────────

/// Every colour a component may use, by role rather than by hue.
abstract interface class UiPalette {
  Color get bg; // page background
  Color get surface; // panels, cards, tables
  Color get surface2; // grey chips, board columns, icon tiles
  Color get surface3; // disabled fills
  Color get line; // hairline borders and dividers
  Color get ink; // body text
  Color get muted; // secondary text
  Color get brand; // navy text accents and links
  Color get brandFill; // navy filled surfaces and primary buttons
  Color get onBrand; // text on brandFill
  Color get brandSoft; // selected rows, brand pills
  Color get steel; // sidebar
  Color get accent; // amber
  Color get onAccent; // text on accent
  Color get good;
  Color get goodSoft;
  Color get warn;
  Color get warnSoft;
  Color get bad;
  Color get badSoft;

  /// The reminder banner's gradient (dark end last).
  List<Color> get bannerGradient;
  Brightness get brightness;
}

/// The drafts' light theme — the platform's look today.
final class DraftLightPalette implements UiPalette {
  const DraftLightPalette();
  @override Color get bg => const Color(0xFFEEF2F6);
  @override Color get surface => const Color(0xFFFFFFFF);
  @override Color get surface2 => const Color(0xFFE6ECF2);
  @override Color get surface3 => const Color(0xFFDBE3EB);
  @override Color get line => const Color(0xFFD3DCE5);
  @override Color get ink => const Color(0xFF0B2239);
  @override Color get muted => const Color(0xFF566A7E);
  @override Color get brand => const Color(0xFF013A63);
  @override Color get brandFill => const Color(0xFF013A63);
  @override Color get onBrand => const Color(0xFFFFFFFF);
  @override Color get brandSoft => const Color(0xFFDDE9F3);
  @override Color get steel => const Color(0xFF457B9D);
  @override Color get accent => const Color(0xFFFFB703);
  @override Color get onAccent => const Color(0xFF1C1400);
  @override Color get good => const Color(0xFF1F8A70);
  @override Color get goodSoft => const Color(0xFFDCF2EA);
  @override Color get warn => const Color(0xFFC77700);
  @override Color get warnSoft => const Color(0xFFFDF0D5);
  @override Color get bad => const Color(0xFFD62839);
  @override Color get badSoft => const Color(0xFFFBE1E4);
  @override List<Color> get bannerGradient => const [Color(0xFF0D5A8F), Color(0xFF013A63)];
  @override Brightness get brightness => Brightness.light;
}

/// The drafts' dark theme — the planned dark mode for web and mobile.
/// Ready to use: `Ui.theme(UiTokens.dark)`.
final class DraftDarkPalette implements UiPalette {
  const DraftDarkPalette();
  @override Color get bg => const Color(0xFF08141F);
  @override Color get surface => const Color(0xFF0F2131);
  @override Color get surface2 => const Color(0xFF152C41);
  @override Color get surface3 => const Color(0xFF1C3850);
  @override Color get line => const Color(0xFF23415C);
  @override Color get ink => const Color(0xFFE4EDF5);
  @override Color get muted => const Color(0xFF92A7BB);
  @override Color get brand => const Color(0xFF8CC4EC);
  @override Color get brandFill => const Color(0xFF1A5D92);
  @override Color get onBrand => const Color(0xFFFFFFFF);
  @override Color get brandSoft => const Color(0xFF16334D);
  @override Color get steel => const Color(0xFF2E5F80);
  @override Color get accent => const Color(0xFFFFC23D);
  @override Color get onAccent => const Color(0xFF1C1400);
  @override Color get good => const Color(0xFF4CC9A4);
  @override Color get goodSoft => const Color(0xFF12382F);
  @override Color get warn => const Color(0xFFF0A83A);
  @override Color get warnSoft => const Color(0xFF3A2C10);
  @override Color get bad => const Color(0xFFFF6B7A);
  @override Color get badSoft => const Color(0xFF3D1A20);
  @override List<Color> get bannerGradient => const [Color(0xFF1A5D92), Color(0xFF0F3A5C)];
  @override Brightness get brightness => Brightness.dark;
}

// ── Type ────────────────────────────────────────────────────────────────────

/// Fonts and the type scale. Colours come from the palette, so one
/// typography works with any palette.
abstract interface class UiTypography {
  double get step_1; // small labels, meta
  double get step0; // body
  double get step1; // card titles
  double get step2; // section titles
  double get step3; // page titles
  TextStyle display(double size, {required Color color, FontWeight weight});
  TextStyle body({required double size, required Color color, FontWeight weight, double height});
}

/// Bricolage Grotesque for headings, Figtree for text; .78 / .9 / 1.05 /
/// 1.3 / 1.75 rem at a 16 px root, as in the drafts.
final class DraftTypography implements UiTypography {
  const DraftTypography();
  @override double get step_1 => 12.5;
  @override double get step0 => 14.4;
  @override double get step1 => 16.8;
  @override double get step2 => 20.8;
  @override double get step3 => 28.0;

  @override
  TextStyle display(double size, {required Color color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.bricolageGrotesque(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.01 * size, height: 1.15);

  @override
  TextStyle body({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) =>
      GoogleFonts.figtree(fontSize: size, fontWeight: weight, color: color, height: height);
}

// ── Shape ───────────────────────────────────────────────────────────────────

class UiShape {
  final double radius; // panels, cards, tables
  final double radiusSm; // buttons, inputs, icon tiles
  const UiShape({this.radius = 14, this.radiusSm = 10});
}

// ── Tokens ──────────────────────────────────────────────────────────────────

/// Palette + typography + shape, published through the Material theme.
/// Read them with `context.ui`; style text with `ui.body()`, `ui.display()`.
@immutable
class UiTokens extends ThemeExtension<UiTokens> {
  final UiPalette palette;
  final UiTypography typography;
  final UiShape shape;

  const UiTokens({required this.palette, required this.typography, this.shape = const UiShape()});

  static const light = UiTokens(palette: DraftLightPalette(), typography: DraftTypography());
  static const dark = UiTokens(palette: DraftDarkPalette(), typography: DraftTypography());

  /// The tokens in force here: the nearest [UiScope] or theme, else light.
  static UiTokens of(BuildContext context) => Theme.of(context).extension<UiTokens>() ?? light;

  // Colour shortcuts, so components write `ui.surface` instead of
  // `ui.palette.surface`.
  Color get bg => palette.bg;
  Color get surface => palette.surface;
  Color get surface2 => palette.surface2;
  Color get surface3 => palette.surface3;
  Color get line => palette.line;
  Color get ink => palette.ink;
  Color get muted => palette.muted;
  Color get brand => palette.brand;
  Color get brandFill => palette.brandFill;
  Color get onBrand => palette.onBrand;
  Color get brandSoft => palette.brandSoft;
  Color get steel => palette.steel;
  Color get accent => palette.accent;
  Color get onAccent => palette.onAccent;
  Color get good => palette.good;
  Color get goodSoft => palette.goodSoft;
  Color get warn => palette.warn;
  Color get warnSoft => palette.warnSoft;
  Color get bad => palette.bad;
  Color get badSoft => palette.badSoft;

  /// The reminder banner background.
  LinearGradient get banner =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette.bannerGradient);

  // Type shortcuts with the palette's colours as defaults.
  TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      typography.display(size, color: color ?? ink, weight: weight);

  TextStyle body({double? size, Color? color, FontWeight weight = FontWeight.w400, double height = 1.5}) =>
      typography.body(size: size ?? typography.step0, color: color ?? ink, weight: weight, height: height);

  TextStyle get meta => body(size: typography.step_1, color: muted);

  TextStyle get eyebrow =>
      body(size: typography.step_1, color: muted, weight: FontWeight.w600).copyWith(letterSpacing: 0.08 * typography.step_1);

  @override
  UiTokens copyWith({UiPalette? palette, UiTypography? typography, UiShape? shape}) => UiTokens(
      palette: palette ?? this.palette, typography: typography ?? this.typography, shape: shape ?? this.shape);

  /// Tokens are swapped, not blended.
  @override
  UiTokens lerp(covariant UiTokens? other, double t) => t < 0.5 || other == null ? this : other;
}

extension UiContext on BuildContext {
  /// The design tokens in force at this point of the tree.
  UiTokens get ui => UiTokens.of(this);
}

/// Restyles everything inside it — e.g. a promotional panel on a different
/// palette, or a dark section — by publishing other tokens to that subtree.
/// Material widgets inside follow too, because the theme is rebuilt from
/// the tokens.
class UiScope extends StatelessWidget {
  final UiTokens tokens;
  final Widget child;
  const UiScope({super.key, required this.tokens, required this.child});

  @override
  Widget build(BuildContext context) => Theme(data: Ui.theme(tokens), child: child);
}

// ── Static access ───────────────────────────────────────────────────────────

/// The default (light) tokens as constants, for `const` widgets and for
/// screens written before the tokens moved onto the widget tree. New code
/// reads `context.ui` so it follows [UiScope] and future dark mode.
class Ui {
  Ui._();

  static const _p = DraftLightPalette();
  static const _t = DraftTypography();

  static const bg = Color(0xFFEEF2F6);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFE6ECF2);
  static const surface3 = Color(0xFFDBE3EB);
  static const line = Color(0xFFD3DCE5);
  static const ink = Color(0xFF0B2239);
  static const muted = Color(0xFF566A7E);
  static const brand = Color(0xFF013A63);
  static const brandFill = Color(0xFF013A63);
  static const onBrand = Color(0xFFFFFFFF);
  static const brandSoft = Color(0xFFDDE9F3);
  static const steel = Color(0xFF457B9D);
  static const accent = Color(0xFFFFB703);
  static const onAccent = Color(0xFF1C1400);
  static const good = Color(0xFF1F8A70);
  static const goodSoft = Color(0xFFDCF2EA);
  static const warn = Color(0xFFC77700);
  static const warnSoft = Color(0xFFFDF0D5);
  static const bad = Color(0xFFD62839);
  static const badSoft = Color(0xFFFBE1E4);

  static const radius = 14.0;
  static const radiusSm = 10.0;
  static const step_1 = 12.5;
  static const step0 = 14.4;
  static const step1 = 16.8;
  static const step2 = 20.8;
  static const step3 = 28.0;
  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle display(double size, {Color color = ink, FontWeight weight = FontWeight.w700}) =>
      _t.display(size, color: color, weight: weight);

  static TextStyle body({double size = step0, Color color = ink, FontWeight weight = FontWeight.w400, double height = 1.5}) =>
      _t.body(size: size, color: color, weight: weight, height: height);

  static TextStyle get meta => UiTokens.light.meta;
  static TextStyle get eyebrow => UiTokens.light.eyebrow;

  /// Material theme built from [tokens]: Figtree everywhere, palette colours,
  /// and every stock Material control (buttons, inputs, dialogs, tabs…) drawn
  /// like the drafts, so screens made of plain Material widgets match too.
  /// The tokens ride along as a ThemeExtension for `context.ui`.
  static ThemeData theme([UiTokens tokens = UiTokens.light]) {
    final p = tokens.palette;
    final ui = tokens;
    final radius = BorderRadius.circular(tokens.shape.radiusSm);
    final panelRadius = Radius.circular(tokens.shape.radius);
    final buttonText = ui.body(weight: FontWeight.w600, height: 1.3);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c));

    final base = ThemeData(
      brightness: p.brightness,
      extensions: [tokens],
      // outline / outlineVariant colour Material's dividers and table rows.
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.brandFill,
        onPrimary: p.onBrand,
        secondary: p.accent,
        onSecondary: p.onAccent,
        surface: p.surface,
        onSurface: p.ink,
        error: p.bad,
        onError: p.onBrand,
        outline: p.line,
        outlineVariant: p.line,
      ),
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.surface,
      dividerColor: p.line,
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: ui.display(tokens.typography.step2),
        iconTheme: IconThemeData(color: p.brand),
        actionsIconTheme: IconThemeData(color: p.brand),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brandFill,
          foregroundColor: p.onBrand,
          disabledBackgroundColor: p.surface3,
          disabledForegroundColor: p.muted,
          elevation: 0,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.brand,
          side: BorderSide(color: p.line),
          padding: buttonPadding,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.brand, textStyle: buttonText),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brandFill,
          foregroundColor: p.onBrand,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintStyle: ui.body(color: p.muted),
        labelStyle: ui.body(color: p.muted),
        border: border(p.line),
        enabledBorder: border(p.line),
        focusedBorder: border(p.brandFill),
        errorBorder: border(p.bad),
        focusedErrorBorder: border(p.bad),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(panelRadius)),
        titleTextStyle: ui.display(tokens.typography.step2),
        contentTextStyle: ui.body(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: panelRadius)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.muted,
        indicatorColor: p.brandFill,
        dividerColor: p.line,
        labelStyle: ui.body(weight: FontWeight.w700),
        unselectedLabelStyle: ui.body(weight: FontWeight.w500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: ui.body(color: p.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        selectedColor: p.brandFill,
        labelStyle: ui.body(size: tokens.typography.step_1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brandFill, linearTrackColor: p.surface2),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.brandFill : null),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.brandFill : p.surface3),
        thumbColor: WidgetStatePropertyAll(p.surface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: ui.body(),
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: p.line)),
      ),
      listTileTheme: ListTileThemeData(titleTextStyle: ui.body(weight: FontWeight.w600), subtitleTextStyle: ui.meta),
      iconTheme: IconThemeData(color: p.brand),
    );
    return base.copyWith(
      textTheme: GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: p.ink, displayColor: p.ink),
    );
  }

  /// Keeps the constants above honest: they must equal the light palette.
  static bool matchesLightPalette() =>
      bg == _p.bg && surface == _p.surface && surface2 == _p.surface2 && surface3 == _p.surface3 &&
      line == _p.line && ink == _p.ink && muted == _p.muted && brand == _p.brand &&
      brandFill == _p.brandFill && onBrand == _p.onBrand && brandSoft == _p.brandSoft &&
      steel == _p.steel && accent == _p.accent && onAccent == _p.onAccent && good == _p.good &&
      goodSoft == _p.goodSoft && warn == _p.warn && warnSoft == _p.warnSoft && bad == _p.bad &&
      badSoft == _p.badSoft;
}
