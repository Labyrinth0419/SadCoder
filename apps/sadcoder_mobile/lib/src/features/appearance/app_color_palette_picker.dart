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
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(128.0, 166.0).toDouble()
            : 166.0;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final palette in AppColorPalette.values)
              _PaletteOptionTile(
                key: ValueKey('$keyPrefix-${palette.commandValue}'),
                palette: palette,
                label: context.l10n.colorPaletteLabel(palette.commandValue),
                selected: palette == selectedPalette,
                selectedBorder: colorScheme.primary,
                width: tileWidth,
                onTap: () => onSelected(palette),
              ),
          ],
        );
      },
    );
  }
}

class _PaletteOptionTile extends StatelessWidget {
  const _PaletteOptionTile({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.selectedBorder,
    required this.width,
    required this.onTap,
  });

  final AppColorPalette palette;
  final String label;
  final bool selected;
  final Color selectedBorder;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.52)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? selectedBorder : colorScheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: selectedBorder.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                AppColorPaletteSwatch(
                  palette: palette,
                  width: 46,
                  height: 22,
                  radius: 6,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppColorPaletteSwatch extends StatelessWidget {
  const AppColorPaletteSwatch({
    super.key,
    required this.palette,
    this.width = 22,
    this.height = 22,
    this.radius = 11,
  });

  final AppColorPalette palette;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = palette.swatchColors;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
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
