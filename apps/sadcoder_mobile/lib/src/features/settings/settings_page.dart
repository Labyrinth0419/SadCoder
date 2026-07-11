import 'package:flutter/material.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../appearance/app_appearance_controller.dart';
import '../../background/background_connection_policy.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../config/codex_config_snapshot.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../diagnostics/diagnostic_log_export_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../models/model_labels.dart';
import '../../models/model_list_controller.dart';
import '../../security/permission_risk.dart';
import '../appearance/app_color_palette_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.appearanceController,
    this.configOverrideController,
    this.configSnapshotController,
    this.accountSnapshotController,
    this.modelListController,
    this.backgroundConnectionPreferences,
    this.diagnosticLogExportController,
  });

  final AppAppearanceController? appearanceController;
  final CodexConfigOverrideController? configOverrideController;
  final CodexConfigSnapshotController? configSnapshotController;
  final AccountSnapshotController? accountSnapshotController;
  final ModelListController? modelListController;
  final BackgroundConnectionPreferences? backgroundConnectionPreferences;
  final DiagnosticLogExportController? diagnosticLogExportController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  _SettingsSection? _selectedSection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useWideLayout = constraints.maxWidth >= 720;
        if (useWideLayout) {
          final selectedSection =
              _selectedSection ?? _SettingsSection.permissions;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 240,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l10n.settings,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    _SettingsSectionMenu(
                      selectedSection: selectedSection,
                      onSelected: _selectSection,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _sectionContent(context, selectedSection),
                ),
              ),
            ],
          );
        }
        final selectedSection = _selectedSection;
        if (selectedSection != null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsDetailHeader(
                section: selectedSection,
                onBack: _showSectionMenu,
              ),
              const SizedBox(height: 12),
              ..._sectionContent(context, selectedSection),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.settings,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _SettingsSectionMenu(
              selectedSection: null,
              onSelected: _selectSection,
            ),
          ],
        );
      },
    );
  }

  void _selectSection(_SettingsSection section) {
    if (_selectedSection == section) {
      return;
    }
    setState(() => _selectedSection = section);
  }

  void _showSectionMenu() {
    setState(() => _selectedSection = null);
  }

  List<Widget> _sectionContent(BuildContext context, _SettingsSection section) {
    final l10n = context.l10n;
    return switch (section) {
      _SettingsSection.permissions => [
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.serverDefaults),
            subtitle: Text(l10n.serverDefaultsBody),
          ),
        ),
        if (widget.configSnapshotController != null)
          _ServerConfigSnapshotCard(
            controller: widget.configSnapshotController!,
          ),
        if (widget.configOverrideController != null)
          _AppDefaultOverridesCard(
            controller: widget.configOverrideController!,
          ),
      ],
      _SettingsSection.account => [
        if (widget.accountSnapshotController == null)
          _SettingsUnavailableCard(
            icon: Icons.account_circle_outlined,
            title: l10n.settingsSectionAccount,
          )
        else
          _AccountStatusSettingsCard(
            controller: widget.accountSnapshotController!,
          ),
      ],
      _SettingsSection.models => [
        if (widget.modelListController == null)
          _SettingsUnavailableCard(
            icon: Icons.memory_outlined,
            title: l10n.settingsSectionModels,
          )
        else
          _ModelListSettingsCard(controller: widget.modelListController!),
      ],
      _SettingsSection.appearance => [
        if (widget.appearanceController == null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(l10n.theme),
              subtitle: Text(l10n.themeBody),
            ),
          )
        else
          _AppearanceSettingsCard(controller: widget.appearanceController!),
      ],
      _SettingsSection.ssh => [
        if (widget.backgroundConnectionPreferences == null)
          _SettingsUnavailableCard(
            icon: Icons.settings_ethernet_outlined,
            title: l10n.settingsSectionSsh,
          )
        else
          _BackgroundConnectionSettingsCard(
            preferences: widget.backgroundConnectionPreferences!,
          ),
      ],
      _SettingsSection.diagnostics => [
        if (widget.diagnosticLogExportController == null)
          _SettingsUnavailableCard(
            icon: Icons.article_outlined,
            title: l10n.settingsSectionDiagnostics,
          )
        else
          _DiagnosticLogExportCard(
            controller: widget.diagnosticLogExportController!,
          ),
      ],
    };
  }
}

