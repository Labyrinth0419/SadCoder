abstract interface class FileSearchReader {
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  });
}

class FileSearchResultPage {
  const FileSearchResultPage({required this.files});

  factory FileSearchResultPage.fromJson(Map<String, Object?> json) {
    return FileSearchResultPage(
      files: _list(
        json['files'],
      ).map(FileSearchMatch.fromJson).nonNulls.toList(growable: false),
    );
  }

  final List<FileSearchMatch> files;
}

class FileSearchMatch {
  const FileSearchMatch({
    required this.root,
    required this.path,
    required this.matchType,
    required this.fileName,
    required this.score,
    required this.indices,
  });

  static FileSearchMatch? fromJson(Object? value) {
    final map = _objectMap(value);
    final root = _stringValue(map['root']);
    final path = _stringValue(map['path']);
    if (root == null || path == null) {
      return null;
    }
    return FileSearchMatch(
      root: root,
      path: path,
      matchType: _stringValue(map['match_type']) ?? '',
      fileName: _stringValue(map['file_name']) ?? _basename(path),
      score: _intValue(map['score']) ?? 0,
      indices: _intList(map['indices']),
    );
  }

  final String root;
  final String path;
  final String matchType;
  final String fileName;
  final int score;
  final List<int> indices;
}

List<Object?> _list(Object? value) {
  return value is List ? value : const [];
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

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

List<int> _intList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.map(_intValue).nonNulls);
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash == -1 || slash == normalized.length - 1) {
    return normalized;
  }
  return normalized.substring(slash + 1);
}
