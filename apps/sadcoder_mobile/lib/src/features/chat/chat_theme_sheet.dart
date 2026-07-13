import 'package:flutter/material.dart';

import '../../appearance/app_appearance_controller.dart';
import '../../i18n/app_localizations.dart';
import '../appearance/app_color_palette_picker.dart';

class ChatThemeSheet extends StatefulWidget {
  const ChatThemeSheet({
    super.key,
    required this.initialTheme,
    required this.initialColorPalette,
  });

  final AppThemePreference initialTheme;
  final AppColorPalette initialColorPalette;

  @override
  State<ChatThemeSheet> createState() => _ChatThemeSheetState();
}

class _ChatThemeSheetState extends State<ChatThemeSheet> {
  late AppThemePreference _theme;
  late AppColorPalette _colorPalette;

  @override
  void initState() {
    super.initState();
    _theme = widget.initialTheme;
    _colorPalette = widget.initialColorPalette;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.themeCommandTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<AppThemePreference>(
                segments: [
                  ButtonSegment(
                    value: AppThemePreference.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: {_theme},
                onSelectionChanged: (selection) {
                  setState(() => _theme = selection.single);
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.colorPalette,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.colorPaletteBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              AppColorPalettePicker(
                keyPrefix: 'chat-color-palette',
                selectedPalette: _colorPalette,
                onSelected: (palette) {
                  setState(() => _colorPalette = palette);
                },
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.approvalCancel),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('chat-theme-command-apply'),
                    onPressed: () => Navigator.of(context).pop(
                      ChatThemeSheetResult(
                        theme: _theme,
                        colorPalette: _colorPalette,
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.applyTheme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatThemeSheetResult {
  const ChatThemeSheetResult({required this.theme, required this.colorPalette});

  final AppThemePreference theme;
  final AppColorPalette colorPalette;
}
