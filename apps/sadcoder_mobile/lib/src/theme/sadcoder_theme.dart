import 'package:flutter/material.dart';

import '../appearance/app_appearance_controller.dart';

ThemeData sadCoderThemeData({
  required AppColorPalette colorPalette,
  required Brightness brightness,
  AppFontSizePreference fontSize = AppFontSizePreference.medium,
}) {
  final baseTextTheme = _sadCoderBaseTextTheme();
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: sadCoderColorScheme(
      colorPalette: colorPalette,
      brightness: brightness,
    ),
    textTheme: baseTextTheme,
    primaryTextTheme: baseTextTheme,
    extensions: [
      SadCoderThemeColors.forPalette(
        colorPalette: colorPalette,
        brightness: brightness,
      ),
    ],
  );
  return _applyFontSize(theme, fontSize);
}

TextTheme _sadCoderBaseTextTheme() {
  const zeroTracking = 0.0;
  return const TextTheme(
    displayLarge: TextStyle(fontSize: 57, letterSpacing: zeroTracking),
    displayMedium: TextStyle(fontSize: 45, letterSpacing: zeroTracking),
    displaySmall: TextStyle(fontSize: 36, letterSpacing: zeroTracking),
    headlineLarge: TextStyle(fontSize: 32, letterSpacing: zeroTracking),
    headlineMedium: TextStyle(fontSize: 28, letterSpacing: zeroTracking),
    headlineSmall: TextStyle(fontSize: 24, letterSpacing: zeroTracking),
    titleLarge: TextStyle(fontSize: 22, letterSpacing: zeroTracking),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: zeroTracking,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: zeroTracking,
    ),
    bodyLarge: TextStyle(fontSize: 16, letterSpacing: zeroTracking),
    bodyMedium: TextStyle(fontSize: 14, letterSpacing: zeroTracking),
    bodySmall: TextStyle(fontSize: 12, letterSpacing: zeroTracking),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: zeroTracking,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: zeroTracking,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: zeroTracking,
    ),
  );
}

