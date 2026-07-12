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
          ? const Color(0xFFF4BCC7)
          : const Color(0xFF7A2D43),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF481421)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF653044)
          : const Color(0xFFF4BCC7),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFE2E9)
          : const Color(0xFF351018),
      secondary: brightness == Brightness.dark
          ? const Color(0xFF9EDEF2)
          : const Color(0xFF00677B),
      onSecondary: brightness == Brightness.dark
          ? const Color(0xFF003541)
          : const Color(0xFFFFFFFF),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF164C5C)
          : const Color(0xFF9EDEF2),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFD7F6FF)
          : const Color(0xFF001F27),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFC6F2AF)
          : const Color(0xFF3D6B25),
      onTertiary: brightness == Brightness.dark
          ? const Color(0xFF1B3A10)
          : const Color(0xFFFFFFFF),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF31551E)
          : const Color(0xFFC6F2AF),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFE6FFD7)
          : const Color(0xFF102800),
      surface: brightness == Brightness.dark
          ? const Color(0xFF161115)
          : const Color(0xFFFFFBFF),
      surfaceContainerLowest: brightness == Brightness.dark
          ? const Color(0xFF100C10)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF211920)
          : const Color(0xFFFFF7F9),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF281F28)
          : const Color(0xFFFFF0F4),
      surfaceContainerHigh: brightness == Brightness.dark
          ? const Color(0xFF302530)
          : const Color(0xFFF9E8F0),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF3B2D3C)
          : const Color(0xFFF1E3F9),
      outline: brightness == Brightness.dark
          ? const Color(0xFFBFAFC1)
          : const Color(0xFF857184),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF6B5A6C)
          : const Color(0xFFD5CAF9),
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
        codeKeyword: const Color(0xFF7A2D43),
        codeString: const Color(0xFF6A5A00),
        codeComment: const Color(0xFF7D6B74),
        diffHeaderBackground: const Color(0xFFF1E3F9),
        diffHeaderForeground: const Color(0xFF33203D),
        terminalAccent: const Color(0xFF9EDEF2),
      ),
      (AppColorPalette.candy, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF211920),
        codeForeground: const Color(0xFFFFF3F8),
        codeKeyword: const Color(0xFFF4BCC7),
        codeString: const Color(0xFFF2E1B1),
        codeComment: const Color(0xFFCBB8C2),
        diffHeaderBackground: const Color(0xFF3B2D3C),
        diffHeaderForeground: const Color(0xFFEBDDFF),
        terminalAccent: const Color(0xFF9EDEF2),
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
