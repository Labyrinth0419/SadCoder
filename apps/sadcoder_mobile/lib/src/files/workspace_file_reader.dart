import 'workspace_file_kind.dart';

abstract interface class WorkspaceFileReader {
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  });

  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  });
}

class WorkspaceFileStat {
  const WorkspaceFileStat({
    required this.root,
    required this.path,
    required this.kind,
    this.sizeBytes,
    this.modifiedAt,
    this.isSymlink = false,
    this.isBinary,
    this.mimeType,
    this.language,
    this.contentVersion,
  });

  final String root;
  final String path;
  final WorkspaceFileKind kind;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final bool isSymlink;
  final bool? isBinary;
  final String? mimeType;
  final String? language;
  final String? contentVersion;
}

class WorkspaceFileReadChunk {
  const WorkspaceFileReadChunk({
    required this.root,
    required this.path,
    required this.sizeBytes,
    required this.offset,
    required this.bytesRead,
    required this.hasMore,
    required this.encoding,
    required this.isBinary,
    required this.content,
    this.nextOffset,
    this.contentVersion,
  });

  final String root;
  final String path;
  final int sizeBytes;
  final int offset;
  final int bytesRead;
  final int? nextOffset;
  final bool hasMore;
  final String encoding;
  final bool isBinary;
  final String content;
  final String? contentVersion;
}