ColorScheme sadCoderColorScheme({
  required AppColorPalette colorPalette,
  required Brightness brightness,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: colorPalette.seedColor,
    brightness: brightness,
  );
  return switch (colorPalette) {
    AppColorPalette.sadcoder => base,
    AppColorPalette.candy => base.copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFFFFB3E6)
          : const Color(0xFFA01870),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF57003C)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF7D115C)
          : const Color(0xFFFFD1F3),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFEAF8)
          : const Color(0xFF3A002B),
      secondary: brightness == Brightness.dark
          ? const Color(0xFFB8F2E6)
          : const Color(0xFF0F766E),
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF003B35)
          : const Color(0xFFFFFFFF),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF07564E)
          : const Color(0xFFB8F2E6),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFE1FFF9)
          : const Color(0xFF002F2A),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFA0C4FF)
          : const Color(0xFF2E61B8),
      onTertiary: brightness == Brightness.dark
          ? const Color(0xFF002F69)
          : const Color(0xFFFFFFFF),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF17498F)
          : const Color(0xFFA0C4FF),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFEAF2FF)
          : const Color(0xFF001E45),
      surface: brightness == Brightness.dark
          ? const Color(0xFF17111A)
          : const Color(0xFFFFFBFE),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF0F0A12)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF221824)
          : const Color(0xFFFFF5FC),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF2D2032)
          : const Color(0xFFF2FFFC),
      surfaceContainerHigh: brightness == Brightness.dark
          ? const Color(0xFF392841)
          : const Color(0xFFFFF1B6),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF46304F)
          : const Color(0xFFEAF2FF),
      outline: brightness == Brightness.dark
          ? const Color(0xFFD4B8CE)
          : const Color(0xFF806A7A),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF735D72)
          : const Color(0xFFEACFE3),
    ),
    AppColorPalette.pastelCandy => base.copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFFF4BCC7)
          : const Color(0xFF944253),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF57212D)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF743342)
          : const Color(0xFFF4BCC7),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFE8ED)
          : const Color(0xFF3B0C16),
      secondary: brightness == Brightness.dark
          ? const Color(0xFF9EDEF2)
          : const Color(0xFF006D83),
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF003743)
          : const Color(0xFFFFFFFF),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF005365)
          : const Color(0xFF9EDEF2),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFDDF8FF)
          : const Color(0xFF001F28),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFC6F2AF)
          : const Color(0xFF4F7F35),
      onTertiary: brightness == Brightness.dark
          ? const Color(0xFF223E16)
          : const Color(0xFFFFFFFF),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF3C6329)
          : const Color(0xFFC6F2AF),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFE9FFDE)
          : const Color(0xFF17330C),
      surface: brightness == Brightness.dark
          ? const Color(0xFF181113)
          : const Color(0xFFFFFBFF),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF100B0D)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF23191D)
          : const Color(0xFFFFF5F7),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF2E2228)
          : const Color(0xFFF6FCFF),
      surfaceContainerHigh: brightness == Brightness.dark
          ? const Color(0xFF3A2A31)
          : const Color(0xFFFFF8E3),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF46333D)
          : const Color(0xFFF1EBFF),
      outline: brightness == Brightness.dark
          ? const Color(0xFFD8BBC5)
          : const Color(0xFF806B72),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF765E68)
          : const Color(0xFFE6CDD4),
    ),
    AppColorPalette.candyTones => base.copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFFFFB6D5)
          : const Color(0xFF9E2B66),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF5A0037)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF7C1E50)
          : const Color(0xFFF694C1),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFEDF5)
          : const Color(0xFF3C0023),
      secondary: brightness == Brightness.dark
          ? const Color(0xFFD3F8E2)
          : const Color(0xFF176C47),
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF003822)
          : const Color(0xFFFFFFFF),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF0D5234)
          : const Color(0xFFD3F8E2),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFE9FFF2)
          : const Color(0xFF00331E),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFA9DEF9)
          : const Color(0xFF0B6785),
      onTertiary: brightness == Brightness.dark
          ? const Color(0xFF003447)
          : const Color(0xFFFFFFFF),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF004E66)
          : const Color(0xFFA9DEF9),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFE7F8FF)
          : const Color(0xFF002838),
      surface: brightness == Brightness.dark
          ? const Color(0xFF181115)
          : const Color(0xFFFFFBFF),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF100B0E)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF23191F)
          : const Color(0xFFFFF3FA),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF2E222A)
          : const Color(0xFFF5FFF8),
      surfaceContainerHigh: brightness == Brightness.dark
          ? const Color(0xFF392A33)
          : const Color(0xFFFFFBE6),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF45333F)
          : const Color(0xFFF4E6FF),
      outline: brightness == Brightness.dark
          ? const Color(0xFFD8BBC7)
          : const Color(0xFF7D6871),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF745E68)
          : const Color(0xFFE7CDD8),
    ),
    AppColorPalette.candyPop => base.copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFFD8B6FF)
          : const Color(0xFF6B22B8),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF3A006F)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF5E1C9C)
          : const Color(0xFFE9D8FF),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFF5EBFF)
          : const Color(0xFF25004E),
      secondary: brightness == Brightness.dark
          ? const Color(0xFFFFB0DE)
          : const Color(0xFFA51678),
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF5E003D)
          : const Color(0xFFFFFFFF),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF7C0054)
          : const Color(0xFFFFD7EF),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFECF7)
          : const Color(0xFF430029),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFF72E8FF)
          : const Color(0xFF006A83),
      onTertiary: brightness == Brightness.dark
          ? const Color(0xFF003642)
          : const Color(0xFFFFFFFF),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF005365)
          : const Color(0xFFB6F1FF),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFDDF9FF)
          : const Color(0xFF001F28),
      surface: brightness == Brightness.dark
          ? const Color(0xFF17111C)
          : const Color(0xFFFFFBFF),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF0F0A13)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF211828)
          : const Color(0xFFFFF3FB),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF2B2034)
          : const Color(0xFFF1FBFF),
      surfaceContainerHigh: brightness == Brightness.dark
          ? const Color(0xFF362840)
          : const Color(0xFFFFF9DD),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF43304F)
          : const Color(0xFFEADFFF),
      outline: brightness == Brightness.dark
          ? const Color(0xFFD3B8D9)
          : const Color(0xFF7D6B83),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF725E78)
          : const Color(0xFFE0D2EA),
    ),
    AppColorPalette.lagoon => base.copyWith(
      secondary: brightness == Brightness.dark
          ? const Color(0xFF2DD4BF)
          : const Color(0xFF00796B),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFF86EFAC)
          : const Color(0xFF237A3B),
    ),
    AppColorPalette.ember => base.copyWith(
      secondary: brightness == Brightness.dark
          ? const Color(0xFFFFC971)
          : const Color(0xFF8B5A00),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFC4B5FD)
          : const Color(0xFF5B35B1),
    ),
  };
}

