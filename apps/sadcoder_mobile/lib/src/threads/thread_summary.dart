class ThreadListPage {
  const ThreadListPage({
    required this.threads,
    this.nextCursor,
    this.backwardsCursor,
  });

  factory ThreadListPage.fromJson(Map<String, Object?> json) {
    return ThreadListPage(
      threads: _listOfMaps(
        json['data'],
      ).map(ThreadSummary.fromJson).toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      backwardsCursor: json['backwardsCursor'] as String?,
    );
  }

  final List<ThreadSummary> threads;
  final String? nextCursor;
  final String? backwardsCursor;
}

class ThreadDetail {
  const ThreadDetail({required this.thread});

  factory ThreadDetail.fromJson(Map<String, Object?> json) {
    final thread = _stringKeyedMap(json['thread']);
    return ThreadDetail(thread: ThreadSummary.fromJson(thread));
  }

  final ThreadSummary thread;

  List<TurnSummary> get turns => thread.turns;
}

class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.sessionId,
    required this.preview,
    required this.ephemeral,
    required this.status,
    required this.cwd,
    required this.updatedAtSeconds,
    this.name,
    this.parentThreadId,
    this.forkedFromId,
    this.agentNickname,
    this.agentRole,
    this.turns = const [],
    this.raw = const {},
  });

  factory ThreadSummary.fromJson(Map<String, Object?> json) {
    return ThreadSummary(
      id: _stringValue(json['id']) ?? '',
      sessionId: _stringValue(json['sessionId']) ?? '',
      preview: _stringValue(json['preview']) ?? '',
      ephemeral: _boolValue(json['ephemeral']) ?? false,
      status: _stringValue(json['status']) ?? 'unknown',
      cwd: _stringValue(json['cwd']) ?? '',
      updatedAtSeconds: _intValue(json['updatedAt']) ?? 0,
      name: _stringValue(json['name']),
      parentThreadId: _stringValue(json['parentThreadId']),
      forkedFromId: _stringValue(json['forkedFromId']),
      agentNickname: _stringValue(json['agentNickname']),
      agentRole: _stringValue(json['agentRole']),
      turns: _listOfMaps(
        json['turns'],
      ).map(TurnSummary.fromJson).toList(growable: false),
      raw: Map.unmodifiable(json),
    );
  }

  factory ThreadSummary.fromThreadResponse(Map<String, Object?> json) {
    return ThreadSummary.fromJson(_stringKeyedMap(json['thread']));
  }

  final String id;
  final String sessionId;
  final String preview;
  final bool ephemeral;
  final String status;
  final String cwd;
  final int updatedAtSeconds;
  final String? name;
  final String? parentThreadId;
  final String? forkedFromId;
  final String? agentNickname;
  final String? agentRole;
  final List<TurnSummary> turns;
  final Map<String, Object?> raw;

  String get title {
    final name = this.name;
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    if (preview.trim().isNotEmpty) {
      return preview;
    }
    return id;
  }

  bool get isSubagent => parentThreadId != null;
  bool get isFork => forkedFromId != null;
}

class TurnSummary {
  const TurnSummary({
    required this.id,
    required this.status,
    required this.itemCount,
    required this.itemsView,
    this.items = const [],
    this.startedAtSeconds,
    this.completedAtSeconds,
    this.durationMs,
    this.errorMessage,
    this.raw = const {},
  });

  factory TurnSummary.fromJson(Map<String, Object?> json) {
    final items = _listOfMaps(
      json['items'],
    ).map(ThreadItemSummary.fromJson).toList(growable: false);
    return TurnSummary(
      id: _stringValue(json['id']) ?? '',
      status: _stringValue(json['status']) ?? 'unknown',
      itemCount: items.length,
      itemsView: _stringValue(json['itemsView']) ?? 'notLoaded',
      items: items,
      startedAtSeconds: _intValue(json['startedAt']),
      completedAtSeconds: _intValue(json['completedAt']),
      durationMs: _intValue(json['durationMs']),
      errorMessage: _stringValue(_stringKeyedMap(json['error'])['message']),
      raw: Map.unmodifiable(json),
    );
  }

  factory TurnSummary.fromTurnResponse(Map<String, Object?> json) {
    return TurnSummary.fromJson(_stringKeyedMap(json['turn']));
  }

  final String id;
  final String status;
  final int itemCount;
  final String itemsView;
  final List<ThreadItemSummary> items;
  final int? startedAtSeconds;
  final int? completedAtSeconds;
  final int? durationMs;
  final String? errorMessage;
  final Map<String, Object?> raw;
}

class ThreadItemSummary {
  const ThreadItemSummary({
    required this.id,
    required this.type,
    required this.text,
    required this.output,
    this.raw = const {},
  });

  factory ThreadItemSummary.fromJson(Map<String, Object?> json) {
    final type = _stringValue(json['type']) ?? 'unknown';
    return ThreadItemSummary(
      id: _stringValue(json['id']) ?? '',
      type: type,
      text: _itemText(type, json),
      output: _stringValue(json['aggregatedOutput']) ?? '',
      raw: Map.unmodifiable(json),
    );
  }

  final String id;
  final String type;
  final String text;
  final String output;
  final Map<String, Object?> raw;
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return const {};
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, Object?>.from(entry))
      .toList(growable: false);
}

String? _stringValue(Object? value) => value is String ? value : null;

bool? _boolValue(Object? value) => value is bool ? value : null;

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

String _itemText(String type, Map<String, Object?> json) {
  return switch (type) {
    'userMessage' => _userMessageText(json['content']),
    'agentMessage' || 'plan' => _stringValue(json['text']) ?? '',
    'reasoning' => [
      ..._listOfStrings(json['summary']),
      ..._listOfStrings(json['content']),
    ].join('\n'),
    'mcpToolCall' => [
      _stringValue(json['server']),
      _stringValue(json['tool']),
    ].whereType<String>().where((value) => value.isNotEmpty).join('/'),
    'dynamicToolCall' => _stringValue(json['tool']) ?? '',
    'webSearch' => _stringValue(json['query']) ?? '',
    'imageView' => _stringValue(json['path']) ?? '',
    _ => _stringValue(json['text']) ?? '',
  };
}

String _userMessageText(Object? content) {
  return _listOfMaps(content)
      .map((entry) {
        return switch (_stringValue(entry['type'])) {
          'text' => _stringValue(entry['text']) ?? '',
          'image' => _bracketed('image', _stringValue(entry['url'])),
          'localImage' => _bracketed('image', _stringValue(entry['path'])),
          'skill' => _bracketed('skill', _stringValue(entry['name'])),
          'mention' => _bracketed('mention', _stringValue(entry['name'])),
          _ => '',
        };
      })
      .where((value) => value.isNotEmpty)
      .join('\n');
}

String _bracketed(String label, String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  return '[$label: $value]';
}

List<String> _listOfStrings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}
