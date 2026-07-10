import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';

void main() {
  test('ModelListPage parses string and object model entries', () {
    final page = ModelListPage.fromJson({
      'models': [
        'gpt-5',
        {
          'id': 'gpt-5-codex',
          'displayName': 'GPT-5 Codex',
          'provider': 'openai',
        },
        {'name': 'local-model', 'display_name': 'Local Model'},
        '',
        {'displayName': 'missing id'},
        42,
      ],
    });

    expect(page.models, hasLength(3));
    expect(page.models[0].id, 'gpt-5');
    expect(page.models[0].label, 'gpt-5');
    expect(page.models[1].id, 'gpt-5-codex');
    expect(page.models[1].label, 'GPT-5 Codex (openai)');
    expect(page.models[2].id, 'local-model');
    expect(page.models[2].label, 'Local Model');
  });

  test('ModelListPage parses app-server v2 model data entries', () {
    final page = ModelListPage.fromJson({
      'data': [
        {
          'id': 'gpt-5.6-sol-default',
          'model': 'gpt-5.6-sol',
          'displayName': 'GPT-5.6 Sol',
          'description': 'Latest frontier agentic coding model.',
        },
        {
          'slug': 'gpt-5.6-terra',
          'display_name': 'GPT-5.6 Terra',
          'description': 'Balanced agentic coding model for everyday work.',
        },
        {'slug': 'gpt-5.6-luna', 'display_name': 'GPT-5.6 Luna'},
      ],
      'nextCursor': 'next-page',
    });

    expect(page.models, hasLength(3));
    expect(page.nextCursor, 'next-page');
    expect(page.models[0].id, 'gpt-5.6-sol');
    expect(page.models[0].catalogId, 'gpt-5.6-sol-default');
    expect(page.models[0].label, 'GPT-5.6 Sol');
    expect(page.models[0].description, 'Latest frontier agentic coding model.');
    expect(page.models[1].id, 'gpt-5.6-terra');
    expect(page.models[1].label, 'GPT-5.6 Terra');
    expect(page.models[2].id, 'gpt-5.6-luna');
  });

  test('ModelListPage treats missing model arrays as empty', () {
    expect(ModelListPage.fromJson({}).models, isEmpty);
    expect(ModelListPage.fromJson({'models': 'gpt-5'}).models, isEmpty);
  });
}
