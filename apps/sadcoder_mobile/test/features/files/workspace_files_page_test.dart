import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/features/files/workspace_files_page.dart';
import 'package:sadcoder_mobile/src/files/file_search_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

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

    final loadMore = find.byKey(
      const ValueKey('workspace-files-preview-load-more'),
    );
    await tester.ensureVisible(loadMore);
    await tester.pumpAndSettle();
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    expect(find.textContaining('hello world'), findsOneWidget);
  });

  testWidgets('keeps large Markdown in raw mode after loading all chunks', (
    tester,
  ) async {
    const largeMarkdownBytes = 300 * 1024;
    const secondOffset = 32 * 1024;
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'big.md', name: 'big.md')],
    });
    final fileReader = _FakeWorkspaceFileReader(
      stats: {'big.md': _stat(path: 'big.md', language: 'markdown')},
      chunks: {
        'big.md': [
          _chunk(
            path: 'big.md',
            content: '# Big\nfirst\n',
            sizeBytes: largeMarkdownBytes,
            bytesRead: secondOffset,
            nextOffset: secondOffset,
            hasMore: true,
          ),
          _chunk(
            path: 'big.md',
            content: 'second\n',
            offset: secondOffset,
            sizeBytes: largeMarkdownBytes,
            bytesRead: largeMarkdownBytes - secondOffset,
          ),
        ],
      },
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-big.md')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('# Big'), findsOneWidget);
    expect(find.text('Big'), findsNothing);
    expect(
      find.textContaining('Markdown rendering is available'),
      findsOneWidget,
    );
    expect(_markdownRenderSegmentEnabled(tester), isFalse);

    final markdownLoadMore = find.byKey(
      const ValueKey('workspace-files-preview-load-more'),
    );
    await tester.ensureVisible(markdownLoadMore);
    await tester.pumpAndSettle();
    await tester.tap(markdownLoadMore);
    await tester.pumpAndSettle();

    expect(find.textContaining('# Big'), findsOneWidget);
    expect(find.text('Big'), findsNothing);
    expect(
      find.textContaining('Markdown rendering is available'),
      findsOneWidget,
    );
    expect(find.text('Load more'), findsNothing);
    expect(_markdownRenderSegmentEnabled(tester), isFalse);

    await tester.tap(find.text('Rendered'));
    await tester.pumpAndSettle();

    expect(find.textContaining('# Big'), findsOneWidget);
    expect(find.text('Big'), findsNothing);
  });

  testWidgets('uses semantic code colors in dark file previews', (
    tester,
  ) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'lib/main.dart', name: 'main.dart')],
    });
    const code =
        'void main() {\n'
        '  final url = "https://example.com"; // comment\n'
        '}';
    final fileReader = _FakeWorkspaceFileReader(
      stats: {'lib/main.dart': _stat(path: 'lib/main.dart', language: 'dart')},
      chunks: {
        'lib/main.dart': [
          _chunk(path: 'lib/main.dart', content: code, sizeBytes: code.length),
        ],
      },
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
      themeMode: ThemeMode.dark,
    );
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-lib/main.dart')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == SadCoderThemeColors.dark.codeBackground;
      }),
      findsOneWidget,
    );

    final codeTextFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          widget.textSpan?.toPlainText().contains('void main') == true,
    );
    final codeText = tester.widget<SelectableText>(codeTextFinder);
    expect(
      codeText.textSpan?.style?.color,
      SadCoderThemeColors.dark.codeForeground,
    );

    final spanColors = codeText.textSpan!.children
        ?.whereType<TextSpan>()
        .map((span) => span.style?.color)
        .toSet();
    expect(spanColors, contains(SadCoderThemeColors.dark.codeKeyword));
    expect(spanColors, contains(SadCoderThemeColors.dark.codeString));
    expect(spanColors, contains(SadCoderThemeColors.dark.codeComment));
    final spans = codeText.textSpan!.children!.whereType<TextSpan>().toList();
    expect(
      spans.any(
        (span) =>
            span.text == '"https://example.com"' &&
            span.style?.color == SadCoderThemeColors.dark.codeString,
      ),
      true,
    );
    expect(
      spans.any(
        (span) =>
            span.text == '// comment' &&
            span.style?.color == SadCoderThemeColors.dark.codeComment,
      ),
      true,
    );
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

  testWidgets('opens remote file search results from the current root', (
    tester,
  ) async {
    final searchCalls = <_FileSearchCall>[];
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'README.md', name: 'README.md')],
    });
    const code = 'class SearchHit {}';
    final fileReader = _FakeWorkspaceFileReader(
      stats: {'lib/search_hit.dart': _stat(path: 'lib/search_hit.dart')},
      chunks: {
        'lib/search_hit.dart': [
          _chunk(
            path: 'lib/search_hit.dart',
            content: code,
            sizeBytes: code.length,
          ),
        ],
      },
    );
    final searchReader = _FakeFileSearchReader(
      calls: searchCalls,
      page: const FileSearchResultPage(
        files: [
          FileSearchMatch(
            root: '/repo',
            path: 'lib/search_hit.dart',
            matchType: 'fuzzy',
            fileName: 'search_hit.dart',
            score: 10,
            indices: [4],
          ),
        ],
      ),
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
      fileSearchReader: searchReader,
    );

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-remote-search')),
    );
    await tester.pumpAndSettle();

    expect(searchCalls.single.roots, ['/repo']);
    expect(find.text('lib/search_hit.dart'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-mention-file-lib/search_hit.dart')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('class SearchHit'), findsOneWidget);
  });

  testWidgets('keeps the file browser toolbar read-only', (tester) async {
    await _pumpFilesPage(
      tester,
      directoryReader: const _FakeWorkspaceDirectoryReader({'': []}),
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(
      find.byKey(const ValueKey('workspace-files-terminal')),
      findsNothing,
    );
    expect(find.byIcon(Icons.terminal), findsNothing);
  });

  testWidgets('rejects unsafe remote file search result paths before reading', (
    tester,
  ) async {
    final fileReader = _RecordingWorkspaceFileReader();
    final searchReader = _FakeFileSearchReader(
      page: const FileSearchResultPage(
        files: [
          FileSearchMatch(
            root: '/repo',
            path: '../secret.txt',
            matchType: 'fuzzy',
            fileName: 'secret.txt',
            score: 10,
            indices: [0],
          ),
        ],
      ),
    );

    await _pumpFilesPage(
      tester,
      directoryReader: const _FakeWorkspaceDirectoryReader({'': []}),
      fileReader: fileReader,
      fileSearchReader: searchReader,
    );

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-remote-search')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chat-mention-file-../secret.txt')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Path is outside the workspace root.'), findsOneWidget);
    expect(fileReader.statCalls, isEmpty);
    expect(fileReader.readCalls, isEmpty);
  });

  testWidgets('formats file row metadata with the active locale', (
    tester,
  ) async {
    final modifiedAt = DateTime.utc(2024, 11, 7, 8, 9);
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [
        _entry(
          path: 'lib/main.dart',
          name: 'main.dart',
          sizeBytes: 2048,
          modifiedAt: modifiedAt,
        ),
      ],
    });

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(find.textContaining('Size: 2 KB'), findsOneWidget);
    expect(find.textContaining('Modified:'), findsOneWidget);
    expect(find.textContaining('2024'), findsOneWidget);

    await _pumpFilesPage(
      tester,
      locale: const Locale('zh', 'CN'),
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(find.textContaining('大小：2 KB'), findsOneWidget);
    expect(find.textContaining('修改时间：'), findsOneWidget);
    expect(find.textContaining('2024'), findsOneWidget);
  });

  testWidgets('pages directory rows', (tester) async {
    final calls = <_DirectoryListCall>[];
    final entriesByPath = <String, List<WorkspaceDirectoryEntry>>{
      '': [
        _entry(path: '.env', name: '.env'),
        ...List.generate(
          101,
          (index) => _entry(
            path: 'file${index.toString().padLeft(3, '0')}.txt',
            name: 'file${index.toString().padLeft(3, '0')}.txt',
          ),
        ),
      ],
    };
    final directoryReader = _FakeWorkspaceDirectoryReader(entriesByPath, calls);

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(find.text('.env'), findsNothing);
    expect(find.text('file000.txt'), findsWidgets);
    expect(find.text('file100.txt'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('workspace-files-load-more-')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-files-load-more-')));
    await tester.pumpAndSettle();
    expect(find.text('file100.txt'), findsWidgets);

    expect(calls.map((call) => call.cursor), contains('100'));
  });

  testWidgets('reloads hidden files on refresh', (tester) async {
    final calls = <_DirectoryListCall>[];
    final entriesByPath = <String, List<WorkspaceDirectoryEntry>>{
      '': [
        _entry(path: '.env', name: '.env'),
        _entry(path: 'visible.txt', name: 'visible.txt'),
      ],
    };
    final directoryReader = _FakeWorkspaceDirectoryReader(entriesByPath, calls);

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(find.text('.env'), findsNothing);
    expect(find.text('visible.txt'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-hidden-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('.env'), findsWidgets);

    entriesByPath[''] = [_entry(path: 'refreshed.txt', name: 'refreshed.txt')];
    await tester.tap(find.byKey(const ValueKey('workspace-files-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('refreshed.txt'), findsWidgets);
    expect(find.text('visible.txt'), findsNothing);
    expect(calls.map((call) => call.includeHidden), containsAll([false, true]));
  });

  testWidgets('copies workspace paths without opening files', (tester) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'README.md', name: 'README.md')],
    });
    final fileReader = _RecordingWorkspaceFileReader();
    Object? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'];
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );
    await tester.tap(find.byTooltip('Copy path'));
    await tester.pumpAndSettle();

    expect(clipboardText, '/repo/README.md');
    expect(find.text('Path copied.'), findsOneWidget);
    expect(fileReader.statCalls, isEmpty);
    expect(fileReader.readCalls, isEmpty);
  });

  testWidgets('shows absolute paths while reading relative workspace paths', (
    tester,
  ) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'lib/main.dart', name: 'main.dart')],
    });
    final fileReader = _RecordingWorkspaceFileReader(
      delegate: _FakeWorkspaceFileReader(
        stats: {
          'lib/main.dart': _stat(path: 'lib/main.dart', language: 'dart'),
        },
        chunks: {
          'lib/main.dart': [
            _chunk(path: 'lib/main.dart', content: 'void main() {}'),
          ],
        },
      ),
    );

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );

    expect(find.textContaining('/repo/lib/main.dart'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-lib/main.dart')),
    );
    await tester.pumpAndSettle();

    expect(find.text('/repo/lib/main.dart'), findsWidgets);
    expect(fileReader.statCalls.single.root, '/repo');
    expect(fileReader.readCalls.single.root, '/repo');
    expect(fileReader.statCalls.single.path, 'lib/main.dart');
    expect(fileReader.readCalls.single.path, 'lib/main.dart');
  });

  testWidgets('uses host separators for copied Windows workspace paths', (
    tester,
  ) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'lib/main.dart', name: 'main.dart')],
    });
    Object? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'];
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpFilesPage(
      tester,
      root: r'C:\repo',
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
    );

    await tester.tap(find.byTooltip('Copy path'));
    await tester.pumpAndSettle();

    expect(clipboardText, r'C:\repo\lib\main.dart');
  });

  testWidgets('shows binary file preview state', (tester) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'image.png', name: 'image.png')],
    });
    final fileReader = _FakeWorkspaceFileReader(
      stats: {
        'image.png': _stat(
          path: 'image.png',
          isBinary: true,
          mimeType: 'image/png',
          sizeBytes: 2048,
        ),
      },
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
    expect(find.text('Size: 2 KB'), findsOneWidget);
    expect(find.text('Type: image/png'), findsOneWidget);
  });

  testWidgets('does not expand or read symlink directory entries', (
    tester,
  ) async {
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [
        _entry(
          path: 'linked',
          name: 'linked',
          kind: WorkspaceFileKind.directory,
          isSymlink: true,
        ),
      ],
      'linked': [_entry(path: 'linked/secret.txt', name: 'secret.txt')],
    });
    final fileReader = _RecordingWorkspaceFileReader();

    await _pumpFilesPage(
      tester,
      directoryReader: directoryReader,
      fileReader: fileReader,
    );
    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-linked')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Path is outside the workspace root.'), findsOneWidget);
    expect(find.text('secret.txt'), findsNothing);
    expect(fileReader.statCalls, isEmpty);
    expect(fileReader.readCalls, isEmpty);
  });

  testWidgets('shows empty directory and structured file error states', (
    tester,
  ) async {
    Future<void> pumpErrorCase({
      required String path,
      required String expectedText,
      Map<String, WorkspaceFileException> statErrors = const {},
      Map<String, WorkspaceFileException> readErrors = const {},
    }) async {
      await _pumpFilesPage(
        tester,
        directoryReader: _FakeWorkspaceDirectoryReader({
          '': [_entry(path: path, name: path)],
        }),
        fileReader: _FakeWorkspaceFileReader(
          stats: {path: _stat(path: path)},
          statErrors: statErrors,
          readErrors: readErrors,
        ),
      );

      await tester.tap(find.byKey(ValueKey('workspace-files-entry-$path')));
      await tester.pumpAndSettle();
      expect(find.text(expectedText), findsOneWidget);
    }

    await _pumpFilesPage(
      tester,
      directoryReader: const _FakeWorkspaceDirectoryReader({'': []}),
      fileReader: const _FakeWorkspaceFileReader(),
    );

    expect(find.text('No files found'), findsOneWidget);

    await pumpErrorCase(
      path: 'denied.txt',
      expectedText: 'Permission denied while reading path.',
      readErrors: const {
        'denied.txt': WorkspaceFileException(
          WorkspaceFileFailureCode.permissionDenied,
          'Workspace path cannot be read because permission was denied.',
        ),
      },
    );
    await pumpErrorCase(
      path: 'large.txt',
      expectedText: 'File is too large to preview.',
      readErrors: const {
        'large.txt': WorkspaceFileException(
          WorkspaceFileFailureCode.tooLarge,
          'Workspace file is too large to preview.',
        ),
      },
    );
    await pumpErrorCase(
      path: 'missing.txt',
      expectedText: 'Path was not found.',
      statErrors: const {
        'missing.txt': WorkspaceFileException(
          WorkspaceFileFailureCode.notFound,
          'Workspace path was not found.',
        ),
      },
    );
    await pumpErrorCase(
      path: 'outside.txt',
      expectedText: 'Path is outside the workspace root.',
      statErrors: const {
        'outside.txt': WorkspaceFileException(
          WorkspaceFileFailureCode.pathOutsideRoot,
          'Workspace path is outside the workspace root.',
        ),
      },
    );
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

  testWidgets('uses cwd override before selected thread cwd', (tester) async {
    final calls = <_DirectoryListCall>[];
    final directoryReader = _FakeWorkspaceDirectoryReader({
      '': [_entry(path: 'README.md', name: 'README.md')],
    }, calls);
    final configOverrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/override'),
      ),
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        ThreadDetail(thread: _threadSummary(cwd: '/thread')),
      ),
    );
    addTearDown(configOverrideController.dispose);
    addTearDown(threadDetailController.dispose);
    await threadDetailController.readThread('thr_1');

    await _pumpFilesPage(
      tester,
      root: null,
      directoryReader: directoryReader,
      fileReader: const _FakeWorkspaceFileReader(),
      configOverrideController: configOverrideController,
      threadDetailController: threadDetailController,
    );

    expect(find.text('Root: /override'), findsOneWidget);
    expect(calls.last.root, '/override');

    configOverrideController.clearSession();
    await tester.pumpAndSettle();

    expect(find.text('Root: /thread'), findsOneWidget);
    expect(calls.last.root, '/thread');
  });
}

