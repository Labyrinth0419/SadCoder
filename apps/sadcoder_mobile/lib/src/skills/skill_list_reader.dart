abstract interface class SkillListReader {
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  });
}

class SkillListPage {
  const SkillListPage({required this.entries});

  factory SkillListPage.fromJson(Map<String, Object?> json) {
    final rawEntries = json['data'];
    return SkillListPage(
      entries: rawEntries is List
          ? List.unmodifiable(rawEntries.map(SkillListEntry.fromJson).nonNulls)
          : const [],
    );
  }

  final List<SkillListEntry> entries;
}

class SkillListEntry {
  const SkillListEntry({
    required this.cwd,
    required this.skills,
    required this.errors,
    required this.raw,
  });

  static SkillListEntry? fromJson(Object? value) {
    final map = _objectMap(value);
    final cwd = _stringValue(map['cwd']);
    if (cwd == null) {
      return null;
    }
    return SkillListEntry(
      cwd: cwd,
      skills: _skillList(map['skills']),
      errors: _errorList(map['errors']),
      raw: map,
    );
  }

  final String cwd;
  final List<SkillSummary> skills;
  final List<SkillLoadError> errors;
  final Map<String, Object?> raw;
}

class SkillSummary {
  const SkillSummary({
    required this.name,
    required this.description,
    required this.path,
    required this.scope,
    required this.enabled,
    required this.raw,
    this.shortDescription,
    this.interface,
  });

  static SkillSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    if (name == null) {
      return null;
    }
    return SkillSummary(
      name: name,
      description: _stringValue(map['description']) ?? '',
      shortDescription: _stringValue(map['shortDescription']),
      interface: SkillInterfaceSummary.fromJson(map['interface']),
      path: _stringValue(map['path']) ?? '',
      scope: _stringValue(map['scope']) ?? 'unknown',
      enabled: _boolValue(map['enabled']) ?? true,
      raw: map,
    );
  }

  final String name;
  final String description;
  final String? shortDescription;
  final SkillInterfaceSummary? interface;
  final String path;
  final String scope;
  final bool enabled;
  final Map<String, Object?> raw;

  String get displayName => interface?.displayName ?? name;

  String get summary {
    final interfaceDescription = interface?.shortDescription;
    if (interfaceDescription != null && interfaceDescription.isNotEmpty) {
      return interfaceDescription;
    }
    final legacyDescription = shortDescription;
    if (legacyDescription != null && legacyDescription.isNotEmpty) {
      return legacyDescription;
    }
    return description;
  }
}

class SkillInterfaceSummary {
  const SkillInterfaceSummary({
    this.displayName,
    this.shortDescription,
    this.brandColor,
    this.defaultPrompt,
  });

  static SkillInterfaceSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    return SkillInterfaceSummary(
      displayName: _stringValue(map['displayName']),
      shortDescription: _stringValue(map['shortDescription']),
      brandColor: _stringValue(map['brandColor']),
      defaultPrompt: _stringValue(map['defaultPrompt']),
    );
  }

  final String? displayName;
  final String? shortDescription;
  final String? brandColor;
  final String? defaultPrompt;
}

class SkillLoadError {
  const SkillLoadError({required this.path, required this.message});

  static SkillLoadError? fromJson(Object? value) {
    final map = _objectMap(value);
    final path = _stringValue(map['path']);
    final message = _stringValue(map['message']);
    if (path == null || message == null) {
      return null;
    }
    return SkillLoadError(path: path, message: message);
  }

  final String path;
  final String message;
}

List<SkillSummary> _skillList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.map(SkillSummary.fromJson).nonNulls);
}

List<SkillLoadError> _errorList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.map(SkillLoadError.fromJson).nonNulls);
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

bool? _boolValue(Object? value) {
  return value is bool ? value : null;
}
