import 'package:flutter/material.dart';

const brandDark = Color(0xFF0B3C5D);
const brandMid = Color(0xFF1D6FA5);
const brandTeal = Color(0xFF14B8A6);

/// Colours for one verdict. Meaning is never carried by colour alone: every verdict also has an icon and words.
class VerdictPalette {
  final Color accent, background, text;
  final IconData icon;
  final int level; // 1 = no warning signs, 2 = suspicious, 3 = dangerous
  const VerdictPalette(this.accent, this.background, this.text, this.icon, this.level);
}

VerdictPalette paletteFor(String verdict, Brightness b) {
  final dark = b == Brightness.dark;
  switch (verdict) {
    case 'dangerous':
      return dark
          ? const VerdictPalette(Color(0xFFFFB4AB), Color(0xFF3B1512), Color(0xFFFFE3E0), Icons.gpp_bad_outlined, 3)
          : const VerdictPalette(Color(0xFFB3261E), Color(0xFFFDECEA), Color(0xFF3B0A07), Icons.gpp_bad_outlined, 3);
    case 'suspicious':
      return dark
          ? const VerdictPalette(Color(0xFFFFD27A), Color(0xFF3A2C0A), Color(0xFFFFEFCB), Icons.gpp_maybe_outlined, 2)
          : const VerdictPalette(Color(0xFF7A4F00), Color(0xFFFFF4DB), Color(0xFF2E1E00), Icons.gpp_maybe_outlined, 2);
    default:
      return dark
          ? const VerdictPalette(Color(0xFF9DDBAD), Color(0xFF12301E), Color(0xFFD7F2DF), Icons.verified_user_outlined, 1)
          : const VerdictPalette(Color(0xFF1B6E3C), Color(0xFFE6F4EA), Color(0xFF0B2A17), Icons.verified_user_outlined, 1);
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: brandMid, brightness: b);
  return ThemeData(
    useMaterial3: true,
    // bundled, so Hindi renders correctly on any phone and nothing is fetched from a font server
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoSansDevanagari'],
    colorScheme: scheme,
    scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0E1418) : const Color(0xFFF3F7FA),
    cardTheme: CardThemeData(
      elevation: 0,
      color: b == Brightness.dark ? const Color(0xFF172027) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        backgroundColor: b == Brightness.light ? brandMid : null,
        foregroundColor: b == Brightness.light ? Colors.white : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: b == Brightness.dark ? const Color(0xFF101A20) : Colors.white,
    ),
  );
}
