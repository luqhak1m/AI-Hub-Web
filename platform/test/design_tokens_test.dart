import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A one-off palette, as a special case would define it: only what differs
/// from the light palette.
final class _PromoPalette implements UiPalette {
  const _PromoPalette();
  static const _base = DraftLightPalette();
  @override Color get bg => _base.bg;
  @override Color get surface => const Color(0xFFFFF7E0);
  @override Color get surface2 => _base.surface2;
  @override Color get surface3 => _base.surface3;
  @override Color get line => const Color(0xFFFFB703);
  @override Color get ink => _base.ink;
  @override Color get muted => _base.muted;
  @override Color get brand => _base.brand;
  @override Color get brandFill => const Color(0xFF8D5524);
  @override Color get onBrand => _base.onBrand;
  @override Color get brandSoft => _base.brandSoft;
  @override Color get steel => _base.steel;
  @override Color get accent => _base.accent;
  @override Color get onAccent => _base.onAccent;
  @override Color get good => _base.good;
  @override Color get goodSoft => _base.goodSoft;
  @override Color get warn => _base.warn;
  @override Color get warnSoft => _base.warnSoft;
  @override Color get bad => _base.bad;
  @override Color get badSoft => _base.badSoft;
  @override List<Color> get bannerGradient => _base.bannerGradient;
  @override Brightness get brightness => Brightness.light;
}

Color? _fillOf(WidgetTester tester, Finder within) {
  final box = tester.widget<Container>(find.descendant(of: within, matching: find.byType(Container)).first);
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  test('static constants match the light palette they stand in for', () {
    expect(Ui.matchesLightPalette(), isTrue);
  });

  test('both draft palettes implement every role', () {
    for (final UiPalette p in const [DraftLightPalette(), DraftDarkPalette()]) {
      expect(p.bannerGradient, hasLength(2));
      expect(p.bg, isNot(p.ink));
    }
    expect(const DraftDarkPalette().brightness, Brightness.dark);
  });

  test('tones resolve through the palette, so a new palette recolours them', () {
    expect(PillStyle.of(Tone.good, UiTokens.light).foreground, const DraftLightPalette().good);
    expect(PillStyle.of(Tone.good, UiTokens.dark).foreground, const DraftDarkPalette().good);
    expect(UiButtonStyle.of(ButtonKind.primary, UiTokens.dark).background, const DraftDarkPalette().brandFill);
  });

  testWidgets('components without a theme fall back to the light tokens', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Panel(child: Text('x')))));
    expect(_fillOf(tester, find.byType(Panel)), const DraftLightPalette().surface);
  });

  testWidgets('UiScope restyles every component inside it, and only inside it', (tester) async {
    const promo = UiTokens(palette: _PromoPalette(), typography: DraftTypography());
    await tester.pumpWidget(MaterialApp(
      theme: Ui.theme(),
      home: const Scaffold(
        body: Column(children: [
          Panel(key: Key('outside'), child: Text('normal')),
          UiScope(tokens: promo, child: Panel(key: Key('inside'), child: Text('promo'))),
        ]),
      ),
    ));
    expect(_fillOf(tester, find.byKey(const Key('outside'))), const DraftLightPalette().surface);
    expect(_fillOf(tester, find.byKey(const Key('inside'))), const Color(0xFFFFF7E0));
  });

  testWidgets('a special-case style overrides the kind for one widget', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: Ui.theme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            UiButton('Save', key: const Key('primary'), onPressed: () {}),
            UiButton('Delete', key: const Key('danger'), style: UiButtonStyle.danger(context.ui), onPressed: () {}),
            const Pill('Beta', key: Key('custom'),
                style: PillStyle(background: Color(0xFF000000), foreground: Color(0xFFFFFFFF))),
          ]),
        ),
      ),
    ));
    expect(_fillOf(tester, find.byKey(const Key('primary'))), const DraftLightPalette().brandFill);
    expect(_fillOf(tester, find.byKey(const Key('danger'))), const DraftLightPalette().bad);
    expect(_fillOf(tester, find.byKey(const Key('custom'))), const Color(0xFF000000));
  });

  testWidgets('the Material theme is built from the tokens', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(
      theme: Ui.theme(UiTokens.dark),
      home: Builder(builder: (context) {
        theme = Theme.of(context);
        return const SizedBox();
      }),
    ));
    expect(theme.scaffoldBackgroundColor, const DraftDarkPalette().bg);
    expect(theme.colorScheme.primary, const DraftDarkPalette().brandFill);
    expect(theme.extension<UiTokens>(), same(UiTokens.dark));
  });
}
