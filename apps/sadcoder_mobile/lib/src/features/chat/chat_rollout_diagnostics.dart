String? rolloutPathFromThreadRaw(Map<String, Object?> raw) {
  String? fromValue(Object? value) {
    if (value is String) {
      return _nonEmptyText(value);
    }
    if (value is Map) {
      return fromValue(value['path']);
    }
    return null;
  }

  for (final key in const [
    'rolloutPath',
    'rollout_path',
    'currentRolloutPath',
    'current_rollout_path',
    'rollout',
  ]) {
    final path = fromValue(raw[key]);
    if (path != null) {
      return path;
    }
  }
  return null;
}

String? _nonEmptyText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
