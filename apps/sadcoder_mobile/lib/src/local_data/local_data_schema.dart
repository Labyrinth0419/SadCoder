enum LocalDataAuthority { localOnly, remoteCodexAuthoritative }

enum LocalDataRetention { durable, reconnectCache, diagnostic }

enum LocalDataContentPolicy { metadataOnly, mayContainProjectContent }

enum LocalDataColumnPrivacy {
  publicMetadata,
  credentialReference,
  localSettingsPayload,
  remoteStatePayload,
  projectContentPayload,
  redactedDiagnosticPayload,
}

class LocalDataColumn {
  const LocalDataColumn({
    required this.name,
    required this.type,
    this.nullable = false,
    this.primaryKey = false,
    this.defaultValue,
    this.privacy = LocalDataColumnPrivacy.publicMetadata,
  });

  final String name;
  final String type;
  final bool nullable;
  final bool primaryKey;
  final String? defaultValue;
  final LocalDataColumnPrivacy privacy;

  String get sql {
    final parts = <String>[name, type];
    if (primaryKey) {
      parts.add('PRIMARY KEY');
    }
    if (!nullable && !primaryKey) {
      parts.add('NOT NULL');
    }
    if (defaultValue != null) {
      parts.add('DEFAULT $defaultValue');
    }
    return parts.join(' ');
  }
}

class LocalDataIndex {
  const LocalDataIndex({
    required this.name,
    required this.tableName,
    required this.columns,
    this.unique = false,
  });

  final String name;
  final String tableName;
  final List<String> columns;
  final bool unique;

  String get sql {
    final uniqueClause = unique ? 'UNIQUE ' : '';
    return 'CREATE ${uniqueClause}INDEX IF NOT EXISTS $name '
        'ON $tableName (${columns.join(', ')});';
  }
}

class LocalDataTableDefinition {
  const LocalDataTableDefinition({
    required this.name,
    required this.authority,
    required this.retention,
    required this.contentPolicy,
    required this.columns,
    this.indexes = const [],
    this.requiresExportRedaction = false,
    this.notes = '',
  });

  final String name;
  final LocalDataAuthority authority;
  final LocalDataRetention retention;
  final LocalDataContentPolicy contentPolicy;
  final List<LocalDataColumn> columns;
  final List<LocalDataIndex> indexes;
  final bool requiresExportRedaction;
  final String notes;

  String get createStatement {
    final columnSql = columns.map((column) => '  ${column.sql}').join(',\n');
    return 'CREATE TABLE IF NOT EXISTS $name (\n$columnSql\n);';
  }
}

class LocalDataSchema {
  const LocalDataSchema._();

  static const version = 1;