enum _SettingsSection {
  permissions,
  account,
  models,
  appearance,
  ssh,
  diagnostics,
}

String _labelForSection(BuildContext context, _SettingsSection section) {
  final l10n = context.l10n;
  return switch (section) {
    _SettingsSection.permissions => l10n.settingsSectionPermissions,
    _SettingsSection.account => l10n.settingsSectionAccount,
    _SettingsSection.models => l10n.settingsSectionModels,
    _SettingsSection.appearance => l10n.settingsSectionAppearance,
    _SettingsSection.ssh => l10n.settingsSectionSsh,
    _SettingsSection.diagnostics => l10n.settingsSectionDiagnostics,
  };
}

IconData _iconForSection(_SettingsSection section) {
  return switch (section) {
    _SettingsSection.permissions => Icons.admin_panel_settings_outlined,
    _SettingsSection.account => Icons.account_circle_outlined,
    _SettingsSection.models => Icons.memory_outlined,
    _SettingsSection.appearance => Icons.palette_outlined,
    _SettingsSection.ssh => Icons.settings_ethernet_outlined,
    _SettingsSection.diagnostics => Icons.article_outlined,
  };
}

class _SettingsSectionMenu extends StatelessWidget {
  const _SettingsSectionMenu({
    required this.selectedSection,
    required this.onSelected,
  });

  final _SettingsSection? selectedSection;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final section in _SettingsSection.values)
            _SettingsSectionTile(
              tileKey: ValueKey('settings-section-${section.name}'),
              icon: _iconForSection(section),
              label: _labelForSection(context, section),
              selected: selectedSection == section,
              onTap: () => onSelected(section),
            ),
        ],
      ),
    );
  }
}

class _SettingsSectionTile extends StatelessWidget {
  const _SettingsSectionTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SettingsDetailHeader extends StatelessWidget {
  const _SettingsDetailHeader({required this.section, required this.onBack});

  final _SettingsSection section;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('settings-section-back'),
          onPressed: onBack,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Icon(_iconForSection(section)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _labelForSection(context, section),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

class _SettingsUnavailableCard extends StatelessWidget {
  const _SettingsUnavailableCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(context.l10n.settingsSectionUnavailable),
      ),
    );
  }
}

class _AccountStatusSettingsCard extends StatelessWidget {
  const _AccountStatusSettingsCard({required this.controller});

  final AccountSnapshotController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _AccountStatusSettingsContent(controller: controller),
    );
  }
}

class _AccountStatusSettingsContent extends StatelessWidget {
  const _AccountStatusSettingsContent({required this.controller});

  final AccountSnapshotController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.accountStatus,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('settings-account-refresh'),
                  onPressed: controller.status == AccountSnapshotStatus.loading
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshAccountStatus,
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (controller.status) {
              AccountSnapshotStatus.idle => Text(l10n.accountStatusUnavailable),
              AccountSnapshotStatus.loading => const LinearProgressIndicator(),
              AccountSnapshotStatus.failed => Text(
                controller.error?.toString() ?? l10n.accountLoadFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              AccountSnapshotStatus.loaded when controller.snapshot == null =>
                Text(l10n.accountStatusUnavailable),
              AccountSnapshotStatus.loaded => _LoadedAccountStatus(
                controller: controller,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _LoadedAccountStatus extends StatelessWidget {
  const _LoadedAccountStatus({required this.controller});

  final AccountSnapshotController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = controller.snapshot!;
    final account = snapshot.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account == null)
          Text(l10n.accountNotSignedIn)
        else ...[
          _SettingsValueLine(label: l10n.accountSignedIn, value: account.label),
          if (account.credentialSource != null)
            _SettingsValueLine(
              label: l10n.accountCredentialSource,
              value: account.credentialSource!,
            ),
        ],
        const SizedBox(height: 4),
        Text(
          snapshot.requiresOpenaiAuth
              ? l10n.openaiAuthRequired
              : l10n.openaiAuthNotRequired,
        ),
      ],
    );
  }
}

class _ModelListSettingsCard extends StatelessWidget {
  const _ModelListSettingsCard({required this.controller});

  final ModelListController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _ModelListSettingsContent(controller: controller),
    );
  }
}

