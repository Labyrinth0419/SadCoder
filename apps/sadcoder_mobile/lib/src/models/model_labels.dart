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