class SadCoderThemeColors extends ThemeExtension<SadCoderThemeColors> {
  const SadCoderThemeColors({
    required this.codeBackground,
    required this.codeForeground,
    required this.codeKeyword,
    required this.codeString,
    required this.codeComment,
    required this.diffAddedBackground,
    required this.diffAddedForeground,
    required this.diffRemovedBackground,
    required this.diffRemovedForeground,
    required this.diffHeaderBackground,
    required this.diffHeaderForeground,
    required this.terminalBackground,
    required this.terminalForeground,
    required this.terminalMuted,
    required this.terminalAccent,
  });

  final Color codeBackground;
  final Color codeForeground;
  final Color codeKeyword;
  final Color codeString;
  final Color codeComment;
  final Color diffAddedBackground;
  final Color diffAddedForeground;
  final Color diffRemovedBackground;
  final Color diffRemovedForeground;
  final Color diffHeaderBackground;
  final Color diffHeaderForeground;
  final Color terminalBackground;
  final Color terminalForeground;
  final Color terminalMuted;
  final Color terminalAccent;

  static const light = SadCoderThemeColors(
    codeBackground: Color(0xFFF3F7F5),
    codeForeground: Color(0xFF10201D),
    codeKeyword: Color(0xFF006A60),
    codeString: Color(0xFF8B3F11),
    codeComment: Color(0xFF5F6F6B),
    diffAddedBackground: Color(0xFFE6F4EA),
    diffAddedForeground: Color(0xFF0F5132),
    diffRemovedBackground: Color(0xFFFCE8E6),
    diffRemovedForeground: Color(0xFF842029),
    diffHeaderBackground: Color(0xFFE8EEF1),
    diffHeaderForeground: Color(0xFF24343A),
    terminalBackground: Color(0xFF101418),
    terminalForeground: Color(0xFFE7F2EF),
    terminalMuted: Color(0xFFA8B8B3),
    terminalAccent: Color(0xFF80CBC4),
  );

  static const dark = SadCoderThemeColors(
    codeBackground: Color(0xFF111917),
    codeForeground: Color(0xFFE7F2EF),
    codeKeyword: Color(0xFF80CBC4),
    codeString: Color(0xFFFFB86B),
    codeComment: Color(0xFF8AA39D),
    diffAddedBackground: Color(0xFF123524),
    diffAddedForeground: Color(0xFF9BE7B0),
    diffRemovedBackground: Color(0xFF3B171A),
    diffRemovedForeground: Color(0xFFFFB3B8),
    diffHeaderBackground: Color(0xFF182229),
    diffHeaderForeground: Color(0xFFC8D6DB),
    terminalBackground: Color(0xFF090D10),
    terminalForeground: Color(0xFFE7F2EF),
    terminalMuted: Color(0xFF8DA19B),
    terminalAccent: Color(0xFF5EEAD4),
  );