class _ModelListSettingsContent extends StatelessWidget {
  const _ModelListSettingsContent({required this.controller});

  final ModelListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.memory_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.modelList,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('settings-model-list-refresh'),
                  onPressed: controller.status == ModelListStatus.loading
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshModelList,
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (controller.status) {
              ModelListStatus.idle => Text(l10n.modelListUnavailable),
              ModelListStatus.loading => const LinearProgressIndicator(),
              ModelListStatus.failed => Text(
                controller.error?.toString() ?? l10n.modelListLoadFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              ModelListStatus.loaded when controller.models.isEmpty => Text(
                l10n.modelListEmpty,
              ),
              ModelListStatus.loaded => _LoadedModelList(
                controller: controller,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _LoadedModelList extends StatelessWidget {
  const _LoadedModelList({required this.controller});

  final ModelListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final models = controller.models;
    final visibleModels = models.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.availableModels(models.length)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final model in visibleModels)
              Chip(label: Text(codexModelDisplayLabel(context, model))),
          ],
        ),
        if (models.length > visibleModels.length) ...[
          const SizedBox(height: 8),
          Text(l10n.modelListMore(models.length - visibleModels.length)),
        ],
      ],
    );
  }
}

class _DiagnosticLogExportCard extends StatefulWidget {
  const _DiagnosticLogExportCard({required this.controller});

  final DiagnosticLogExportController controller;

  @override
  State<_DiagnosticLogExportCard> createState() =>
      _DiagnosticLogExportCardState();
}

class _DiagnosticLogExportCardState extends State<_DiagnosticLogExportCard> {
  bool _copying = false;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.diagnosticLogs,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(l10n.diagnosticLogsBody),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  key: const ValueKey('settings-copy-diagnostic-logs'),
                  onPressed: _copying ? null : _copyLogs,
                  icon: _copying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy),
                  label: Text(
                    _copying
                        ? l10n.copyingDiagnosticLogs
                        : l10n.copyDiagnosticLogs,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('settings-export-diagnostic-logs'),
                  onPressed: _exporting ? null : _exportLogs,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_outlined),
                  label: Text(
                    _exporting
                        ? l10n.exportingDiagnosticLogs
                        : l10n.exportDiagnosticLogs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLogs() async {
    final l10n = context.l10n;
    if (widget.controller.entryCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.diagnosticLogsEmpty)));
      return;
    }

    final confirmed = await _confirmDiagnosticLogExport(
      title: l10n.diagnosticLogsConfirmTitle,
      actionLabel: l10n.copyDiagnosticLogs,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _copying = true);
    try {
      final result = await widget.controller.copyLogs();
      if (!mounted) {
        return;
      }
      final message = result.copied
          ? l10n.diagnosticLogsCopied(result.entryCount)
          : l10n.diagnosticLogsEmpty;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _copying = false);
      }
    }
  }

  Future<void> _exportLogs() async {
    final l10n = context.l10n;
    if (widget.controller.entryCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.diagnosticLogsEmpty)));
      return;
    }

    final confirmed = await _confirmDiagnosticLogExport(
      title: l10n.diagnosticLogsExportConfirmTitle,
      actionLabel: l10n.exportDiagnosticLogs,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _exporting = true);
    try {
      final result = await widget.controller.exportLogs(
        dialogTitle: l10n.exportDiagnosticLogs,
      );
      if (!mounted || !result.exported) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.diagnosticLogsExported(result.entryCount))),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.diagnosticLogsExportFailed}: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<bool?> _confirmDiagnosticLogExport({
    required String title,
    required String actionLabel,
  }) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(l10n.diagnosticLogsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _BackgroundConnectionSettingsCard extends StatelessWidget {
  const _BackgroundConnectionSettingsCard({required this.preferences});

  final BackgroundConnectionPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => Card(
        child: SwitchListTile(
          key: const ValueKey('settings-background-active-turn-keepalive'),
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(context.l10n.backgroundConnectionKeepActiveTurn),
          subtitle: Text(context.l10n.backgroundConnectionKeepActiveTurnBody),
          value: preferences.keepConnectionDuringActiveTurn,
          onChanged: preferences.setKeepConnectionDuringActiveTurn,
        ),
      ),
    );
  }
}

