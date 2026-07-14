import 'package:flutter/material.dart';

import '../../experimental_features/experimental_feature_runner.dart';
import '../../i18n/app_localizations.dart';

class ChatExperimentalFeatureSheet extends StatefulWidget {
  const ChatExperimentalFeatureSheet({
    super.key,
    required this.runner,
    required this.features,
    this.threadId,
    this.expectedVersion,
  });

  final ExperimentalFeatureRunner runner;
  final List<ExperimentalFeature> features;
  final String? threadId;
  final String? expectedVersion;

  @override
  State<ChatExperimentalFeatureSheet> createState() =>
      _ChatExperimentalFeatureSheetState();
}

class _ChatExperimentalFeatureSheetState
    extends State<ChatExperimentalFeatureSheet> {
  late List<ExperimentalFeature> _features;
  String? _savingFeature;
  String? _error;
  var _changeCount = 0;
  String? _expectedVersion;

  @override
  void initState() {
    super.initState();
    _features = widget.features;
    _expectedVersion = widget.expectedVersion;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectable =
        _features
            .where((feature) => feature.isUserSelectable)
            .toList(growable: false)
          ..sort((left, right) => left.label.compareTo(right.label));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.experimentalTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('experimental-feature-close'),
                    onPressed: () => Navigator.of(context).pop(_changeCount),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: selectable.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.experimentalFeatureNoSelectable,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: selectable.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final feature = selectable[index];
                        final saving = _savingFeature == feature.name;
                        return SwitchListTile(
                          key: ValueKey('experimental-feature-${feature.name}'),
                          value: feature.enabled,
                          onChanged: _savingFeature == null
                              ? (enabled) => _setEnabled(feature, enabled)
                              : null,
                          secondary: saving
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Icon(Icons.science_outlined),
                          title: Text(feature.label),
                          subtitle: _ExperimentalFeatureSubtitle(
                            feature: feature,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(ExperimentalFeature feature, bool enabled) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.experimentalFeatureConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.experimentalFeatureConfirmBody(
                feature.label,
                feature.enabled
                    ? context.l10n.appEnabled
                    : context.l10n.appDisabled,
                enabled ? context.l10n.appEnabled : context.l10n.appDisabled,
              ),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.experimentalFeatureWriteImpact),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('experimental-feature-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.experimentalFeatureApply),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _savingFeature = feature.name;
      _error = null;
    });
    try {
      final result = await widget.runner.setFeatureEnabled(
        featureName: feature.name,
        enabled: enabled,
        expectedVersion: _expectedVersion,
      );
      final refreshed = await widget.runner.listFeatures(
        threadId: widget.threadId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _features = refreshed;
        _expectedVersion = result.version ?? _expectedVersion;
        _changeCount++;
      });
      final message = result.wasOverridden
          ? l10n.experimentalFeatureOverridden(result.overriddenMessage!)
          : l10n.experimentalFeatureUpdated(feature.label);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = l10n.messageWithDetail(
          l10n.experimentalFeatureWriteFailed,
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _savingFeature = null);
      }
    }
  }
}

class _ExperimentalFeatureSubtitle extends StatelessWidget {
  const _ExperimentalFeatureSubtitle({required this.feature});

  final ExperimentalFeature feature;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = [
      feature.name,
      feature.defaultEnabled
          ? l10n.experimentalFeatureDefaultEnabled
          : l10n.experimentalFeatureDefaultDisabled,
    ].join(' | ');
    final description = feature.description;
    final announcement = feature.announcement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null) Text(description),
        Text(metadata),
        if (announcement != null && announcement != description)
          Text(announcement),
      ],
    );
  }
}
