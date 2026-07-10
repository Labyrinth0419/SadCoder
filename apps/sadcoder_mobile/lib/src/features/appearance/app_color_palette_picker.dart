import 'package:flutter/material.dart';

import '../../appearance/app_appearance_controller.dart';
import '../../i18n/app_localizations.dart';

class AppColorPalettePicker extends StatelessWidget {
  const AppColorPalettePicker({
    super.key,
    required this.selectedPalette,
    required this.onSelected,
    this.keyPrefix = 'app-color-palette',
  });

  final AppColorPalette selectedPalette;
  final ValueChanged<AppColorPalette> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final palette in AppColorPalette.values)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${palette.commandValue}'),
            selected: palette == selectedPalette,
            avatar: AppColorPaletteSwatch(palette: palette),
            label: Text(context.l10n.colorPaletteLabel(palette.commandValue)),
            onSelected: (selected) {
              if (selected) {
                onSelected(palette);
              }
            },
          ),
      ],
    );
  }
}

class AppColorPaletteSwatch extends StatelessWidget {
  const AppColorPaletteSwatch({super.key, required this.palette});

  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = palette.swatchColors;
    return Container(
      width: 22,
      height: 22,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          for (final color in colors) Expanded(child: ColoredBox(color: color)),
        ],
      ),
    );
  }
}
