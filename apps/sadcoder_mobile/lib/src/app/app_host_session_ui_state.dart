import '../config/codex_config_override_controller.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_list_controller.dart';
import '../turns/turn_controller.dart';
import 'app_session_recovery_coordinator.dart';

class AppHostSessionUiState {
  AppHostSessionUiState({
    required this.sessionController,
    required CodexConfigOverrideController configOverrideController,
  }) {
    threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    threadDetailController = ThreadDetailController(
      readerProvider: () => sessionController.threadDetailReader,
    );
    turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      activeThreadIdProvider: () => threadDetailController.selectedThreadId,
      overrideLayersProvider: () => configOverrideController.layers,
    );
    timelineController = ChatTimelineController(
      onTurnCompleted: ({required threadId, required turn}) {
        turnController.finishTurn(threadId: threadId, turn: turn);
      },
    );
    _sessionRecoveryCoordinator = AppSessionRecoveryCoordinator(
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      threadTurnListReaderProvider: () =>
          sessionController.threadTurnListReader,
    );
    threadDetailController.addListener(_handleThreadDetailChanged);
  }

  final CodexSessionStateController sessionController;
  late final ThreadListController threadListController;
  late final ThreadDetailController threadDetailController;
  late final TurnController turnController;
  late final ChatTimelineController timelineController;
  late final AppSessionRecoveryCoordinator _sessionRecoveryCoordinator;

  void attachEvents() {
    timelineController.attach(sessionController.events);
  }

  void detachEvents() {
    timelineController.attach(null);
  }

  void handleSessionStatus(CodexSessionStatus status) {
    _sessionRecoveryCoordinator.handleSessionStatus(status);
  }

  void dispose() {
    detachEvents();
    threadDetailController.removeListener(_handleThreadDetailChanged);
    timelineController.dispose();
    turnController.dispose();
    threadDetailController.dispose();
    threadListController.dispose();
  }

  void _handleThreadDetailChanged() {
    switch (threadDetailController.status) {
      case ThreadDetailStatus.loading:
        timelineController.selectThread(
          threadDetailController.selectedThreadId,
        );
      case ThreadDetailStatus.loaded:
        final detail = threadDetailController.detail;
        if (detail != null) {
          timelineController.showThread(detail.thread);
        }
      case ThreadDetailStatus.idle:
        timelineController.clear();
      case ThreadDetailStatus.failed:
        break;
    }
  }
}
