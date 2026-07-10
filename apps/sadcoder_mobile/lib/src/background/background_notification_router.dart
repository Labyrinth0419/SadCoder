import 'dart:async';

class BackgroundNotificationRoute {
  const BackgroundNotificationRoute({
    this.profileId,
    this.endpoint,
    this.threadId,
    this.turnId,
  });

  factory BackgroundNotificationRoute.fromMap(Map<Object?, Object?> map) {
    return BackgroundNotificationRoute(
      profileId: _stringValue(map['profileId']),
      endpoint: _stringValue(map['endpoint']),
      threadId: _stringValue(map['threadId']),
      turnId: _stringValue(map['turnId']),
    );
  }

  final String? profileId;
  final String? endpoint;
  final String? threadId;
  final String? turnId;
}

typedef BackgroundNotificationRouteHandler =
    FutureOr<void> Function(BackgroundNotificationRoute route);

abstract interface class BackgroundNotificationRouter {
  Future<void> attach(BackgroundNotificationRouteHandler handler);

  Future<void> detach();
}

class NoopBackgroundNotificationRouter implements BackgroundNotificationRouter {
  const NoopBackgroundNotificationRouter();

  @override
  Future<void> attach(BackgroundNotificationRouteHandler handler) async {}

  @override
  Future<void> detach() async {}
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