  static const tables = <LocalDataTableDefinition>[
    LocalDataTableDefinition(
      name: 'ssh_profiles',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.durable,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'name', type: 'TEXT'),
        LocalDataColumn(name: 'host', type: 'TEXT'),
        LocalDataColumn(name: 'port', type: 'INTEGER'),
        LocalDataColumn(name: 'username', type: 'TEXT'),
        LocalDataColumn(name: 'auth_type', type: 'TEXT'),
        LocalDataColumn(
          name: 'credential_ref',
          type: 'TEXT',
          nullable: true,
          privacy: LocalDataColumnPrivacy.credentialReference,
        ),
        LocalDataColumn(name: 'default_cwd', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'agent_command', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'updated_at_ms', type: 'INTEGER'),
      ],
      notes:
          'Credential material stays in secure storage; this table keeps '
          'only profile metadata and credential references.',
    ),
    LocalDataTableDefinition(
      name: 'known_hosts',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.durable,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'host', type: 'TEXT'),
        LocalDataColumn(name: 'port', type: 'INTEGER'),
        LocalDataColumn(name: 'key_type', type: 'TEXT'),
        LocalDataColumn(name: 'public_key', type: 'TEXT'),
        LocalDataColumn(name: 'fingerprint_sha256', type: 'TEXT'),
        LocalDataColumn(name: 'verified_at_ms', type: 'INTEGER'),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_known_hosts_endpoint',
          tableName: 'known_hosts',
          columns: ['host', 'port', 'key_type'],
          unique: true,
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'connection_history',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.diagnostic,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'profile_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'host', type: 'TEXT'),
        LocalDataColumn(name: 'port', type: 'INTEGER'),
        LocalDataColumn(name: 'started_at_ms', type: 'INTEGER'),
        LocalDataColumn(name: 'ended_at_ms', type: 'INTEGER', nullable: true),
        LocalDataColumn(name: 'status', type: 'TEXT'),
        LocalDataColumn(name: 'error_summary', type: 'TEXT', nullable: true),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_connection_history_started',
          tableName: 'connection_history',
          columns: ['started_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'thread_cache',
      authority: LocalDataAuthority.remoteCodexAuthoritative,
      retention: LocalDataRetention.reconnectCache,
      contentPolicy: LocalDataContentPolicy.mayContainProjectContent,
      columns: [
        LocalDataColumn(name: 'thread_id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'session_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'profile_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'cwd', type: 'TEXT', nullable: true),
        LocalDataColumn(
          name: 'preview',
          type: 'TEXT',
          nullable: true,
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
        LocalDataColumn(name: 'status', type: 'TEXT'),
        LocalDataColumn(name: 'updated_at_ms', type: 'INTEGER'),
        LocalDataColumn(name: 'cached_at_ms', type: 'INTEGER'),
        LocalDataColumn(
          name: 'raw_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_thread_cache_updated',
          tableName: 'thread_cache',
          columns: ['updated_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'item_cache',
      authority: LocalDataAuthority.remoteCodexAuthoritative,
      retention: LocalDataRetention.reconnectCache,
      contentPolicy: LocalDataContentPolicy.mayContainProjectContent,
      requiresExportRedaction: true,
      columns: [
        LocalDataColumn(name: 'item_id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'thread_id', type: 'TEXT'),
        LocalDataColumn(name: 'turn_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'item_type', type: 'TEXT'),
        LocalDataColumn(name: 'status', type: 'TEXT', nullable: true),
        LocalDataColumn(
          name: 'summary',
          type: 'TEXT',
          nullable: true,
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
        LocalDataColumn(
          name: 'raw_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
        LocalDataColumn(name: 'cached_at_ms', type: 'INTEGER'),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_item_cache_thread',
          tableName: 'item_cache',
          columns: ['thread_id', 'cached_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'pending_approvals',
      authority: LocalDataAuthority.remoteCodexAuthoritative,
      retention: LocalDataRetention.reconnectCache,
      contentPolicy: LocalDataContentPolicy.mayContainProjectContent,
      requiresExportRedaction: true,
      columns: [
        LocalDataColumn(name: 'request_id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'thread_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'kind', type: 'TEXT'),
        LocalDataColumn(
          name: 'title',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
        LocalDataColumn(name: 'requested_at_ms', type: 'INTEGER'),
        LocalDataColumn(
          name: 'raw_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.projectContentPayload,
        ),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_pending_approvals_thread',
          tableName: 'pending_approvals',
          columns: ['thread_id', 'requested_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'app_settings',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.durable,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'key', type: 'TEXT', primaryKey: true),
        LocalDataColumn(
          name: 'value_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.localSettingsPayload,
        ),
        LocalDataColumn(name: 'updated_at_ms', type: 'INTEGER'),
      ],
    ),
    LocalDataTableDefinition(
      name: 'codex_config_snapshots',
      authority: LocalDataAuthority.remoteCodexAuthoritative,
      retention: LocalDataRetention.reconnectCache,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'profile_id', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'cwd', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'captured_at_ms', type: 'INTEGER'),
        LocalDataColumn(
          name: 'raw_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.remoteStatePayload,
        ),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_codex_config_snapshots_captured',
          tableName: 'codex_config_snapshots',
          columns: ['captured_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'codex_override_profiles',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.durable,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'name', type: 'TEXT'),
        LocalDataColumn(name: 'scope', type: 'TEXT'),
        LocalDataColumn(
          name: 'overrides_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.remoteStatePayload,
        ),
        LocalDataColumn(name: 'updated_at_ms', type: 'INTEGER'),
      ],
      notes:
          'Stores only SadCoder explicit override profiles, not server '
          'effective Codex configuration.',
    ),
    LocalDataTableDefinition(
      name: 'slash_command_manifest_cache',
      authority: LocalDataAuthority.remoteCodexAuthoritative,
      retention: LocalDataRetention.reconnectCache,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'profile_id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'cwd', type: 'TEXT', nullable: true),
        LocalDataColumn(
          name: 'manifest_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.remoteStatePayload,
        ),
        LocalDataColumn(name: 'cached_at_ms', type: 'INTEGER'),
      ],
    ),
    LocalDataTableDefinition(
      name: 'slash_command_usage_history',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.diagnostic,
      contentPolicy: LocalDataContentPolicy.metadataOnly,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'command_name', type: 'TEXT'),
        LocalDataColumn(name: 'used_at_ms', type: 'INTEGER'),
        LocalDataColumn(name: 'context', type: 'TEXT', nullable: true),
        LocalDataColumn(
          name: 'arguments_summary',
          type: 'TEXT',
          nullable: true,
        ),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_slash_command_usage_history_command',
          tableName: 'slash_command_usage_history',
          columns: ['command_name', 'used_at_ms'],
        ),
      ],
    ),
    LocalDataTableDefinition(
      name: 'raw_rpc_logs',
      authority: LocalDataAuthority.localOnly,
      retention: LocalDataRetention.diagnostic,
      contentPolicy: LocalDataContentPolicy.mayContainProjectContent,
      requiresExportRedaction: true,
      columns: [
        LocalDataColumn(name: 'id', type: 'TEXT', primaryKey: true),
        LocalDataColumn(name: 'direction', type: 'TEXT'),
        LocalDataColumn(name: 'method', type: 'TEXT', nullable: true),
        LocalDataColumn(name: 'captured_at_ms', type: 'INTEGER'),
        LocalDataColumn(name: 'redaction_version', type: 'INTEGER'),
        LocalDataColumn(
          name: 'redacted_json',
          type: 'TEXT',
          privacy: LocalDataColumnPrivacy.redactedDiagnosticPayload,
        ),
      ],
      indexes: [
        LocalDataIndex(
          name: 'idx_raw_rpc_logs_captured',
          tableName: 'raw_rpc_logs',
          columns: ['captured_at_ms'],
        ),
      ],
    ),
  ];

  static LocalDataTableDefinition table(String name) {
    return tables.singleWhere((table) => table.name == name);
  }

  static List<String> get createStatements {
    return [
      for (final table in tables) table.createStatement,
      for (final table in tables) ...table.indexes.map((index) => index.sql),
    ];
  }
}
