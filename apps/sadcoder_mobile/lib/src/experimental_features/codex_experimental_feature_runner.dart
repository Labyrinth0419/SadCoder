import '../protocol/codex_app_server_client.dart';
import 'experimental_feature_runner.dart';

class CodexExperimentalFeatureRunner implements ExperimentalFeatureRunner {
  const CodexExperimentalFeatureRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<List<ExperimentalFeature>> listFeatures({String? threadId}) async {
    final features = <String, ExperimentalFeature>{};
    String? cursor;
    final seenCursors = <String>{};
    do {
      final response = await _client.listExperimentalFeatures(
        cursor: cursor,
        limit: 100,
        threadId: threadId,
      );
      final data = response['data'];
      if (data is List) {
        for (final item in data) {
          final feature = ExperimentalFeature.fromJson(item);
          if (feature != null) {
            features[feature.name] = feature;
          }
        }
      }
      final next = _stringValue(
        response['nextCursor'] ?? response['next_cursor'],
      );
      if (next == null || !seenCursors.add(next)) {
        break;
      }
      cursor = next;
    } while (true);
    return List.unmodifiable(features.values);
  }

  @override
  Future<ExperimentalFeatureWriteResult> setFeatureEnabled({
    required String featureName,
    required bool enabled,
    String? expectedVersion,
  }) async {
    final normalized = featureName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        featureName,
        'featureName',
        'featureName must not be blank',
      );
    }
    final response = await _client.batchWriteConfig(
      edits: [
        {
          'keyPath': 'features.$normalized',
          'value': enabled,
          'mergeStrategy': 'upsert',
        },
      ],
      expectedVersion: expectedVersion,
      reloadUserConfig: true,
    );
    return ExperimentalFeatureWriteResult.fromJson(response);
  }
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
