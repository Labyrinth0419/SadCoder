import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_controller.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';

void main() {
  test('refresh loads MCP servers from the current reader', () async {
    final reader = _FakeMcpServerStatusReader(
      page: McpServerStatusPage.fromJson({
        'data': [
          {'name': 'filesystem', 'authStatus': 'unsupported'},
        ],
      }),
    );
    final controller = McpServerStatusController(readerProvider: () => reader);
    addTearDown(controller.dispose);
    final statuses = <McpServerStatusListStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh(
      threadId: 'thr_1',
      limit: 25,
      detail: McpServerStatusDetail.toolsAndAuthOnly,
    );

    expect(reader.threadIds, ['thr_1']);
    expect(reader.limits, [25]);
    expect(reader.details, [McpServerStatusDetail.toolsAndAuthOnly]);
    expect(controller.status, McpServerStatusListStatus.loaded);
    expect(controller.servers.single.name, 'filesystem');
    expect(statuses, [
      McpServerStatusListStatus.loading,
      McpServerStatusListStatus.loaded,
    ]);
  });

  test(
    'refresh without a reader returns to idle without clearing cache',
    () async {
      _FakeMcpServerStatusReader? reader = _FakeMcpServerStatusReader(
        page: McpServerStatusPage.fromJson({
          'data': [
            {'name': 'filesystem', 'authStatus': 'unsupported'},
          ],
        }),
      );
      final controller = McpServerStatusController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, McpServerStatusListStatus.idle);
      expect(controller.servers.single.name, 'filesystem');
    },
  );

  test('refresh records failures', () async {
    final controller = McpServerStatusController(
      readerProvider: () => _FailingMcpServerStatusReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, McpServerStatusListStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakeMcpServerStatusReader implements McpServerStatusReader {
  _FakeMcpServerStatusReader({required this.page});

  final McpServerStatusPage page;
  final threadIds = <String?>[];
  final cursors = <String?>[];
  final limits = <int?>[];
  final details = <McpServerStatusDetail>[];

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    threadIds.add(threadId);
    cursors.add(cursor);
    limits.add(limit);
    details.add(detail);
    return page;
  }
}

class _FailingMcpServerStatusReader implements McpServerStatusReader {
  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) {
    throw StateError('mcp failed');
  }
}