class _AppearanceSettingsCard extends StatelessWidget {
  const _AppearanceSettingsCard({required this.controller});

  final AppAppearanceController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _AppearanceSettingsContent(controller: controller),
    );
  }
}

class _AppearanceSettingsContent extends StatelessWidget {
  const _AppearanceSettingsContent({required this.controller});

  final AppAppearanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.dark_mode_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.theme,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        l10n.themeBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<AppThemePreference>(
              key: const ValueKey('settings-theme-selector'),
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
              selected: {controller.theme},
              onSelectionChanged: (selection) {
                controller.setTheme(selection.single);
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
              keyPrefix: 'settings-color-palette',
              selectedPalette: controller.colorPalette,
              onSelected: controller.setColorPalette,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('settings-show-unavailable-slash-commands'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.showUnavailableSlashCommands),
              subtitle: Text(l10n.showUnavailableSlashCommandsBody),
              value: controller.showUnavailableSlashCommands,
              onChanged: controller.setShowUnavailableSlashCommands,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerConfigSnapshotCard extends StatelessWidget {
  const _ServerConfigSnapshotCard({required this.controller});

  final CodexConfigSnapshotController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _ServerConfigSnapshotContent(controller: controller),
    );
  }
}

class _ServerConfigSnapshotContent extends StatelessWidget {
  const _ServerConfigSnapshotContent({required this.controller});

  final CodexConfigSnapshotController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = controller.snapshot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.serverConfigSnapshot,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('settings-server-config-refresh'),
                  onPressed:
                      controller.status == CodexConfigSnapshotStatus.loading
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshServerConfig,
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (controller.status) {
              CodexConfigSnapshotStatus.idle => Text(
                l10n.serverConfigUnavailable,
              ),
              CodexConfigSnapshotStatus.loading =>
                const LinearProgressIndicator(),
              CodexConfigSnapshotStatus.failed => Text(
                controller.error?.toString() ?? l10n.serverConfigLoadFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              CodexConfigSnapshotStatus.loaded when snapshot == null => Text(
                l10n.serverConfigUnavailable,
              ),
              CodexConfigSnapshotStatus.loaded => _LoadedServerConfig(
                snapshot: snapshot!,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _LoadedServerConfig extends StatelessWidget {
  const _LoadedServerConfig({required this.snapshot});

  final CodexConfigSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.modelOverride,
          keyName: 'model',
        ),
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.modelProvider,
          keyName: 'model_provider',
        ),
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.effortOverride,
          keyName: 'model_reasoning_effort',
        ),
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.approvalPolicy,
          keyName: 'approval_policy',
        ),
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.permissionProfile,
          keyName: 'default_permissions',
        ),
        _ServerConfigField(
          snapshot: snapshot,
          label: l10n.sandboxMode,
          keyName: 'sandbox_mode',
        ),
        if (isHighRiskPermissionState(
          approvalPolicy: snapshot.valueFor('approval_policy'),
          sandboxPolicy: snapshot.valueFor('sandbox_mode'),
          permissionProfile: snapshot.valueFor('default_permissions'),
        )) ...[
          const SizedBox(height: 8),
          _ServerConfigRiskWarning(message: l10n.permissionsHighRiskWarning),
        ],
        if (snapshot.layers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.configLayersLoaded(snapshot.layers.length)),
        ],
      ],
    );
  }
}

class _ServerConfigField extends StatelessWidget {
  const _ServerConfigField({
    required this.snapshot,
    required this.label,
    required this.keyName,
  });

  final CodexConfigSnapshot snapshot;
  final String label;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = snapshot.displayValueFor(keyName) ?? l10n.serverValueUnset;
    final origin = snapshot.originLabelFor(keyName) ?? l10n.sourceServerDefault;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('$label: $value (${l10n.overrideSource}: $origin)'),
    );
  }
}

