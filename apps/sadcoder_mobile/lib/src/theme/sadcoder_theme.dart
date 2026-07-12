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
          ? const Color(0xFFFFA0F8)
          : const Color(0xFF7A1F72),
      onPrimary: brightness == Brightness.dark
          ? const Color(0xFF4B0050)
          : const Color(0xFFFFFFFF),
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF6A1565)
          : const Color(0xFFFFA0F8),
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFFFD7FB)
          : const Color(0xFF2F0030),
      secondary: brightness == Brightness.dark
          ? const Color(0xFFB5EEF1)
          : const Color(0xFF00696D),
      secondaryContainer: brightness == Brightness.dark
          ? const Color(0xFF17494D)
          : const Color(0xFFB5EEF1),
      onSecondaryContainer: brightness == Brightness.dark
          ? const Color(0xFFD4FCFF)
          : const Color(0xFF002022),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFA5F1A5)
          : const Color(0xFF336B35),
      tertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFF255226)
          : const Color(0xFFA5F1A5),
      onTertiaryContainer: brightness == Brightness.dark
          ? const Color(0xFFD4FFD4)
          : const Color(0xFF062207),
      surface: brightness == Brightness.dark
          ? const Color(0xFF151118)
          : const Color(0xFFFFFBFE),
      surfaceContainerLow: brightness == Brightness.dark
          ? const Color(0xFF1F1722)
          : const Color(0xFFFFF6FE),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF342638)
          : const Color(0xFFF3DDF9),
      outlineVariant: brightness == Brightness.dark
          ? const Color(0xFF6B546F)
          : const Color(0xFFE4B8F5),
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
        codeBackground: const Color(0xFFFFFAFE),
        codeForeground: const Color(0xFF24151F),
        codeKeyword: const Color(0xFF7A1F72),
        codeString: const Color(0xFF6C6200),
        codeComment: const Color(0xFF7B6A78),
        diffHeaderBackground: const Color(0xFFF3DDF9),
        diffHeaderForeground: const Color(0xFF35153B),
        terminalAccent: const Color(0xFFB5EEF1),
      ),
      (AppColorPalette.candy, Brightness.dark) => base.copyWith(
        codeBackground: const Color(0xFF1F1722),
        codeForeground: const Color(0xFFFFF0FE),
        codeKeyword: const Color(0xFFFFA0F8),
        codeString: const Color(0xFFF5F4A6),
        codeComment: const Color(0xFFC4AEC1),
        diffHeaderBackground: const Color(0xFF342638),
        diffHeaderForeground: const Color(0xFFFFD7FB),
        terminalAccent: const Color(0xFFB5EEF1),
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
