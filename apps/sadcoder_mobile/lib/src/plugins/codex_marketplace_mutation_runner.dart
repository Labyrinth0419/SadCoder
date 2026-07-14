import '../protocol/codex_app_server_client.dart';
import 'marketplace_mutation_runner.dart';

class CodexMarketplaceMutationRunner implements MarketplaceMutationRunner {
  const CodexMarketplaceMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<MarketplaceAddResult> addMarketplace({
    required String source,
    String? refName,
    List<String> sparsePaths = const [],
  }) async {
    final response = await _client.addMarketplace(
      source: source,
      refName: refName,
      sparsePaths: sparsePaths,
    );
    return MarketplaceAddResult.fromJson(response);
  }

  @override
  Future<MarketplaceRemoveResult> removeMarketplace({
    required String marketplaceName,
  }) async {
    final response = await _client.removeMarketplace(
      marketplaceName: marketplaceName,
    );
    return MarketplaceRemoveResult.fromJson(response);
  }

  @override
  Future<MarketplaceUpgradeResult> upgradeMarketplaces({
    String? marketplaceName,
  }) async {
    final response = await _client.upgradeMarketplaces(
      marketplaceName: marketplaceName,
    );
    return MarketplaceUpgradeResult.fromJson(response);
  }
}
