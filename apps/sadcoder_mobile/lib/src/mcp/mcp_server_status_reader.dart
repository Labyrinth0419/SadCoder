abstract interface class McpServerStatusReader {
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  });
}

enum McpServerStatusDetail {
  full('full'),
  toolsAndAuthOnly('toolsAndAuthOnly');

  const McpServerStatusDetail(this.wireName);

  final String wireName;
}

class McpServerStatusPage {
  const McpServerStatusPage({required this.servers, this.nextCursor});

  factory McpServerStatusPage.fromJson(Map<String, Object?> json) {
    final rawServers = json['data'];
    return McpServerStatusPage(
      servers: rawServers is List
          ? List.unmodifiable(rawServers.map(McpServerStatus.fromJson).nonNulls)
          : const [],
      nextCursor: _stringValue(json['nextCursor']),
    );
  }

  final List<McpServerStatus> servers;
  final String? nextCursor;
}

class McpServerStatus {
  const McpServerStatus({
    required this.name,
    required this.authStatus,
    required this.tools,
    required this.resources,
    required this.resourceTemplates,
    required this.raw,
    this.serverInfo,
  });

  static McpServerStatus? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    if (name == null) {
      return null;
    }
    return McpServerStatus(
      name: name,
      serverInfo: McpServerInfo.fromJson(map['serverInfo']),
      tools: _toolMap(map['tools']),
      resources: _resourceList(map['resources']),
      resourceTemplates: _resourceTemplateList(map['resourceTemplates']),
      authStatus: _stringValue(map['authStatus']) ?? 'unknown',
      raw: map,
    );
  }

  final String name;
  final McpServerInfo? serverInfo;
  final Map<String, McpToolSummary> tools;
  final List<McpResourceSummary> resources;
  final List<McpResourceTemplateSummary> resourceTemplates;
  final String authStatus;
  final Map<String, Object?> raw;

  String get displayName {
    final title = serverInfo?.title;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return name;
  }
}

class McpServerInfo {
  const McpServerInfo({
    required this.name,
    required this.version,
    this.title,
    this.description,
    this.websiteUrl,
  });

  static McpServerInfo? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    final version = _stringValue(map['version']);
    if (name == null || version == null) {
      return null;
    }
    return McpServerInfo(
      name: name,
      version: version,
      title: _stringValue(map['title']),
      description: _stringValue(map['description']),
      websiteUrl: _stringValue(map['websiteUrl']),
    );
  }

  final String name;
  final String version;
  final String? title;
  final String? description;
  final String? websiteUrl;
}

class McpToolSummary {
  const McpToolSummary({
    required this.name,
    required this.raw,
    this.title,
    this.description,
  });

  static McpToolSummary? fromJson(String fallbackName, Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']) ?? fallbackName.trim();
    if (name.isEmpty) {
      return null;
    }
    return McpToolSummary(
      name: name,
      title: _stringValue(map['title']),
      description: _stringValue(map['description']),
      raw: map,
    );
  }

  final String name;
  final String? title;
  final String? description;
  final Map<String, Object?> raw;

  String get label {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    return name;
  }
}

class McpResourceSummary {
  const McpResourceSummary({
    required this.name,
    required this.uri,
    required this.raw,
    this.title,
    this.description,
    this.mimeType,
  });

  static McpResourceSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    final uri = _stringValue(map['uri']);
    if (name == null || uri == null) {
      return null;
    }
    return McpResourceSummary(
      name: name,
      uri: uri,
      title: _stringValue(map['title']),
      description: _stringValue(map['description']),
      mimeType: _stringValue(map['mimeType']),
      raw: map,
    );
  }

  final String name;
  final String uri;
  final String? title;
  final String? description;
  final String? mimeType;
  final Map<String, Object?> raw;

  String get label {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    return name;
  }
}

class McpResourceTemplateSummary {
  const McpResourceTemplateSummary({
    required this.name,
    required this.uriTemplate,
    required this.raw,
    this.title,
    this.description,
    this.mimeType,
  });

  static McpResourceTemplateSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    final uriTemplate = _stringValue(map['uriTemplate']);
    if (name == null || uriTemplate == null) {
      return null;
    }
    return McpResourceTemplateSummary(
      name: name,
      uriTemplate: uriTemplate,
      title: _stringValue(map['title']),
      description: _stringValue(map['description']),
      mimeType: _stringValue(map['mimeType']),
      raw: map,
    );
  }

  final String name;
  final String uriTemplate;
  final String? title;
  final String? description;
  final String? mimeType;
  final Map<String, Object?> raw;

  String get label {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    return name;
  }
}

Map<String, McpToolSummary> _toolMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  final tools = <String, McpToolSummary>{};
  for (final entry in value.entries) {
    final key = entry.key.toString();
    final tool = McpToolSummary.fromJson(key, entry.value);
    if (tool != null) {
      tools[key] = tool;
    }
  }
  return Map.unmodifiable(tools);
}

List<McpResourceSummary> _resourceList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.map(McpResourceSummary.fromJson).nonNulls);
}

List<McpResourceTemplateSummary> _resourceTemplateList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value.map(McpResourceTemplateSummary.fromJson).nonNulls,
  );
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
