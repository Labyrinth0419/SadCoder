import 'thread_review.dart';

class ThreadReviewCommand {
  const ThreadReviewCommand({required this.target, this.delivery});

  final ThreadReviewTarget target;
  final ThreadReviewDelivery? delivery;
}

ThreadReviewCommand? parseThreadReviewCommand(String arguments) {
  var rest = arguments.trim();
  ThreadReviewDelivery? delivery;

  final deliveryHead = _splitHead(rest);
  final normalizedDelivery = deliveryHead.head.toLowerCase();
  if (normalizedDelivery == 'detached' || normalizedDelivery == '--detached') {
    delivery = ThreadReviewDelivery.detached;
    rest = deliveryHead.tail;
  } else if (normalizedDelivery == 'inline' ||
      normalizedDelivery == '--inline') {
    delivery = ThreadReviewDelivery.inline;
    rest = deliveryHead.tail;
  }

  if (rest.isEmpty) {
    return ThreadReviewCommand(
      target: const ThreadReviewTarget.uncommittedChanges(),
      delivery: delivery,
    );
  }

  final split = _splitHead(rest);
  final head = split.head.toLowerCase();
  final tail = split.tail;
  final target = switch (head) {
    'changes' || 'uncommitted' || 'uncommittedchanges' =>
      tail.isEmpty ? const ThreadReviewTarget.uncommittedChanges() : null,
    'base' || 'branch' || 'basebranch' => _parseBaseBranchTarget(tail),
    'commit' => _parseCommitTarget(tail),
    'custom' => tail.isEmpty ? null : ThreadReviewTarget.custom(tail),
    _ => head.startsWith('--') ? null : ThreadReviewTarget.custom(rest),
  };
  if (target == null) {
    return null;
  }
  return ThreadReviewCommand(target: target, delivery: delivery);
}

ThreadReviewTarget? _parseBaseBranchTarget(String tail) {
  if (tail.isEmpty || tail.contains(RegExp(r'\s'))) {
    return null;
  }
  return ThreadReviewTarget.baseBranch(tail);
}

ThreadReviewTarget? _parseCommitTarget(String tail) {
  if (tail.isEmpty) {
    return null;
  }
  final split = _splitHead(tail);
  if (split.head.isEmpty) {
    return null;
  }
  return ThreadReviewTarget.commit(
    split.head,
    title: split.tail.isEmpty ? null : split.tail,
  );
}

({String head, String tail}) _splitHead(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return (head: '', tail: '');
  }
  final firstSpace = trimmed.indexOf(RegExp(r'\s'));
  if (firstSpace == -1) {
    return (head: trimmed, tail: '');
  }
  return (
    head: trimmed.substring(0, firstSpace),
    tail: trimmed.substring(firstSpace + 1).trim(),
  );
}
