abstract interface class McpResourceReader {
  Future<McpResourceReadResult> readResource({
    String? threadId,
    required String server,
    required String uri,
  });
}

class McpResourceReadResult {
  const McpResourceReadResult({required this.contents, required this.raw});

  factory McpResourceReadResult.fromJson(Map<String, Object?> json) {
    final rawContents = json['contents'];
    return McpResourceReadResult(
      contents: rawContents is List
          ? List.unmodifiable(
              rawContents.map(McpResourceContent.fromJson).nonNulls,
            )
          : const [],
      raw: Map.unmodifiable(json),
    );
  }

  final List<McpResourceContent> contents;
  final Map<String, Object?> raw;
}

class McpResourceContent {
  const McpResourceContent({
    required this.uri,
    required this.kind,
    required this.raw,
    this.mimeType,
    this.text,
    this.blob,
    this.meta,
  });

  static McpResourceContent? fromJson(Object? value) {
    final map = _objectMap(value);
    final uri = _nonBlankString(map['uri']);
    if (uri == null) {
      return null;
    }
    final text = map['text'];
    if (text is String) {
      return McpResourceContent(
        uri: uri,
        kind: McpResourceContentKind.text,
        mimeType: _nonBlankString(map['mimeType'] ?? map['mime_type']),
        text: text,
        meta: map['_meta'],
        raw: map,
      );
    }
    final blob = map['blob'];
    if (blob is String) {
      return McpResourceContent(
        uri: uri,
        kind: McpResourceContentKind.blob,
        mimeType: _nonBlankString(map['mimeType'] ?? map['mime_type']),
        blob: blob,
        meta: map['_meta'],
        raw: map,
      );
    }
    return null;
  }

  final String uri;
  final McpResourceContentKind kind;
  final String? mimeType;
  final String? text;
  final String? blob;
  final Object? meta;
  final Map<String, Object?> raw;
}

enum McpResourceContentKind { text, blob }

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _nonBlankString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
