import 'package:flutter/material.dart';

/// Веб-нұсқадағы CSS айнымалылары (--bg, --sf, …)
class Pal extends ThemeExtension<Pal> {
  final Color bg, sf, sf2, ink, mute, line, lime, limeInk, hero, heroInk, heroMute, heroLine, pos, neg, warn, dock, dockInk;
  final bool dark;
  const Pal({
    required this.bg, required this.sf, required this.sf2, required this.ink, required this.mute, required this.line,
    required this.lime, required this.limeInk, required this.hero, required this.heroInk, required this.heroMute, required this.heroLine,
    required this.pos, required this.neg, required this.warn, required this.dock, required this.dockInk, required this.dark,
  });

  static const light = Pal(
    bg: Color(0xFFEFECE4), sf: Color(0xFFFAF8F3), sf2: Color(0xFFE5E1D6), ink: Color(0xFF141412), mute: Color(0xFF6F6C64), line: Color(0xFFDCD7CB),
    lime: Color(0xFFD2F45C), limeInk: Color(0xFF141412),
    hero: Color(0xFF141412), heroInk: Color(0xFFF4F1E8), heroMute: Color(0xFF9C998F), heroLine: Color(0xFF2B2B27),
    pos: Color(0xFF138A5B), neg: Color(0xFFD2452D), warn: Color(0xFFC98A0B), dock: Color(0xFF141412), dockInk: Color(0xFFF4F1E8), dark: false,
  );

  static const darkPal = Pal(
    bg: Color(0xFF0C0C0B), sf: Color(0xFF171715), sf2: Color(0xFF22221F), ink: Color(0xFFF1EEE6), mute: Color(0xFF8F8C84), line: Color(0xFF2A2A26),
    lime: Color(0xFFD2F45C), limeInk: Color(0xFF141412),
    hero: Color(0xFFD2F45C), heroInk: Color(0xFF141412), heroMute: Color(0xFF4E5A22), heroLine: Color(0x24141412),
    pos: Color(0xFF4FD08F), neg: Color(0xFFFF6B52), warn: Color(0xFFF2B53A), dock: Color(0xFF1D1D1A), dockInk: Color(0xFFF1EEE6), dark: true,
  );

  @override
  Pal copyWith() => this;

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) => (other is Pal && t > .5) ? other : this;
}

extension PalX on BuildContext {
  Pal get pal => Theme.of(this).extension<Pal>() ?? Pal.light;
}

ThemeData buildTheme(Pal p) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Onest',
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.lime,
      brightness: p.dark ? Brightness.dark : Brightness.light,
      surface: p.sf,
      primary: p.ink,
      onPrimary: p.bg,
    ),
    splashFactory: InkSparkle.splashFactory,
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: 'Onest'),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.sf, showDragHandle: true, dragHandleColor: p.line),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dark ? p.sf2 : p.ink,
      contentTextStyle: TextStyle(color: p.dark ? p.ink : p.bg, fontFamily: 'Onest', fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.sf2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.mute),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.sf, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
  );
}

const kNum = [FontFeature.tabularFigures()];
