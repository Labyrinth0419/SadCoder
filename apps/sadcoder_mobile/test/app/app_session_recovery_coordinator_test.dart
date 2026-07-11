import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/app_session_recovery_coordinator.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/threads/thread_turn_list_reader.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';

void main() {
  test('refreshes thread list once when session becomes connected', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.idle);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadListReader.limits, [20]);
    expect(fixture.threadDetailReader.threadIds, isEmpty);
  });

  test('rereads the selected thread after reconnect', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.reconnecting);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadListReader.limits, [20, 20]);
    expect(fixture.threadDetailReader.threadIds, [
      'thr_selected',
      'thr_selected',
    ]);
    expect(fixture.threadDetailReader.includeTurnsValues, [true, true]);
  });

  test(
    'backfills recent turns after reconnect with thread turns list',
    () async {
      final turnListReader = _RecordingThreadTurnListReader(
        page: ThreadTurnsPage(
          turns: [
            _turn('turn_newer', 'completed', 'newer'),
            _turn('turn_older', 'completed', 'older'),
          ],
        ),
      );
      final fixture = _Fixture(threadTurnListReader: turnListReader);
      addTearDown(fixture.dispose);
      await fixture.threadDetailController.readThread('thr_selected');
      fixture.threadDetailReader.clear();

      fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
      await _flushMicrotasks();

      expect(fixture.threadDetailReader.threadIds, ['thr_selected']);
      expect(fixture.threadDetailReader.includeTurnsValues, [false]);
      expect(turnListReader.calls, [
        (
          threadId: 'thr_selected',
          cursor: null,
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
      ]);
      expect(
        fixture.threadDetailController.detail?.turns.map((turn) => turn.id),
        ['turn_older', 'turn_newer'],
      );
      expect(
        fixture.threadDetailController.detail?.turns.last.items.single.text,
        'newer',
      );
    },
  );

  test('backfills recent turns across bounded pages', () async {
    final turnListReader = _RecordingThreadTurnListReader.pages([
      ThreadTurnsPage(
        turns: [
          _turn('turn_newest', 'completed', 'newest'),
          _turn('turn_middle', 'completed', 'middle'),
        ],
        nextCursor: 'older_turns',
      ),
      ThreadTurnsPage(turns: [_turn('turn_oldest', 'completed', 'oldest')]),
    ]);
    final fixture = _Fixture(threadTurnListReader: turnListReader);
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(turnListReader.calls, [
      (
        threadId: 'thr_selected',
        cursor: null,
        limit: 50,
        sortDirection: 'desc',
        itemsView: 'full',
      ),
      (
        threadId: 'thr_selected',
        cursor: 'older_turns',
        limit: 50,
        sortDirection: 'desc',
        itemsView: 'full',
      ),
    ]);
    expect(
      fixture.threadDetailController.detail?.turns.map((turn) => turn.id),
      ['turn_oldest', 'turn_middle', 'turn_newest'],
    );
  });

  test('deduplicates paged turn backfill by id', () async {
    final turnListReader = _RecordingThreadTurnListReader.pages([
      ThreadTurnsPage(
        turns: [
          _turn('turn_newest', 'completed', 'newest'),
          _turn('turn_overlap', 'completed', 'newer overlap'),
        ],
        nextCursor: 'older_turns',
      ),
      ThreadTurnsPage(
        turns: [
          _turn('turn_overlap', 'completed', 'older overlap'),
          _turn('turn_oldest', 'completed', 'oldest'),
        ],
      ),
    ]);
    final fixture = _Fixture(threadTurnListReader: turnListReader);
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    final turns = fixture.threadDetailController.detail?.turns ?? const [];
    expect(turns.map((turn) => turn.id), [
      'turn_oldest',
      'turn_overlap',
      'turn_newest',
    ]);
    expect(turns[1].items.single.text, 'newer overlap');
  });

  test('backfills thread items when turn list reader is unavailable', () async {
    final itemListReader = _RecordingThreadItemListReader(
      page: ThreadItemsPage(
        items: [_item('item_recovered', 'Recovered item', turnId: 'turn_1')],
      ),
    );
    final fixture = _Fixture(threadItemListReader: itemListReader);
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, ['thr_selected']);
    expect(fixture.threadDetailReader.includeTurnsValues, [false]);
    expect(itemListReader.calls, [
      (
        threadId: 'thr_selected',
        cursor: null,
        limit: 200,
        sortDirection: 'asc',
      ),
    ]);
    expect(fixture.recoveredItems.single.threadId, 'thr_selected');
    expect(fixture.recoveredItems.single.items.single.id, 'item_recovered');
    expect(fixture.recoveredItems.single.items.single.turnId, 'turn_1');
  });

  test('backfills thread items across bounded pages', () async {
    final itemListReader = _RecordingThreadItemListReader.pages([
      ThreadItemsPage(
        items: [_item('item_1', 'First page', turnId: 'turn_1')],
        nextCursor: 'cursor_2',
      ),
      ThreadItemsPage(
        items: [_item('item_2', 'Second page', turnId: 'turn_2')],
      ),
    ]);
    final fixture = _Fixture(threadItemListReader: itemListReader);
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(itemListReader.calls, [
      (
        threadId: 'thr_selected',
        cursor: null,
        limit: 200,
        sortDirection: 'asc',
      ),
      (
        threadId: 'thr_selected',
        cursor: 'cursor_2',
        limit: 200,
        sortDirection: 'asc',
      ),
    ]);
    expect(fixture.recoveredItems, hasLength(1));
    expect(fixture.recoveredItems.single.items.map((item) => item.id), [
      'item_1',
      'item_2',
    ]);
  });

  test('deduplicates paged item backfill by id', () async {
    final itemListReader = _RecordingThreadItemListReader.pages([
      ThreadItemsPage(
        items: [
          _item('item_1', 'First page', turnId: 'turn_1'),
          _item('item_overlap', 'Newer overlap', turnId: 'turn_1'),
        ],
        nextCursor: 'cursor_2',
      ),
      ThreadItemsPage(
        items: [
          _item('item_overlap', 'Older overlap', turnId: 'turn_1'),
          _item('item_2', 'Second page', turnId: 'turn_2'),
        ],
      ),
    ]);
    final fixture = _Fixture(threadItemListReader: itemListReader);
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    final items = fixture.recoveredItems.single.items;
    expect(items.map((item) => item.id), ['item_1', 'item_overlap', 'item_2']);
    expect(items[1].text, 'Newer overlap');
  });

  test('falls back to full thread read when turns backfill fails', () async {
    final fixture = _Fixture(
      threadTurnListReader: _FailingThreadTurnListReader(),
    );
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, [
      'thr_selected',
      'thr_selected',
    ]);
    expect(fixture.threadDetailReader.includeTurnsValues, [false, true]);
  });

  test('falls back to thread items when turns backfill fails', () async {
    final itemListReader = _RecordingThreadItemListReader(
      page: ThreadItemsPage(
        items: [_item('item_recovered', 'Recovered item', turnId: 'turn_1')],
      ),
    );
    final fixture = _Fixture(
      threadTurnListReader: _FailingThreadTurnListReader(),
      threadItemListReader: itemListReader,
    );
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, ['thr_selected']);
    expect(fixture.threadDetailReader.includeTurnsValues, [false]);
    expect(itemListReader.calls.single.threadId, 'thr_selected');
    expect(fixture.recoveredItems.single.items.single.text, 'Recovered item');
  });

  test('rereads the active turn thread before the selected thread', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();
    fixture.turnController.trackStartedTurn(
      threadId: 'thr_active',
      turn: const TurnSummary(
        id: 'turn_1',
        status: 'running',
        itemCount: 0,
        itemsView: 'notLoaded',
      ),
    );

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, ['thr_active']);
  });
}

