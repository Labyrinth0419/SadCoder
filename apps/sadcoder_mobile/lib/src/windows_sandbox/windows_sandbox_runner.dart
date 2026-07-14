enum WindowsSandboxSetupMode {
  elevated('elevated'),
  unelevated('unelevated');

  const WindowsSandboxSetupMode(this.wireName);

  final String wireName;

  static WindowsSandboxSetupMode? fromWire(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'elevated' => elevated,
      'unelevated' => unelevated,
      _ => null,
    };
  }
}

enum WindowsSandboxReadiness {
  ready('ready'),
  notConfigured('notConfigured'),
  updateRequired('updateRequired'),
  unknown('unknown');

  const WindowsSandboxReadiness(this.wireName);

  final String wireName;

  static WindowsSandboxReadiness fromWire(Object? value) {
    return switch (value?.toString().trim()) {
      'ready' => ready,
      'notConfigured' => notConfigured,
      'updateRequired' => updateRequired,
      _ => unknown,
    };
  }
}

class WindowsSandboxSetupStart {
  const WindowsSandboxSetupStart({required this.started});

  factory WindowsSandboxSetupStart.fromJson(Map<String, Object?> json) {
    return WindowsSandboxSetupStart(started: json['started'] == true);
  }

  final bool started;
}

abstract interface class WindowsSandboxRunner {
  Future<WindowsSandboxReadiness> readReadiness();

  Future<WindowsSandboxSetupStart> startSetup({
    required WindowsSandboxSetupMode mode,
    String? cwd,
  });
}
