import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import 'chat_advanced_controls_sheet.dart';

typedef ChatAdvancedThreadIdProvider = String? Function();
typedef ChatAdvancedVisibleThreadsRefresher = void Function({int limit});

class ChatAdvancedControlsHandler {
  const ChatAdvancedControlsHandler({
    required this.context,
    required this.sessionController,
    required this.configOverrideController,
    required this.threadDetailController,
    required this.currentThreadIdProvider,
    required this.refreshVisibleThreads,
  });

  final BuildContext context;
  final CodexSessionStateController? sessionController;
  final CodexConfigOverrideController? configOverrideController;
  final ThreadDetailController? threadDetailController;
  final ChatAdvancedThreadIdProvider currentThreadIdProvider;
  final ChatAdvancedVisibleThreadsRefresher refreshVisibleThreads;

  Future<void> showSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ChatAdvancedControlsSheet(
        configOverrideController: configOverrideController,
        rawRpcSender: sessionController?.requestRaw,
        onApplySessionOverrides: _applySessionOverrides,
      ),
    );
  }

  Future<void> _applySessionOverrides(CodexConfigOverrides overrides) async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = currentThreadIdProvider();
    if (runner == null || threadId == null) {
      return;
    }
    await runner.updateThreadSettings(threadId: threadId, overrides: overrides);
    refreshVisibleThreads();
    if (threadDetailController?.selectedThreadId == threadId) {
      unawaited(
        threadDetailController?.readThread(threadId, includeTurns: false),
      );
    }
  }
}
