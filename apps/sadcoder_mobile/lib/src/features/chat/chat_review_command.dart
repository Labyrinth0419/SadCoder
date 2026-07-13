import 'dart:async';

import '../../i18n/app_localizations.dart';
import '../../reviews/thread_review_command.dart';
import '../../reviews/thread_review_runner.dart';
import '../../threads/thread_detail_controller.dart';
import '../../turns/turn_controller.dart';
import 'chat_review_summary.dart';
import 'chat_timeline_controller.dart';

Future<String?> startThreadReviewFromCommand({
  required AppLocalizations l10n,
  required ThreadReviewRunner? runner,
  required TurnController? turnController,
  required ChatTimelineController? timelineController,
  required ThreadDetailController? threadDetailController,
  required void Function() refreshVisibleThreads,
  required String? threadId,
  required String arguments,
}) async {
  if (runner == null || turnController == null || threadId == null) {
    return null;
  }
  if (!turnController.canSubmit) {
    return null;
  }

  final command = parseThreadReviewCommand(arguments);
  if (command == null) {
    return null;
  }

  final result = await runner.startReview(
    threadId: threadId,
    target: command.target,
    delivery: command.delivery,
  );
  final reviewThreadId = result.reviewThreadId;
  final tracked = turnController.trackStartedTurn(
    threadId: reviewThreadId,
    turn: result.turn,
  );
  if (!tracked) {
    return null;
  }

  timelineController?.showTurn(threadId: reviewThreadId, turn: result.turn);
  refreshVisibleThreads();
  unawaited(
    threadDetailController?.readThread(reviewThreadId, includeTurns: false),
  );
  return buildThreadReviewStartedSummary(
    l10n: l10n,
    result: result,
    target: command.target,
    delivery: command.delivery,
  );
}
