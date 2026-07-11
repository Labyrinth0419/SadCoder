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
          'hidden': false,
          'isDefault': true,
          'upgrade': 'gpt-5.6-sol',
          'availabilityNux': {'message': 'GPT-5.6 Sol is available.'},
          'upgradeInfo': {
            'model': 'gpt-5.6-sol',
            'upgradeCopy': 'Use GPT-5.6 Sol for frontier coding.',
            'modelLink': 'https://example.test/models/gpt-5.6-sol',
            'migrationMarkdown': 'Move from {current_model} to {target_model}.',
          },
          'supportedReasoningEfforts': [
            {'reasoningEffort': 'medium', 'description': 'Balanced'},
            {'reasoning_effort': 'high', 'description': 'Deeper reasoning'},
          ],
          'defaultReasoningEffort': 'medium',
          'inputModalities': ['text', 'image', '', 42],
          'supportsPersonality': true,
          'additionalSpeedTiers': ['fast'],
          'serviceTiers': [
            {
              'id': 'default',
              'name': 'Default',
              'description': 'Catalog default tier.',
            },
            {'id': 'priority', 'name': 'Priority'},
          ],
          'defaultServiceTier': 'default',
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
    expect(page.models[0].hidden, isFalse);
    expect(page.models[0].isDefault, isTrue);
    expect(page.models[0].upgrade?.model, 'gpt-5.6-sol');
    expect(
      page.models[0].upgrade?.copy,
      'Use GPT-5.6 Sol for frontier coding.',
    );
    expect(page.models[0].upgrade?.link, contains('gpt-5.6-sol'));
    expect(
      page.models[0].upgrade?.migrationMarkdown,
      'Move from {current_model} to {target_model}.',
    );
    expect(
      page.models[0].availabilityNux?.message,
      'GPT-5.6 Sol is available.',
    );
    expect(
      page.models[0].supportedReasoningEfforts.map((effort) => effort.id),
      ['medium', 'high'],
    );
    expect(
      page.models[0].supportedReasoningEfforts.last.description,
      'Deeper reasoning',
    );
    expect(page.models[0].defaultReasoningEffort, 'medium');
    expect(page.models[0].inputModalities, ['text', 'image']);
    expect(page.models[0].supportsPersonality, isTrue);
    expect(page.models[0].additionalSpeedTiers, ['fast']);
    expect(page.models[0].serviceTiers.map((tier) => tier.id), [
      'default',
      'priority',
    ]);
    expect(
      page.models[0].serviceTiers.first.description,
      'Catalog default tier.',
    );
    expect(page.models[0].defaultServiceTier, 'default');
    expect(page.models[1].id, 'gpt-5.6-terra');
    expect(page.models[1].label, 'GPT-5.6 Terra');
    expect(page.models[2].id, 'gpt-5.6-luna');
  });

  test(
    'ModelListPage maps deprecated speed tiers when service tiers are absent',
    () {
      final page = ModelListPage.fromJson({
        'data': [
          {
            'model': 'gpt-5.6-fast',
            'displayName': 'GPT-5.6 Fast',
            'additional_speed_tiers': ['priority', '', 'flex'],
          },
        ],
      });

      expect(page.models.single.additionalSpeedTiers, ['priority', 'flex']);
      expect(page.models.single.serviceTiers.map((tier) => tier.id), [
        'priority',
        'flex',
      ]);
      expect(page.models.single.serviceTiers.first.name, 'priority');
    },
  );

  test('ModelListPage parses GPT-5.6 raw model catalog entries', () {
    final page = ModelListPage.fromJson({
      'models': [
        {
          'slug': 'gpt-5.6-sol',
          'display_name': 'GPT-5.6-Sol',
          'description': 'Latest frontier agentic coding model.',
          'default_reasoning_level': 'low',
          'supported_reasoning_levels': [
            {'effort': 'low', 'description': 'Fast responses'},
            {'effort': 'medium', 'description': 'Balanced'},
            {'effort': 'ultra', 'description': 'Automatic task delegation'},
          ],
          'visibility': 'list',
          'availability_nux': {'message': 'Sol is available.'},
          'upgrade': {
            'model': 'gpt-5.6-sol',
            'migration_markdown': 'Use {target_model}.',
          },
          'input_modalities': ['text', 'image'],
          'service_tiers': [
            {
              'id': 'priority',
              'name': 'Fast',
              'description': '1.5x speed, increased usage',
            },
          ],
          'default_service_tier': 'priority',
        },
        {
          'slug': 'gpt-5.6-luna',
          'display_name': 'GPT-5.6-Luna',
          'visibility': 'hide',
        },
      ],
    });

    expect(page.models, hasLength(2));
    expect(page.models[0].id, 'gpt-5.6-sol');
    expect(page.models[0].label, 'GPT-5.6-Sol');
    expect(page.models[0].hidden, isFalse);
    expect(page.models[0].defaultReasoningEffort, 'low');
    expect(
      page.models[0].supportedReasoningEfforts.map((effort) => effort.id),
      ['low', 'medium', 'ultra'],
    );
    expect(
      page.models[0].supportedReasoningEfforts.last.description,
      'Automatic task delegation',
    );
    expect(page.models[0].availabilityNux?.message, 'Sol is available.');
    expect(page.models[0].upgrade?.model, 'gpt-5.6-sol');
    expect(page.models[0].upgrade?.migrationMarkdown, 'Use {target_model}.');
    expect(page.models[0].inputModalities, ['text', 'image']);
    expect(page.models[0].serviceTiers.single.id, 'priority');
    expect(page.models[0].defaultServiceTier, 'priority');
    expect(page.models[1].id, 'gpt-5.6-luna');
    expect(page.models[1].hidden, isTrue);
  });

  test('ModelListPage treats missing model arrays as empty', () {
    expect(ModelListPage.fromJson({}).models, isEmpty);
    expect(ModelListPage.fromJson({'models': 'gpt-5'}).models, isEmpty);
  });
}
