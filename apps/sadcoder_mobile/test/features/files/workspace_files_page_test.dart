import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/files/workspace_files_page.dart';
import 'package:sadcoder_mobile/src/files/workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('browses directories and toggles Markdown render/raw modes', (
    tester,
  ) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [
        _entry(path: 'lib', name: 'lib', kind: WorkspaceFileKind.directory),
        _entry(path: 'README.md', name: 'README.md'),
      ],
      'lib': [_entry(path: 'lib/main.dart', name: 'main.dart')],
    });
    const markdown = '# Guide\n- item';
    final fileReader = _FakeWorkspaceFileReader(
      stats: {
        'README.md': _stat(path: 'README.md', language: 'markdown'),
        'lib/main.dart': _stat(path: 'lib/main.dart', language: 'dart'),
      },
      chunks: {
        'README.md': [
          _chunk(
            path: 'README.md',
            content: markdown,
            sizeBytes: markdown.length,
          ),
        ],
        'lib/main.dart': [
          _chunk(path: 'lib/main.dart', content: 'void main() {}'),
        ],
      },
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );

    expect(find.text('Workspace files'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-files-entry-lib')),
      findsOneWidget,
    );
    expect(find.text('README.md'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('workspace-files-entry-lib')));
    await tester.pumpAndSettle();
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-README.md')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('# Guide'), findsNothing);

    await tester.ensureVisible(find.text('Raw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();
    expect(find.textContaining('# Guide'), findsOneWidget);
  });

  testWidgets('loads additional file chunks', (tester) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'large.txt', name: 'large.txt')],
    });
    final fileReader = _FakeWorkspaceFileReader(
      stats: {'large.txt': _stat(path: 'large.txt', language: 'text')},
      chunks: {
        'large.txt': [
          _chunk(
            path: 'large.txt',
            content: 'hello ',
            sizeBytes: 11,
            nextOffset: 6,
            hasMore: true,
          ),
          _chunk(path: 'large.txt', content: 'world', sizeBytes: 11, offset: 6),
        ],
      },
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-large.txt')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('hello'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-preview-load-more')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('hello world'), findsOneWidget);
  });

  testWidgets('filters visible workspace entries', (tester) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [
        _entry(path: 'README.md', name: 'README.md'),
        _entry(path: 'pubspec.yaml', name: 'pubspec.yaml'),
      ],
    });

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    await tester.enterText(
      find.byKey(const ValueKey('workspace-files-filter')),
      'pub',
    );
    await tester.pumpAndSettle();

    expect(find.text('pubspec.yaml'), findsWidgets);
    expect(find.text('README.md'), findsNothing);
  });

  testWidgets('shows binary file preview state', (tester) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'image.png', name: 'image.png')],
    });
    final fileReader = _FakeWorkspaceFileReader(
      stats: {'image.png': _stat(path: 'image.png', isBinary: true)},
      chunks: const {},
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-image.png')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Binary files cannot be previewed.'), findsOneWidget);
  });

  testWidgets('shows no connection and no cwd states', (tester) async {
    await _pumpFilesPage(tester);

    expect(find.text('Connect to a host to browse files.'), findsOneWidget);

    await _pumpFilesPage(
      tester,
      root: null,
      directoryReader: const _FakeWorkspaceDirectoryReader({}),
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(
      find.text('Select a thread or set a working directory.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpFilesPage(
  WidgetTester tester, {
  WorkspaceDirectoryReader? directoryReader,
  WorkspaceFileReader? fileReader,
  String? root = '/repo',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WorkspaceFilesPage(
          root: root,
          directoryReader: directoryReader,
          fileReader: fileReader,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WorkspaceDirectoryEntry _entry({
  required String path,
  required String name,
  WorkspaceFileKind kind = WorkspaceFileKind.file,
}) {
  return WorkspaceDirectoryEntry(
    root: '/repo',
    path: path,
    name: name,
    kind: kind,
    isHidden: name.startsWith('.'),
  );
}

WorkspaceFileStat _stat({
  required String path,
  String? language,
  bool isBinary = false,
}) {
  return WorkspaceFileStat(
    root: '/repo',
    path: path,
    kind: WorkspaceFileKind.file,
    isBinary: isBinary,
    language: language,
  );
}

WorkspaceFileReadChunk _chunk({
  required String path,
  required String content,
  int offset = 0,
  int? sizeBytes,
  int? nextOffset,
  bool hasMore = false,
}) {
  return WorkspaceFileReadChunk(
    root: '/repo',
    path: path,
    sizeBytes: sizeBytes ?? content.length,
    offset: offset,
    bytesRead: content.length,
    nextOffset: nextOffset,
    hasMore: hasMore,
    encoding: 'utf-8',
    isBinary: false,
    content: content,
  );
}

class _FakeWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _FakeWorkspaceDirectoryReader([this.entriesByPath = const {}]);

  final Map<String, List<WorkspaceDirectoryEntry>> entriesByPath;

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    final entries = entriesByPath[path];
    if (entries == null) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notFound,
        'Workspace path was not found.',
      );
    }
    return WorkspaceDirectoryPage(root: root, path: path, entries: entries);
  }
}

class _FakeWorkspaceFileReader implements WorkspaceFileReader {
  const _FakeWorkspaceFileReader({
    this.stats = const {},
    this.chunks = const {},
  });

  final Map<String, WorkspaceFileStat> stats;
  final Map<String, List<WorkspaceFileReadChunk>> chunks;

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    final stat = stats[path];
    if (stat == null) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notFound,
        'Workspace path was not found.',
      );
    }
    return stat;
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    final chunk = chunks[path]
        ?.where((chunk) => chunk.offset == offset)
        .firstOrNull;
    if (chunk == null) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notFound,
        'Workspace path was not found.',
      );
    }
    return chunk;
  }
}
