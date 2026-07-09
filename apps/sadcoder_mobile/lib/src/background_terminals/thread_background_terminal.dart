class ThreadBackgroundTerminalPage {
  const ThreadBackgroundTerminalPage({
    required this.terminals,
    this.nextCursor,
  });

  factory ThreadBackgroundTerminalPage.fromJson(Map<String, Object?> json) {
    final rawTerminals = json['data'];
    return ThreadBackgroundTerminalPage(
      terminals: rawTerminals is List
          ? List.unmodifiable(
              rawTerminals.map(ThreadBackgroundTerminal.fromJson).nonNulls,
            )
          : const [],
      nextCursor: _stringValue(json['nextCursor']),
    );
  }

  final List<ThreadBackgroundTerminal> terminals;
  final String? nextCursor;
}

class ThreadBackgroundTerminal {
  const ThreadBackgroundTerminal({
    required this.itemId,
    required this.processId,
    required this.command,
    required this.cwd,
    required this.raw,
    this.osPid,
    this.cpuPercent,
    this.rssKb,
  });

  static ThreadBackgroundTerminal? fromJson(Object? value) {
    final map = _objectMap(value);
    final itemId = _stringValue(map['itemId']);
    final processId = _stringValue(map['processId']);
    if (itemId == null || processId == null) {
      return null;
    }
    return ThreadBackgroundTerminal(
      itemId: itemId,
      processId: processId,
      command: _stringValue(map['command']) ?? '',
      cwd: _stringValue(map['cwd']) ?? '',
      osPid: _intValue(map['osPid']),
      cpuPercent: _doubleValue(map['cpuPercent']),
      rssKb: _intValue(map['rssKb']),
      raw: map,
    );
  }

  final String itemId;
  final String processId;
  final String command;
  final String cwd;
  final int? osPid;
  final double? cpuPercent;
  final int? rssKb;
  final Map<String, Object?> raw;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
