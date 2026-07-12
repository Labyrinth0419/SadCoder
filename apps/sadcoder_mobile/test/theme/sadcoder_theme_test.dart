import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  test(
    'semantic theme colors follow palettes without recoloring diff roles',
    () {
      final sadcoder = sadCoderThemeData(
        colorPalette: AppColorPalette.sadcoder,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;
      final candy = sadCoderThemeData(
        colorPalette: AppColorPalette.candy,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;
      final lagoon = sadCoderThemeData(
        colorPalette: AppColorPalette.lagoon,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;

      expect(candy.codeKeyword, isNot(sadcoder.codeKeyword));
      expect(candy.terminalAccent, isNot(sadcoder.terminalAccent));
      expect(lagoon.codeKeyword, isNot(candy.codeKeyword));
      expect(candy.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(candy.diffRemovedForeground, sadcoder.diffRemovedForeground);
      expect(lagoon.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(lagoon.diffRemovedForeground, sadcoder.diffRemovedForeground);
    },
  );

  test('candy color scheme uses bespoke candy tones', () {
    final scheme = sadCoderColorScheme(
      colorPalette: AppColorPalette.candy,
      brightness: Brightness.light,
    );
    final nativeSeed = ColorScheme.fromSeed(
      seedColor: AppColorPalette.candy.seedColor,
      brightness: Brightness.light,
    );

    expect(scheme.primary, const Color(0xFFB91854));
    expect(scheme.primaryContainer, const Color(0xFFFFC2D7));
    expect(scheme.secondaryContainer, const Color(0xFFCBEFF3));
    expect(scheme.tertiaryContainer, const Color(0xFFFFF9C9));
    expect(scheme.outlineVariant, const Color(0xFFE8D3EE));
    expect(scheme.primary, isNot(nativeSeed.primary));
  });

  test('dark palette semantic colors keep code roles distinct', () {
    final ember = SadCoderThemeColors.forPalette(
      colorPalette: AppColorPalette.ember,
      brightness: Brightness.dark,
    );

    expect(ember.codeKeyword, isNot(ember.codeString));
    expect(ember.codeKeyword, isNot(ember.codeComment));
    expect(ember.terminalAccent, isNot(ember.terminalMuted));
  });

  test('font size preference scales app text themes', () {
    final medium = sadCoderThemeData(
      colorPalette: AppColorPalette.sadcoder,
      brightness: Brightness.light,
    );
    final extraLarge = sadCoderThemeData(
      colorPalette: AppColorPalette.sadcoder,
      brightness: Brightness.light,
      fontSize: AppFontSizePreference.extraLarge,
    );

    expect(
      extraLarge.textTheme.bodyMedium!.fontSize,
      greaterThan(medium.textTheme.bodyMedium!.fontSize!),
    );
  });
}