Future<void> _pumpFilesPage(
  WidgetTester tester, {
  WorkspaceDirectoryReader? directoryReader,
  WorkspaceFileReader? fileReader,
  FileSearchReader? fileSearchReader,
  String? root = '/repo',
  ThemeMode themeMode = ThemeMode.light,
  Locale? locale,
  CodexConfigOverrideController? configOverrideController,
  ThreadDetailController? threadDetailController,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ThemeData(extensions: const [SadCoderThemeColors.light]),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [SadCoderThemeColors.dark],
      ),
      themeMode: themeMode,
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
          fileSearchReader: fileSearchReader,
          configOverrideController: configOverrideController,
          threadDetailController: threadDetailController,
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
  bool isSymlink = false,
  int? sizeBytes,
  DateTime? modifiedAt,
}) {
  return WorkspaceDirectoryEntry(
    root: '/repo',
    path: path,
    name: name,
    kind: kind,
    sizeBytes: sizeBytes,
    modifiedAt: modifiedAt,
    isHidden: name.startsWith('.'),
    isSymlink: isSymlink,
  );
}

WorkspaceFileStat _stat({
  required String path,
  String? language,
  bool isBinary = false,
  String? mimeType,
  int? sizeBytes,
  bool isSymlink = false,
}) {
  return WorkspaceFileStat(
    root: '/repo',
    path: path,
    kind: WorkspaceFileKind.file,
    sizeBytes: sizeBytes,
    isSymlink: isSymlink,
    isBinary: isBinary,
    mimeType: mimeType,
    language: language,
  );
}