class _Fixture {
  _Fixture({
    ThreadTurnListReader? threadTurnListReader,
    ThreadItemListReader? threadItemListReader,
  }) : threadListReader = _RecordingThreadListReader(),
       threadDetailReader = _RecordingThreadDetailReader() {
    threadListController = ThreadListController(
      readerProvider: () => threadListReader,
    );
    threadDetailController = ThreadDetailController(
      readerProvider: () => threadDetailReader,
    );
    turnController = TurnController(runnerProvider: () => null);
    coordinator = AppSessionRecoveryCoordinator(
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      threadTurnListReaderProvider: threadTurnListReader == null
          ? null
          : () => threadTurnListReader,
      threadItemListReaderProvider: threadItemListReader == null
          ? null
          : () => threadItemListReader,
      threadItemRecoveryHandler: ({required threadId, required items}) {
        recoveredItems.add((threadId: threadId, items: items));
      },
    );
  }

  final _RecordingThreadListReader threadListReader;
  final _RecordingThreadDetailReader threadDetailReader;
  late final ThreadListController threadListController;
  late final ThreadDetailController threadDetailController;
  late final TurnController turnController;
  late final AppSessionRecoveryCoordinator coordinator;
  final recoveredItems = <({String threadId, List<ThreadItemSummary> items})>[];

