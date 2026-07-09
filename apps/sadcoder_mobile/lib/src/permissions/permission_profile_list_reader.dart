abstract interface class PermissionProfileListReader {
  Future<PermissionProfileListPage> listPermissionProfiles({String? cwd});
}

class PermissionProfileListPage {
  const PermissionProfileListPage({required this.profiles, this.nextCursor});

  factory PermissionProfileListPage.fromJson(Map<String, Object?> json) {
    final rawProfiles = json['data'] ?? json['profiles'];
    final profiles = rawProfiles is List
        ? List<PermissionProfileSummary>.unmodifiable(
            rawProfiles.map(_profileFromJson).nonNulls,
          )
        : const <PermissionProfileSummary>[];
    return PermissionProfileListPage(
      profiles: profiles,
      nextCursor: _stringValue(json['nextCursor']),
    );
  }

  final List<PermissionProfileSummary> profiles;
  final String? nextCursor;
}

class PermissionProfileSummary {
  const PermissionProfileSummary({
    required this.id,
    this.description,
    this.allowed = true,
  });

  final String id;
  final String? description;
  final bool allowed;

  String get label {
    if (_hasText(description)) {
      return '$id / ${description!.trim()}';
    }
    return id;
  }
}

PermissionProfileSummary? _profileFromJson(Object? value) {
  if (value is String) {
    final id = value.trim();
    if (id.isEmpty) {
      return null;
    }
    return PermissionProfileSummary(id: id);
  }
  if (value is Map) {
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    final id = _stringValue(map['id']);
    if (!_hasText(id)) {
      return null;
    }
    return PermissionProfileSummary(
      id: id!.trim(),
      description: _stringValue(map['description']),
      allowed: map['allowed'] is bool ? map['allowed']! as bool : true,
    );
  }
  return null;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
