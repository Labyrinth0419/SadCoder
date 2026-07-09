import '../../i18n/app_localizations.dart';
import '../../reviews/thread_review.dart';

String buildThreadReviewStartedSummary({
  required AppLocalizations l10n,
  required ThreadReviewStartResult result,
  required ThreadReviewTarget target,
  ThreadReviewDelivery? delivery,
}) {
  final lines = <String>[
    l10n.threadReviewStarted,
    '${l10n.threadReviewTarget}: ${_targetLabel(l10n, target)}',
    '${l10n.threadReviewDelivery}: ${_deliveryLabel(l10n, delivery)}',
    '${l10n.threadReviewThread}: ${result.reviewThreadId}',
    '${l10n.threadReviewTurn}: ${result.turn.id}',
  ];
  return lines.join('\n');
}

String _targetLabel(AppLocalizations l10n, ThreadReviewTarget target) {
  return switch (target.kind) {
    ThreadReviewTargetKind.uncommittedChanges =>
      l10n.threadReviewTargetUncommitted,
    ThreadReviewTargetKind.baseBranch =>
      '${l10n.threadReviewTargetBaseBranch}: ${target.branch}',
    ThreadReviewTargetKind.commit =>
      target.title == null || target.title!.isEmpty
          ? '${l10n.threadReviewTargetCommit}: ${target.sha}'
          : '${l10n.threadReviewTargetCommit}: ${target.sha} ${target.title}',
    ThreadReviewTargetKind.custom =>
      '${l10n.threadReviewTargetCustom}: ${target.instructions}',
  };
}

String _deliveryLabel(AppLocalizations l10n, ThreadReviewDelivery? delivery) {
  return switch (delivery ?? ThreadReviewDelivery.inline) {
    ThreadReviewDelivery.inline => l10n.threadReviewDeliveryInline,
    ThreadReviewDelivery.detached => l10n.threadReviewDeliveryDetached,
  };
}
