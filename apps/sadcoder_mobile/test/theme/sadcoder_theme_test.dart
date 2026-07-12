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
      final candyPop = sadCoderThemeData(
        colorPalette: AppColorPalette.candyPop,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;
      final candyTones = sadCoderThemeData(
        colorPalette: AppColorPalette.candyTones,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;
      final pastelCandy = sadCoderThemeData(
        colorPalette: AppColorPalette.pastelCandy,
        brightness: Brightness.light,
      ).extension<SadCoderThemeColors>()!;

      expect(candy.codeKeyword, isNot(sadcoder.codeKeyword));
      expect(candy.terminalAccent, isNot(sadcoder.terminalAccent));
      expect(lagoon.codeKeyword, isNot(candy.codeKeyword));
      expect(candyPop.codeKeyword, isNot(candy.codeKeyword));
      expect(candyPop.terminalAccent, isNot(candy.terminalAccent));
      expect(candyTones.codeKeyword, isNot(candy.codeKeyword));
      expect(candyTones.terminalAccent, isNot(candy.terminalAccent));
      expect(pastelCandy.codeKeyword, isNot(candy.codeKeyword));
      expect(pastelCandy.terminalAccent, isNot(candy.terminalAccent));
      expect(candy.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(candy.diffRemovedForeground, sadcoder.diffRemovedForeground);
      expect(candyPop.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(candyPop.diffRemovedForeground, sadcoder.diffRemovedForeground);
      expect(candyTones.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(candyTones.diffRemovedForeground, sadcoder.diffRemovedForeground);
      expect(pastelCandy.diffAddedForeground, sadcoder.diffAddedForeground);
      expect(pastelCandy.diffRemovedForeground, sadcoder.diffRemovedForeground);
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

    expect(scheme.primary, const Color(0xFFA01870));
    expect(scheme.primaryContainer, const Color(0xFFFFD1F3));
    expect(scheme.secondaryContainer, const Color(0xFFB8F2E6));
    expect(scheme.tertiaryContainer, const Color(0xFFA0C4FF));
    expect(scheme.outlineVariant, const Color(0xFFEACFE3));
    expect(scheme.primary, isNot(nativeSeed.primary));
  });

  test('pastel candy color scheme uses bespoke soft candy tones', () {
    final scheme = sadCoderColorScheme(
      colorPalette: AppColorPalette.pastelCandy,
      brightness: Brightness.light,
    );
    final nativeSeed = ColorScheme.fromSeed(
      seedColor: AppColorPalette.pastelCandy.seedColor,
      brightness: Brightness.light,
    );

    expect(scheme.primary, const Color(0xFF944253));
    expect(scheme.primaryContainer, const Color(0xFFF4BCC7));
    expect(scheme.secondaryContainer, const Color(0xFF9EDEF2));
    expect(scheme.tertiaryContainer, const Color(0xFFC6F2AF));
    expect(scheme.surfaceContainerHighest, const Color(0xFFF1EBFF));
    expect(scheme.primary, isNot(nativeSeed.primary));
  });

  test('candy pop color scheme uses bespoke high saturation tones', () {
    final scheme = sadCoderColorScheme(
      colorPalette: AppColorPalette.candyPop,
      brightness: Brightness.light,
    );
    final nativeSeed = ColorScheme.fromSeed(
      seedColor: AppColorPalette.candyPop.seedColor,
      brightness: Brightness.light,
    );

    expect(scheme.primary, const Color(0xFF6B22B8));
    expect(scheme.primaryContainer, const Color(0xFFE9D8FF));
    expect(scheme.secondaryContainer, const Color(0xFFFFD7EF));
    expect(scheme.tertiaryContainer, const Color(0xFFB6F1FF));
    expect(scheme.outlineVariant, const Color(0xFFE0D2EA));
    expect(scheme.primary, isNot(nativeSeed.primary));
  });

  test('candy tones color scheme uses bespoke soft multi-color tones', () {
    final scheme = sadCoderColorScheme(
      colorPalette: AppColorPalette.candyTones,
      brightness: Brightness.light,
    );
    final nativeSeed = ColorScheme.fromSeed(
      seedColor: AppColorPalette.candyTones.seedColor,
      brightness: Brightness.light,
    );

    expect(scheme.primary, const Color(0xFF9E2B66));
    expect(scheme.primaryContainer, const Color(0xFFF694C1));
    expect(scheme.secondaryContainer, const Color(0xFFD3F8E2));
    expect(scheme.tertiaryContainer, const Color(0xFFA9DEF9));
    expect(scheme.surfaceContainerHighest, const Color(0xFFF4E6FF));
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
