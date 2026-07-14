abstract interface class MarketplaceMutationRunner {
  Future<MarketplaceAddResult> addMarketplace({
    required String source,
    String? refName,
    List<String> sparsePaths = const [],
  });

  Future<MarketplaceRemoveResult> removeMarketplace({
    required String marketplaceName,
  });

  Future<MarketplaceUpgradeResult> upgradeMarketplaces({
    String? marketplaceName,
  });
}

class MarketplaceAddResult {
  const MarketplaceAddResult({
    required this.marketplaceName,
    required this.installedRoot,
    required this.alreadyAdded,
    required this.raw,
  });

  factory MarketplaceAddResult.fromJson(Map<String, Object?> json) {
    return MarketplaceAddResult(
      marketplaceName: _requiredString(
        json['marketplaceName'] ?? json['marketplace_name'],
        'marketplaceName',
      ),
      installedRoot: _requiredString(
        json['installedRoot'] ?? json['installed_root'],
        'installedRoot',
      ),
      alreadyAdded:
          _boolValue(json['alreadyAdded'] ?? json['already_added']) ?? false,
      raw: Map.unmodifiable(json),
    );
  }

  final String marketplaceName;
  final String installedRoot;
  final bool alreadyAdded;
  final Map<String, Object?> raw;
}

class MarketplaceRemoveResult {
  const MarketplaceRemoveResult({
    required this.marketplaceName,
    required this.raw,
    this.installedRoot,
  });

  factory MarketplaceRemoveResult.fromJson(Map<String, Object?> json) {
    return MarketplaceRemoveResult(
      marketplaceName: _requiredString(
        json['marketplaceName'] ?? json['marketplace_name'],
        'marketplaceName',
      ),
      installedRoot: _stringValue(
        json['installedRoot'] ?? json['installed_root'],
      ),
      raw: Map.unmodifiable(json),
    );
  }

  final String marketplaceName;
  final String? installedRoot;
  final Map<String, Object?> raw;
}

class MarketplaceUpgradeResult {
  const MarketplaceUpgradeResult({
    required this.selectedMarketplaces,
    required this.upgradedRoots,
    required this.errors,
    required this.raw,
  });

  factory MarketplaceUpgradeResult.fromJson(Map<String, Object?> json) {
    return MarketplaceUpgradeResult(
      selectedMarketplaces: List.unmodifiable(
        _stringList(
          json['selectedMarketplaces'] ?? json['selected_marketplaces'],
        ),
      ),
      upgradedRoots: List.unmodifiable(
        _stringList(json['upgradedRoots'] ?? json['upgraded_roots']),
      ),
      errors: List.unmodifiable(
        _list(json['errors']).map(MarketplaceUpgradeError.fromJson).nonNulls,
      ),
      raw: Map.unmodifiable(json),
    );
  }

  final List<String> selectedMarketplaces;
  final List<String> upgradedRoots;
  final List<MarketplaceUpgradeError> errors;
  final Map<String, Object?> raw;
}

class MarketplaceUpgradeError {
  const MarketplaceUpgradeError({
    required this.marketplaceName,
    required this.message,
  });

  static MarketplaceUpgradeError? fromJson(Object? value) {
    final json = _objectMap(value);
    final marketplaceName = _stringValue(
      json['marketplaceName'] ?? json['marketplace_name'],
    );
    final message = _stringValue(json['message']);
    if (marketplaceName == null || message == null) {
      return null;
    }
    return MarketplaceUpgradeError(
      marketplaceName: marketplaceName,
      message: message,
    );
  }

  final String marketplaceName;
  final String message;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _stringList(Object? value) {
  return _list(value).map(_stringValue).nonNulls.toList(growable: false);
}

String _requiredString(Object? value, String field) {
  final normalized = _stringValue(value);
  if (normalized == null) {
    throw FormatException('marketplace response is missing $field');
  }
  return normalized;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;
