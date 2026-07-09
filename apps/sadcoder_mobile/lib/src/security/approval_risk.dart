import '../approvals/pending_approval.dart';

const largeApprovalDiffBytesThreshold = 16 * 1024;
const largeApprovalDiffLinesThreshold = 300;

bool requiresApprovalSecondConfirmation(
  PendingApproval approval,
  CodexApprovalDecision decision,
) {
  if (decision != CodexApprovalDecision.accept &&
      decision != CodexApprovalDecision.acceptForSession) {
    return false;
  }
  return isHighRiskApproval(approval);
}

bool isHighRiskApproval(PendingApproval approval) {
  return switch (approval.kind) {
    PendingApprovalKind.commandExecution => isHighRiskCommand(
      approval.command ?? _stringValue(approval.rawParams['command']),
    ),
    PendingApprovalKind.fileChange => isLargeFileChangeApproval(approval),
    _ => false,
  };
}

bool isHighRiskCommand(String? command) {
  final normalized = command?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  return _highRiskCommandPatterns.any(
    (pattern) => pattern.hasMatch(normalized),
  );
}

bool isLargeFileChangeApproval(PendingApproval approval) {
  if (approval.kind != PendingApprovalKind.fileChange) {
    return false;
  }
  final rawParams = approval.rawParams;
  return _hasLargeTextSignal(rawParams) ||
      _maxNumericSignal(rawParams, _byteSignalKeys) >=
          largeApprovalDiffBytesThreshold ||
      _sumNumericSignal(rawParams, _lineSignalKeys) >=
          largeApprovalDiffLinesThreshold;
}

final _highRiskCommandPatterns = [
  RegExp(r'\brm\s+-[^\n;|&]*r[^\n;|&]*f\b'),
  RegExp(r'\brm\s+-[^\n;|&]*f[^\n;|&]*r\b'),
  RegExp(r'\bgit\s+reset\s+--hard\b'),
  RegExp(r'\bgit\s+clean\s+[^\n;|&]*-[a-z]*f\b'),
  RegExp(r'\bremove-item\b[^\n;|&]*\b-recurse\b'),
  RegExp(r'\bdel\s+/[a-z]*[sq][a-z]*\b'),
  RegExp(r'\b(?:format|diskpart|mkfs|shutdown|reboot)\b'),
  RegExp(r'\bchmod\s+(?:-r\s+)?777\b'),
  RegExp(r'\bchown\s+-r\b'),
  RegExp(r'\bsudo\s+rm\b'),
];

const _byteSignalKeys = {
  'bytes',
  'sizebytes',
  'diffbytes',
  'patchbytes',
  'changedbytes',
  'bytelength',
};

const _lineSignalKeys = {
  'linecount',
  'changedlines',
  'lineschanged',
  'additions',
  'deletions',
  'linesadded',
  'linesdeleted',
};

bool _hasLargeTextSignal(Object? value) {
  if (value is String) {
    return value.length >= largeApprovalDiffBytesThreshold ||
        '\n'.allMatches(value).length >= largeApprovalDiffLinesThreshold;
  }
  if (value is Map) {
    return value.values.any(_hasLargeTextSignal);
  }
  if (value is Iterable) {
    return value.any(_hasLargeTextSignal);
  }
  return false;
}

int _maxNumericSignal(Object? value, Set<String> keys) {
  var maxValue = 0;
  void visit(Object? node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = _riskKey(entry.key);
        final numeric = _intValue(entry.value);
        if (keys.contains(key) && numeric != null && numeric > maxValue) {
          maxValue = numeric;
        }
        visit(entry.value);
      }
    } else if (node is Iterable) {
      for (final item in node) {
        visit(item);
      }
    }
  }

  visit(value);
  return maxValue;
}

int _sumNumericSignal(Object? value, Set<String> keys) {
  var sum = 0;
  void visit(Object? node) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = _riskKey(entry.key);
        final numeric = _intValue(entry.value);
        if (keys.contains(key) && numeric != null) {
          sum += numeric;
        }
        visit(entry.value);
      }
    } else if (node is Iterable) {
      for (final item in node) {
        visit(item);
      }
    }
  }

  visit(value);
  return sum;
}

String _riskKey(Object? value) {
  return value.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
