bool isHighRiskPermissionState({
  Object? approvalPolicy,
  Object? sandboxPolicy,
  Object? permissionProfile,
}) {
  return _isNeverApproval(_configValueLabel(approvalPolicy)) ||
      _isDangerFullAccess(_configValueLabel(sandboxPolicy)) ||
      _isDangerFullAccess(_configValueLabel(permissionProfile));
}

bool isHighRiskPermissionValue({
  String? approvalPolicy,
  String? sandboxMode,
  String? permissionProfile,
}) {
  return _isNeverApproval(approvalPolicy) ||
      _isDangerFullAccess(sandboxMode) ||
      _isDangerFullAccess(permissionProfile);
}

String? _configValueLabel(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is Map) {
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    for (final key in const ['type', 'id', 'name', 'value']) {
      final raw = map[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw;
      }
    }
  }
  return null;
}

bool _isNeverApproval(String? value) => _riskKey(value) == 'never';

bool _isDangerFullAccess(String? value) {
  final key = _riskKey(value);
  return key == 'dangerfullaccess' || key.endsWith('dangerfullaccess');
}

String _riskKey(String? value) {
  if (value == null) {
    return '';
  }
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