  static SadCoderThemeColors forPalette({
    required AppColorPalette colorPalette,
    required Brightness brightness,
  }) {
    final base = brightness == Brightness.dark ? dark : light;
    return switch ((colorPalette, brightness)) {
      (AppColorPalette.sadcoder, _) => base,
      (AppColorPalette.candy, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFFFFBFF),
        codeForeground: const Color(0xFF24151F),
        codeKeyword: const Color(0xFFA01870),
        codeString: const Color(0xFF0F766E),
        codeComment: const Color(0xFF66708C),
        diffHeaderBackground: const Color(0xFFFFD1F3),
        diffHeaderForeground: const Color(0xFF3A002B),
        terminalAccent: const Color(0xFFB8F2E6),
      ),
      (AppColorPalette.candy, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF211725),
        codeForeground: const Color(0xFFFFF3F8),
        codeKeyword: const Color(0xFFFFB3E6),
        codeString: const Color(0xFFB8F2E6),
        codeComment: const Color(0xFFC8B7C7),
        diffHeaderBackground: const Color(0xFF46304F),
        diffHeaderForeground: const Color(0xFFFFEAF8),
        terminalAccent: const Color(0xFFB8F2E6),
      ),
      (AppColorPalette.pastelCandy, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFFFFBFF),
        codeForeground: const Color(0xFF24171A),
        codeKeyword: const Color(0xFF944253),
        codeString: const Color(0xFF006D83),
        codeComment: const Color(0xFF6D6872),
        diffHeaderBackground: const Color(0xFFF4BCC7),
        diffHeaderForeground: const Color(0xFF3B0C16),
        terminalAccent: const Color(0xFF9EDEF2),
      ),
      (AppColorPalette.pastelCandy, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF21171B),
        codeForeground: const Color(0xFFFFEFF2),
        codeKeyword: const Color(0xFFF4BCC7),
        codeString: const Color(0xFF9EDEF2),
        codeComment: const Color(0xFFCABBC2),
        diffHeaderBackground: const Color(0xFF46333D),
        diffHeaderForeground: const Color(0xFFFFE8ED),
        terminalAccent: const Color(0xFF9EDEF2),
      ),
      (AppColorPalette.candyTones, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFFFFBFF),
        codeForeground: const Color(0xFF23161C),
        codeKeyword: const Color(0xFF9E2B66),
        codeString: const Color(0xFF176C47),
        codeComment: const Color(0xFF6B6670),
        diffHeaderBackground: const Color(0xFFE4C1F9),
        diffHeaderForeground: const Color(0xFF35104C),
        terminalAccent: const Color(0xFFA9DEF9),
      ),
      (AppColorPalette.candyTones, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF21171D),
        codeForeground: const Color(0xFFFFEFF6),
        codeKeyword: const Color(0xFFFFB6D5),
        codeString: const Color(0xFFD3F8E2),
        codeComment: const Color(0xFFCABBC3),
        diffHeaderBackground: const Color(0xFF45333F),
        diffHeaderForeground: const Color(0xFFFFEDF5),
        terminalAccent: const Color(0xFFA9DEF9),
      ),
      (AppColorPalette.candyPop, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFFFFBFF),
        codeForeground: const Color(0xFF211527),
        codeKeyword: const Color(0xFF7B2CBF),
        codeString: const Color(0xFF007A6F),
        codeComment: const Color(0xFF6F6674),
        diffHeaderBackground: const Color(0xFFE9D8FF),
        diffHeaderForeground: const Color(0xFF2A1040),
        terminalAccent: const Color(0xFF00BBF9),
      ),
      (AppColorPalette.candyPop, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF21172A),
        codeForeground: const Color(0xFFF7ECFF),
        codeKeyword: const Color(0xFFD8B6FF),
        codeString: const Color(0xFF00F5D4),
        codeComment: const Color(0xFFC7BBC9),
        diffHeaderBackground: const Color(0xFF432552),
        diffHeaderForeground: const Color(0xFFF6E5FF),
        terminalAccent: const Color(0xFF00F5D4),
      ),
      (AppColorPalette.lagoon, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFF1F7FF),
        codeForeground: const Color(0xFF111F33),
        codeKeyword: const Color(0xFF1D4ED8),
        codeString: const Color(0xFF047857),
        codeComment: const Color(0xFF586A7B),
        diffHeaderBackground: const Color(0xFFE6F4FF),
        diffHeaderForeground: const Color(0xFF16324F),
        terminalAccent: const Color(0xFF38BDF8),
      ),
      (AppColorPalette.lagoon, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF0C1420),
        codeForeground: const Color(0xFFE6F2FF),
        codeKeyword: const Color(0xFF93C5FD),
        codeString: const Color(0xFF5EEAD4),
        codeComment: const Color(0xFF9CB4C7),
        diffHeaderBackground: const Color(0xFF101C2B),
        diffHeaderForeground: const Color(0xFFCFE8FF),
        terminalAccent: const Color(0xFF22D3EE),
      ),
      (AppColorPalette.ember, Brightness.light) => base.copyWith(
        codeBackground: const Color(0xFFFFF7ED),
        codeForeground: const Color(0xFF2A1B12),
        codeKeyword: const Color(0xFF7C3AED),
        codeString: const Color(0xFFB45309),
        codeComment: const Color(0xFF756557),
        diffHeaderBackground: const Color(0xFFFFEEDB),
        diffHeaderForeground: const Color(0xFF432511),
        terminalAccent: const Color(0xFFF59E0B),
      ),
      (AppColorPalette.ember, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF1B120C),
        codeForeground: const Color(0xFFFFF1E5),
        codeKeyword: const Color(0xFFC4B5FD),
        codeString: const Color(0xFFFFC971),
        codeComment: const Color(0xFFB7A493),
        diffHeaderBackground: const Color(0xFF28180D),
        diffHeaderForeground: const Color(0xFFFFDDBC),
        terminalAccent: const Color(0xFFF59E0B),
      ),
    };
  }

  static SadCoderThemeColors of(BuildContext context) {
    return Theme.of(context).extension<SadCoderThemeColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  SadCoderThemeColors copyWith({
    Color? codeBackground,
    Color? codeForeground,
    Color? codeKeyword,
    Color? codeString,
    Color? codeComment,
    Color? diffAddedBackground,
    Color? diffAddedForeground,
    Color? diffRemovedBackground,
    Color? diffRemovedForeground,
    Color? diffHeaderBackground,
    Color? diffHeaderForeground,
    Color? terminalBackground,
    Color? terminalForeground,
    Color? terminalMuted,
    Color? terminalAccent,
  }) {
    return SadCoderThemeColors(
      codeBackground: codeBackground ?? this.codeBackground,
      codeForeground: codeForeground ?? this.codeForeground,
      codeKeyword: codeKeyword ?? this.codeKeyword,
      codeString: codeString ?? this.codeString,
      codeComment: codeComment ?? this.codeComment,
      diffAddedBackground: diffAddedBackground ?? this.diffAddedBackground,
      diffAddedForeground: diffAddedForeground ?? this.diffAddedForeground,
      diffRemovedBackground:
          diffRemovedBackground ?? this.diffRemovedBackground,
      diffRemovedForeground:
          diffRemovedForeground ?? this.diffRemovedForeground,
      diffHeaderBackground: diffHeaderBackground ?? this.diffHeaderBackground,
      diffHeaderForeground: diffHeaderForeground ?? this.diffHeaderForeground,
      terminalBackground: terminalBackground ?? this.terminalBackground,
      terminalForeground: terminalForeground ?? this.terminalForeground,
      terminalMuted: terminalMuted ?? this.terminalMuted,
      terminalAccent: terminalAccent ?? this.terminalAccent,
    );
  }

  @override
  SadCoderThemeColors lerp(
    ThemeExtension<SadCoderThemeColors>? other,
    double t,
  ) {
    if (other is! SadCoderThemeColors) {
      return this;
    }
    return SadCoderThemeColors(
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      codeForeground: Color.lerp(codeForeground, other.codeForeground, t)!,
      codeKeyword: Color.lerp(codeKeyword, other.codeKeyword, t)!,
      codeString: Color.lerp(codeString, other.codeString, t)!,
      codeComment: Color.lerp(codeComment, other.codeComment, t)!,
      diffAddedBackground: Color.lerp(
        diffAddedBackground,
        other.diffAddedBackground,
        t,
      )!,
      diffAddedForeground: Color.lerp(
        diffAddedForeground,
        other.diffAddedForeground,
        t,
      )!,
      diffRemovedBackground: Color.lerp(
        diffRemovedBackground,
        other.diffRemovedBackground,
        t,
      )!,
      diffRemovedForeground: Color.lerp(
        diffRemovedForeground,
        other.diffRemovedForeground,
        t,
      )!,
      diffHeaderBackground: Color.lerp(
        diffHeaderBackground,
        other.diffHeaderBackground,
        t,
      )!,
      diffHeaderForeground: Color.lerp(
        diffHeaderForeground,
        other.diffHeaderForeground,
        t,
      )!,
      terminalBackground: Color.lerp(
        terminalBackground,
        other.terminalBackground,
        t,
      )!,
      terminalForeground: Color.lerp(
        terminalForeground,
        other.terminalForeground,
        t,
      )!,
      terminalMuted: Color.lerp(terminalMuted, other.terminalMuted, t)!,
      terminalAccent: Color.lerp(terminalAccent, other.terminalAccent, t)!,
    );
  }
}