WorkspaceFileReadChunk _chunk({
  required String path,
  required String content,
  int offset = 0,
  int? bytesRead,
  int? sizeBytes,
  int? nextOffset,
  bool hasMore = false,
}) {
  return WorkspaceFileReadChunk(
    root: '/repo',
    path: path,
    sizeBytes: sizeBytes ?? content.length,
    offset: offset,
    bytesRead: bytesRead ?? content.length,
    nextOffset: nextOffset,
    hasMore: hasMore,
    encoding: 'utf-8',
    isBinary: false,
    content: content,
  );
}

bool _markdownRenderSegmentEnabled(WidgetTester tester) {
  final segmentedButton =
      tester.widget<Widget>(
            find.byKey(const ValueKey('workspace-files-markdown-mode')),
          )
          as dynamic;
  final segments = segmentedButton.segments as List<dynamic>;
  return segments.first.enabled as bool;
}

class _FakeWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _FakeWorkspaceDirectoryReader([
    this.entriesByPath = const {},
    this.calls,
  ]);

  final Map<String, List<WorkspaceDirectoryEntry>> entriesByPath;
  final List<_DirectoryListCall>? calls;

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    calls?.add(
      _DirectoryListCall(
        root: root,
        path: path,
        cursor: cursor,
        includeHidden: includeHidden,
      ),
    );
    final entries = entriesByPath[path];
    if (entries == null) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notFound,
        'Workspace path was not found.',
      );
    }
    final visibleEntries = [
      for (final entry in entries)
        if (includeHidden || !entry.isHidden) entry,
    ];
    final pageLimit = limit <= 0 ? 100 : limit;
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + pageLimit).clamp(start, visibleEntries.length);
    return WorkspaceDirectoryPage(
      root: root,
      path: path,
      entries: visibleEntries.sublist(start, end),
      nextCursor: end < visibleEntries.length ? end.toString() : null,
    );
  }
}

