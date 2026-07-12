import 'dart:convert';

import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';

String buildDebugConfigSummary({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
}) {
  final lines = <String>[l10n.debugConfigTitle];
  if (controller == null) {
    lines.add(l10n.debugConfigUnavailable);
    return lines.join('\n');
  }
  if (controller.status == CodexConfigSnapshotStatus.failed) {
    final error = controller.error;
    lines.add(
      '${l10n.debugConfigLoadFailed}${error == null ? '' : ': $error'}',
    );
    return lines.join('\n');
  }

  final snapshot = controller.snapshot;
  if (snapshot == null) {
    lines.add(l10n.debugConfigNoSnapshot);
    return lines.join('\n');
  }

  lines.add(l10n.debugConfigEffectiveValues);
  if (snapshot.config.isEmpty) {
    lines.add('  ${l10n.serverValueUnset}');
  } else {
    final keys = snapshot.config.keys.toList()..sort();
    for (final key in keys) {
      final value = snapshot.displayValueFor(key) ?? l10n.serverValueUnset;
      final origin = snapshot.originLabelFor(key) ?? l10n.sourceServerDefault;
      lines.add('  $key: $value (${l10n.overrideSource}: $origin)');
    }
  }

  if (snapshot.origins.isNotEmpty) {
    lines.add(l10n.debugConfigOrigins);
    final keys = snapshot.origins.keys.toList()..sort();
    for (final key in keys) {
      final origin = snapshot.origins[key]!;
      final version = origin.version;
      lines.add(
        '  $key: ${origin.displayLabel}${version == null ? '' : ' [$version]'}',
      );
    }
  }

  lines.add(l10n.debugConfigLayers(snapshot.layers.length));
  for (var i = 0; i < snapshot.layers.length; i++) {
    final layer = snapshot.layers[i];
    lines.add('  ${l10n.debugConfigLayer(i + 1)}: ${_layerLabel(l10n, layer)}');
    final config = _objectMap(layer['config']);
    if (config.isNotEmpty) {
      lines.add('    ${l10n.debugConfigLayerConfig}: ${jsonEncode(config)}');
    }
    final metadata = Map<String, Object?>.from(layer)..remove('config');
    if (metadata.isNotEmpty) {
      lines.add(
        '    ${l10n.debugConfigLayerMetadata}: ${jsonEncode(metadata)}',
      );
    }
  }

  return lines.join('\n');
}

String _layerLabel(AppLocalizations l10n, Map<String, Object?> layer) {
  final version = _stringValue(layer['version']);
  if (version != null) {
    return version;
  }
  final name = layer['name'];
  if (name is String && name.trim().isNotEmpty) {
    return name.trim();
  }
  if (name is Map) {
    final map = _objectMap(name);
    return jsonEncode(map);
  }
  return l10n.debugConfigLayerUnknown;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