  void dispose() {
    threadListController.dispose();
    threadDetailController.dispose();
    turnController.dispose();
  }
}

class _RecordingThreadListReader implements ThreadListReader {
  final limits = <int>[];

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    limits.add(limit);
    return ThreadListPage(threads: [_thread('thr_selected')]);
  }
}

class _RecordingThreadDetailReader implements ThreadDetailReader {
  final threadIds = <String>[];
  final includeTurnsValues = <bool>[];

  void clear() {
    threadIds.clear();
    includeTurnsValues.clear();
  }

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    includeTurnsValues.add(includeTurns);
    return ThreadDetail(thread: _thread(threadId));
  }
}

class _RecordingThreadTurnListReader implements ThreadTurnListReader {
  _RecordingThreadTurnListReader({required ThreadTurnsPage page})
    : pages = [page];

  _RecordingThreadTurnListReader.pages(this.pages);

  final List<ThreadTurnsPage> pages;
  final calls =
      <
        ({
          String threadId,
          String? cursor,
          int? limit,
          String? sortDirection,
          String? itemsView,
        })
      >[];

  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    calls.add((
      threadId: threadId,
      cursor: cursor,
      limit: limit,
      sortDirection: sortDirection,
      itemsView: itemsView,
    ));
    final pageIndex = calls.length - 1;
    if (pageIndex >= pages.length) {
      return const ThreadTurnsPage(turns: []);
    }
    return pages[pageIndex];
  }
}

class _FailingThreadTurnListReader implements ThreadTurnListReader {
  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    throw StateError('turns list failed');
  }
}

class _RecordingThreadItemListReader implements ThreadItemListReader {
  _RecordingThreadItemListReader({required ThreadItemsPage page})
    : pages = [page];

  _RecordingThreadItemListReader.pages(this.pages);

  final List<ThreadItemsPage> pages;
  final calls =
      <
        ({String threadId, String? cursor, int? limit, String? sortDirection})
      >[];

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    calls.add((
      threadId: threadId,
      cursor: cursor,
      limit: limit,
      sortDirection: sortDirection,
    ));
    final pageIndex = calls.length - 1;
    if (pageIndex >= pages.length) {
      return const ThreadItemsPage(items: []);
    }
    return pages[pageIndex];
  }
}

ThreadSummary _thread(String id) {
  return ThreadSummary.fromJson({
    'id': id,
    'sessionId': 'sess_1',
    'preview': id,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });
}

ThreadItemSummary _item(String id, String text, {String? turnId}) {
  final json = <String, Object?>{
    'id': id,
    'type': 'agentMessage',
    'text': text,
  };
  if (turnId != null) {
    json['turnId'] = turnId;
  }
  return ThreadItemSummary.fromJson(json);
}

TurnSummary _turn(String id, String status, String text) {
  return TurnSummary.fromJson({
    'id': id,
    'status': status,
    'itemsView': 'full',
    'items': [
      {'id': '${id}_item', 'type': 'agentMessage', 'text': text},
    ],
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