class _DirectoryListCall {
  const _DirectoryListCall({
    required this.root,
    required this.path,
    required this.cursor,
    required this.includeHidden,
  });

  final String root;
  final String path;
  final String? cursor;
  final bool includeHidden;
}

class _FakeWorkspaceFileReader implements WorkspaceFileReader {
  const _FakeWorkspaceFileReader({
    this.stats = const {},
    this.chunks = const {},
    this.statErrors = const {},
    this.readErrors = const {},
  });

  final Map<String, WorkspaceFileStat> stats;
  final Map<String, List<WorkspaceFileReadChunk>> chunks;
  final Map<String, WorkspaceFileException> statErrors;
  final Map<String, WorkspaceFileException> readErrors;

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    final error = statErrors[path];
    if (error != null) {
      throw error;
    }
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
    final error = readErrors[path];
    if (error != null) {
      throw error;
    }
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

class _FakeFileSearchReader implements FileSearchReader {
  const _FakeFileSearchReader({required this.page, this.calls});

  final FileSearchResultPage page;
  final List<_FileSearchCall>? calls;

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    calls?.add(_FileSearchCall(query: query, roots: roots));
    return page;
  }
}

class _FileSearchCall {
  const _FileSearchCall({required this.query, required this.roots});

  final String query;
  final List<String> roots;
}

