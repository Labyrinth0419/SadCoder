import 'package:flutter/widgets.dart';

import '../i18n/app_localizations.dart';
import 'model_list_reader.dart';

String codexModelDisplayLabel(BuildContext context, CodexModelSummary model) {
  final label = model.label;
  if (!model.isDefault) {
    return label;
  }
  return '$label (${context.l10n.modelDefaultBadge})';
}

String? codexModelCapabilitySummary(
  BuildContext context,
  CodexModelSummary model,
) {
  final l10n = context.l10n;
  final parts = <String>[];
  final reasoning = _modelReasoningSummary(l10n, model);
  if (reasoning != null) {
    parts.add(reasoning);
  }
  final serviceTiers = _modelServiceTierSummary(l10n, model);
  if (serviceTiers != null) {
    parts.add(serviceTiers);
  }
  final announcement = model.availabilityNux?.message.trim();
  if (announcement != null && announcement.isNotEmpty) {
    parts.add(l10n.modelAnnouncementSummary(announcement));
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

String? _modelReasoningSummary(AppLocalizations l10n, CodexModelSummary model) {
  final levels = model.supportedReasoningEfforts
      .map((effort) => effort.id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  final defaultReasoning = model.defaultReasoningEffort?.trim();
  if (defaultReasoning != null && defaultReasoning.isNotEmpty) {
    final summary = levels.isEmpty
        ? '${l10n.modelDefaultBadge}: $defaultReasoning'
        : '${levels.join(', ')} (${l10n.modelDefaultBadge}: $defaultReasoning)';
    return l10n.modelReasoningSummary(summary);
  }
  if (levels.isEmpty) {
    return null;
  }
  return l10n.modelReasoningSummary(levels.join(', '));
}

String? _modelServiceTierSummary(
  AppLocalizations l10n,
  CodexModelSummary model,
) {
  final tiers = model.serviceTiers
      .map((tier) {
        final name = tier.name?.trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
        return tier.id.trim();
      })
      .where((tier) => tier.isNotEmpty)
      .toList(growable: false);
  final defaultTier = model.defaultServiceTier?.trim();
  if (defaultTier != null && defaultTier.isNotEmpty) {
    final summary = tiers.isEmpty
        ? '${l10n.modelDefaultBadge}: $defaultTier'
        : '${tiers.join(', ')} (${l10n.modelDefaultBadge}: $defaultTier)';
    return l10n.modelServiceTierSummary(summary);
  }
  if (tiers.isEmpty) {
    return null;
  }
  return l10n.modelServiceTierSummary(tiers.join(', '));
}
