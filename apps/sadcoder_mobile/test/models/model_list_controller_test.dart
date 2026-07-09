import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/models/model_list_controller.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';

void main() {
  test('refresh loads models from the current reader', () async {
    final reader = _FakeModelListReader(
      page: const ModelListPage(models: [CodexModelSummary(id: 'gpt-5-codex')]),
    );
    final controller = ModelListController(readerProvider: () => reader);
    addTearDown(controller.dispose);
    final statuses = <ModelListStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh();

    expect(reader.calls, 1);
    expect(controller.status, ModelListStatus.loaded);
    expect(controller.models.single.id, 'gpt-5-codex');
    expect(statuses, [ModelListStatus.loading, ModelListStatus.loaded]);
  });

  test('refresh without a reader returns to idle and clears models', () async {
    _FakeModelListReader? reader = _FakeModelListReader(
      page: const ModelListPage(models: [CodexModelSummary(id: 'gpt-5-codex')]),
    );
    final controller = ModelListController(readerProvider: () => reader);
    addTearDown(controller.dispose);

    await controller.refresh();
    reader = null;
    await controller.refresh();

    expect(controller.status, ModelListStatus.idle);
    expect(controller.models, isEmpty);
  });

  test('refresh records failures', () async {
    final controller = ModelListController(
      readerProvider: () => _FailingModelListReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, ModelListStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakeModelListReader implements ModelListReader {
  _FakeModelListReader({required this.page});

  final ModelListPage page;
  int calls = 0;

  @override
  Future<ModelListPage> listModels() async {
    calls++;
    return page;
  }
}

class _FailingModelListReader implements ModelListReader {
  @override
  Future<ModelListPage> listModels() {
    throw StateError('model list failed');
  }
}