class _RecordingWorkspaceFileReader implements WorkspaceFileReader {
  _RecordingWorkspaceFileReader({WorkspaceFileReader? delegate})
    : _delegate = delegate;

  final WorkspaceFileReader? _delegate;
  final List<_FileStatCall> statCalls = [];
  final List<_FileReadCall> readCalls = [];

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    statCalls.add(_FileStatCall(root: root, path: path));
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.statFile(root: root, path: path);
    }
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Unexpected stat.',
    );
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    readCalls.add(
      _FileReadCall(
        root: root,
        path: path,
        offset: offset,
        limitBytes: limitBytes,
        encoding: encoding,
      ),
    );
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.readFile(
        root: root,
        path: path,
        offset: offset,
        limitBytes: limitBytes,
        encoding: encoding,
      );
    }
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Unexpected read.',
    );
  }
}

class _FileStatCall {
  const _FileStatCall({required this.root, required this.path});

  final String root;
  final String path;
}

class _FileReadCall {
  const _FileReadCall({
    required this.root,
    required this.path,
    required this.offset,
    required this.limitBytes,
    required this.encoding,
  });

  final String root;
  final String path;
  final int offset;
  final int limitBytes;
  final String encoding;
}

class _FakeThreadDetailReader implements ThreadDetailReader {
  const _FakeThreadDetailReader(this.detail);

  final ThreadDetail detail;

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    return detail;
  }
}

ThreadSummary _threadSummary({required String cwd}) {
  return ThreadSummary.fromJson({
    'id': 'thr_1',
    'sessionId': 'sess_1',
    'preview': 'Browse files',
    'ephemeral': false,
    'status': 'idle',
    'cwd': cwd,
    'updatedAt': 1,
  });
}
