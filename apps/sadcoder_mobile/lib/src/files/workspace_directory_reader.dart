import 'workspace_file_kind.dart';

abstract interface class WorkspaceDirectoryReader {
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  });
}

class WorkspaceDirectoryPage {
  const WorkspaceDirectoryPage({
    required this.root,
    required this.path,
    required this.entries,
    this.nextCursor,
  });

  final String root;
  final String path;
  final List<WorkspaceDirectoryEntry> entries;
  final String? nextCursor;
}

class WorkspaceDirectoryEntry {
  const WorkspaceDirectoryEntry({
    required this.root,
    required this.path,
    required this.name,
    required this.kind,
    required this.isHidden,
    this.sizeBytes,
    this.modifiedAt,
  });

  final String root;
  final String path;
  final String name;
  final WorkspaceFileKind kind;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isHidden;
}