ThemeData _applyFontSize(ThemeData theme, AppFontSizePreference fontSize) {
  if (fontSize == AppFontSizePreference.medium) {
    return theme;
  }
  final scale = fontSize.scale;
  return theme.copyWith(
    textTheme: _scaleTextTheme(theme.textTheme, scale),
    primaryTextTheme: _scaleTextTheme(theme.primaryTextTheme, scale),
  );
}

TextTheme _scaleTextTheme(TextTheme theme, double scale) {
  return theme.copyWith(
    displayLarge: _scaleTextStyle(theme.displayLarge, scale),
    displayMedium: _scaleTextStyle(theme.displayMedium, scale),
    displaySmall: _scaleTextStyle(theme.displaySmall, scale),
    headlineLarge: _scaleTextStyle(theme.headlineLarge, scale),
    headlineMedium: _scaleTextStyle(theme.headlineMedium, scale),
    headlineSmall: _scaleTextStyle(theme.headlineSmall, scale),
    titleLarge: _scaleTextStyle(theme.titleLarge, scale),
    titleMedium: _scaleTextStyle(theme.titleMedium, scale),
    titleSmall: _scaleTextStyle(theme.titleSmall, scale),
    bodyLarge: _scaleTextStyle(theme.bodyLarge, scale),
    bodyMedium: _scaleTextStyle(theme.bodyMedium, scale),
    bodySmall: _scaleTextStyle(theme.bodySmall, scale),
    labelLarge: _scaleTextStyle(theme.labelLarge, scale),
    labelMedium: _scaleTextStyle(theme.labelMedium, scale),
    labelSmall: _scaleTextStyle(theme.labelSmall, scale),
  );
}

TextStyle? _scaleTextStyle(TextStyle? style, double scale) {
  final fontSize = style?.fontSize;
  if (style == null || fontSize == null) {
    return style;
  }
  return style.copyWith(fontSize: fontSize * scale);
}
