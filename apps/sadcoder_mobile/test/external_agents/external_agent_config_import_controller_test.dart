import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/external_agents/external_agent_config_import_controller.dart';

void main() {
  test('buffers matching progress until the import id is known', () {
    final controller = ExternalAgentConfigImportController();
    addTearDown(controller.dispose);

    controller.ingest(
      _importEvent(
        method: 'externalAgentConfig/import/progress',
        importId: 'import_1',
        successes: [_success('CONFIG', target: '/config.toml')],
      ),
    );
    expect(controller.status, ExternalAgentConfigImportStatus.waiting);
    expect(controller.results, isEmpty);

    controller.track('import_1');

    expect(controller.status, ExternalAgentConfigImportStatus.running);
    expect(controller.successCount, 1);
    expect(controller.results.single.successes.single.target, '/config.toml');
  });

  test('merges progress without duplicates and ignores other imports', () {
    final controller = ExternalAgentConfigImportController();
    addTearDown(controller.dispose);
    controller.track('import_1');
    final progress = _importEvent(
      method: 'externalAgentConfig/import/progress',
      importId: 'import_1',
      successes: [_success('SKILLS', target: '/skills/a')],
      failures: [_failure('SKILLS', message: 'bad skill')],
    );

    controller.ingest(progress);
    controller.ingest(progress);
    controller.ingest(
      _importEvent(
        method: 'externalAgentConfig/import/progress',
        importId: 'import_2',
        successes: [_success('CONFIG', target: '/other')],
      ),
    );

    expect(controller.successCount, 1);
    expect(controller.failureCount, 1);
    expect(controller.results.single.rawType, 'SKILLS');
  });

  test(
    'completed notification replaces progress with authoritative results',
    () {
      final controller = ExternalAgentConfigImportController();
      addTearDown(controller.dispose);
      controller.track('import_1');
      controller.ingest(
        _importEvent(
          method: 'externalAgentConfig/import/progress',
          importId: 'import_1',
          failures: [_failure('CONFIG', message: 'temporary')],
        ),
      );

      controller.ingest(
        _importEvent(
          method: 'externalAgentConfig/import/completed',
          importId: 'import_1',
          successes: [_success('CONFIG', target: '/config.toml')],
        ),
      );

      expect(controller.status, ExternalAgentConfigImportStatus.completed);
      expect(controller.successCount, 1);
      expect(controller.failureCount, 0);

      controller.ingest(
        _importEvent(
          method: 'externalAgentConfig/import/progress',
          importId: 'import_1',
          failures: [_failure('CONFIG', message: 'late progress')],
        ),
      );
      expect(controller.failureCount, 0);
    },
  );

  test('fail records a terminal request failure', () {
    final controller = ExternalAgentConfigImportController();
    addTearDown(controller.dispose);

    controller.fail(StateError('connection failed'));

    expect(controller.status, ExternalAgentConfigImportStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

CodexEvent _importEvent({
  required String method,
  required String importId,
  List<Map<String, Object?>> successes = const [],
  List<Map<String, Object?>> failures = const [],
}) {
  final rawType =
      successes.firstOrNull?['itemType'] ??
      failures.firstOrNull?['itemType'] ??
      'CONFIG';
  return CodexEvent.fromNotification({
    'method': method,
    'params': {
      'importId': importId,
      'itemTypeResults': [
        {'itemType': rawType, 'successes': successes, 'failures': failures},
      ],
    },
  });
}

Map<String, Object?> _success(String type, {String? target}) {
  return {'itemType': type, 'target': ?target};
}

Map<String, Object?> _failure(String type, {required String message}) {
  return {'itemType': type, 'failureStage': 'write', 'message': message};
}