class _ServerConfigRiskWarning extends StatelessWidget {
  const _ServerConfigRiskWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDefaultOverridesCard extends StatefulWidget {
  const _AppDefaultOverridesCard({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<_AppDefaultOverridesCard> createState() =>
      _AppDefaultOverridesCardState();
}

class _AppDefaultOverridesCardState extends State<_AppDefaultOverridesCard> {
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;
  late final TextEditingController _cwdController;
  late final TextEditingController _personalityController;
  late final TextEditingController _serviceTierController;
  late final TextEditingController _approvalPolicyController;
  late final TextEditingController _permissionProfileController;

  @override
  void initState() {
    super.initState();
    final appDefault = widget.controller.layers.appDefault;
    _modelController = TextEditingController(text: appDefault.model ?? '');
    _effortController = TextEditingController(text: appDefault.effort ?? '');
    _cwdController = TextEditingController(text: appDefault.cwd ?? '');
    _personalityController = TextEditingController(
      text: appDefault.personality ?? '',
    );
    _serviceTierController = TextEditingController(
      text: appDefault.serviceTier ?? '',
    );
    _approvalPolicyController = TextEditingController(
      text: _stringOverrideValue(appDefault.approvalPolicy) ?? '',
    );
    _permissionProfileController = TextEditingController(
      text: appDefault.permissionProfile ?? '',
    );
  }

  @override
  void dispose() {
    _modelController.dispose();
    _effortController.dispose();
    _cwdController.dispose();
    _personalityController.dispose();
    _serviceTierController.dispose();
    _approvalPolicyController.dispose();
    _permissionProfileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule_folder_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.appDefaultOverrides,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.modelOverride,
                  source: widget.controller.sourceFor('model'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-model-override'),
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: l10n.modelOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.effortOverride,
                  source: widget.controller.sourceFor('effort'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-effort-override'),
                  controller: _effortController,
                  decoration: InputDecoration(
                    labelText: l10n.effortOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.cwdOverride,
                  source: widget.controller.sourceFor('cwd'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-cwd-override'),
                  controller: _cwdController,
                  decoration: InputDecoration(
                    labelText: l10n.cwdOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.personalityOverride,
                  source: widget.controller.sourceFor('personality'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-personality-override'),
                  controller: _personalityController,
                  decoration: InputDecoration(
                    labelText: l10n.personalityOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.serviceTierOverride,
                  source: widget.controller.sourceFor('serviceTier'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-service-tier-override'),
                  controller: _serviceTierController,
                  decoration: InputDecoration(
                    labelText: l10n.serviceTierOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.approvalPolicy,
                  source: widget.controller.sourceFor('approvalPolicy'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-approval-policy-override'),
                  controller: _approvalPolicyController,
                  decoration: InputDecoration(
                    labelText: l10n.approvalPolicy,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.permissionProfile,
                  source: widget.controller.sourceFor('permissionProfile'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-permission-profile-override'),
                  controller: _permissionProfileController,
                  decoration: InputDecoration(
                    labelText: l10n.permissionProfile,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.clearOverrides),
                    ),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.applyOverrides),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _apply() {
    widget.controller.setAppDefault(
      CodexConfigOverrides(
        model: _modelController.text,
        effort: _effortController.text,
        cwd: _cwdController.text,
        personality: _personalityController.text,
        serviceTier: _serviceTierController.text,
        approvalPolicy: _stringOverrideValue(_approvalPolicyController.text),
        permissionProfile: _permissionProfileController.text,
      ),
    );
  }

  void _clear() {
    _modelController.clear();
    _effortController.clear();
    _cwdController.clear();
    _personalityController.clear();
    _serviceTierController.clear();
    _approvalPolicyController.clear();
    _permissionProfileController.clear();
    widget.controller.setAppDefault(CodexConfigOverrides.empty);
  }
}

String? _stringOverrideValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.label, required this.source});

  final String label;
  final CodexConfigOverrideSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(
      '$label - ${l10n.overrideSource}: ${_sourceLabel(l10n, source)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  String _sourceLabel(AppLocalizations l10n, CodexConfigOverrideSource source) {
    return switch (source) {
      CodexConfigOverrideSource.serverDefault => l10n.sourceServerDefault,
      CodexConfigOverrideSource.appDefault => l10n.sourceAppDefault,
      CodexConfigOverrideSource.session => l10n.sourceSessionOverride,
      CodexConfigOverrideSource.turn => l10n.sourceTurnOverride,
    };
  }
}

class _SettingsValueLine extends StatelessWidget {
  const _SettingsValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text('$label: $value'),
    );
  }
}
