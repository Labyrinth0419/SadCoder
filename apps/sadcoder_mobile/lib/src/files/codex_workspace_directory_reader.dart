import '../protocol/codex_app_server_client.dart';
import 'workspace_directory_reader.dart';
import 'workspace_file_failure.dart';
import 'workspace_file_kind.dart';
import 'workspace_path.dart';

class CodexWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const CodexWorkspaceDirectoryReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    try {
      final workspacePath = WorkspacePath.fromRoot(root, path);
      final response = await _client.fsReadDirectory(
        path: workspacePath.absolutePath,
      );
      final entries = _entriesFromResponse(
        response,
        workspacePath,
        includeHidden: includeHidden,
      );
      entries.sort(_compareEntries);

      final pageLimit = limit <= 0 ? 100 : limit;
      final start = _cursorOffset(cursor).clamp(0, entries.length);
      final end = (start + pageLimit).clamp(start, entries.length);
      final pageEntries = entries.sublist(start, end);
      return WorkspaceDirectoryPage(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        entries: List.unmodifiable(pageEntries),
        nextCursor: end < entries.length ? end.toString() : null,
      );
    } catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  List<WorkspaceDirectoryEntry> _entriesFromResponse(
    Map<String, Object?> response,
    WorkspacePath parentPath, {
    required bool includeHidden,
  }) {
    final rawEntries = response['entries'];
    if (rawEntries is! List) {
      return const [];
    }
    final entries = <WorkspaceDirectoryEntry>[];
    for (final rawEntry in rawEntries) {
      final map = _objectMap(rawEntry);
      final name = _stringValue(map['fileName'] ?? map['file_name']);
      if (name == null) {
        continue;
      }
      final hidden =
          _optionalBool(map['isHidden'] ?? map['is_hidden']) ??
          WorkspacePath.isHiddenName(name);
      if (hidden && !includeHidden) {
        continue;
      }
      final childPath = parentPath.child(name);
      entries.add(
        WorkspaceDirectoryEntry(
          root: childPath.root,
          path: childPath.relativePath,
          name: name,
          kind: _entryKind(map),
          sizeBytes: _intValue(
            map['sizeBytes'] ?? map['size_bytes'] ?? map['size'],
          ),
          modifiedAt: _dateFromUnixMilliseconds(
            _intValue(map['modifiedAtMs'] ?? map['modified_at_ms']),
          ),
          isHidden: hidden,
        ),
      );
    }
    return entries;
  }
}

int _compareEntries(
  WorkspaceDirectoryEntry left,
  WorkspaceDirectoryEntry right,
) {
  final leftRank = left.kind == WorkspaceFileKind.directory ? 0 : 1;
  final rightRank = right.kind == WorkspaceFileKind.directory ? 0 : 1;
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }
  return left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

WorkspaceFileKind _entryKind(Map<String, Object?> map) {
  if (map['isDirectory'] == true || map['is_directory'] == true) {
    return WorkspaceFileKind.directory;
  }
  if (map['isFile'] == true || map['is_file'] == true) {
    return WorkspaceFileKind.file;
  }
  return WorkspaceFileKind.unknown;
}

int _cursorOffset(String? cursor) {
  final parsed = int.tryParse(cursor ?? '');
  if (parsed == null || parsed < 0) {
    return 0;
  }
  return parsed;
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

bool? _optionalBool(Object? value) => value is bool ? value : null;

DateTime? _dateFromUnixMilliseconds(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}
