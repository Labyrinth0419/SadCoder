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

  test('ModelListPage treats missing model arrays as empty', () {
    expect(ModelListPage.fromJson({}).models, isEmpty);
    expect(ModelListPage.fromJson({'models': 'gpt-5'}).models, isEmpty);
  });
}
