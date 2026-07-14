abstract interface class MemoryRunner {
  Future<void> setThreadMemoryMode({
    required String threadId,
    required ThreadMemoryMode mode,
  });

  Future<void> resetMemory();
}

enum ThreadMemoryMode {
  enabled('enabled'),
  disabled('disabled');

  const ThreadMemoryMode(this.wireName);

  final String wireName;

  static ThreadMemoryMode? fromWire(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'enabled' => enabled,
      'disabled' => disabled,
      _ => null,
    };
  }
}

ThreadMemoryMode? threadMemoryModeFromRaw(Map<String, Object?> raw) {
  final direct = raw['memoryMode'] ?? raw['memory_mode'];
  final directMode = ThreadMemoryMode.fromWire(direct);
  if (directMode != null) {
    return directMode;
  }
  final memory = raw['memory'];
  if (memory is String) {
    return ThreadMemoryMode.fromWire(memory);
  }
  if (memory is Map) {
    return ThreadMemoryMode.fromWire(
      memory['mode'] ?? memory['memoryMode'] ?? memory['memory_mode'],
    );
  }
  return null;
}
