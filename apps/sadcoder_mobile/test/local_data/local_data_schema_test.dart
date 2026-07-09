import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/local_data/local_data_schema.dart';

void main() {
  test('covers the planned local data tables', () {
    expect(LocalDataSchema.tables.map((table) => table.name).toList(), [
      'ssh_profiles',
      'known_hosts',
      'connection_history',
      'thread_cache',
      'item_cache',
      'pending_approvals',
      'app_settings',
      'codex_config_snapshots',
      'codex_override_profiles',
      'slash_command_manifest_cache',
      'slash_command_usage_history',
      'raw_rpc_logs',
    ]);
  });

  test('remote Codex data is modeled as cache rather than local truth', () {
    const remoteCacheTables = {
      'thread_cache',
      'item_cache',
      'pending_approvals',
      'codex_config_snapshots',
      'slash_command_manifest_cache',
    };

    for (final tableName in remoteCacheTables) {
      final table = LocalDataSchema.table(tableName);
      expect(table.authority, LocalDataAuthority.remoteCodexAuthoritative);
      expect(table.retention, LocalDataRetention.reconnectCache);
    }
  });

  test('project content risk is never modeled as durable plain cache', () {
    final riskyTables = LocalDataSchema.tables.where(
      (table) =>
          table.contentPolicy ==
          LocalDataContentPolicy.mayContainProjectContent,
    );

    expect(riskyTables.map((table) => table.name), isNotEmpty);
    for (final table in riskyTables) {
      expect(
        table.retention,
        isNot(LocalDataRetention.durable),
        reason: '${table.name} may contain project content',
      );
      expect(
        table.requiresExportRedaction ||
            table.authority == LocalDataAuthority.remoteCodexAuthoritative,
        isTrue,
        reason: '${table.name} needs redaction or remote-cache semantics',
      );
    }
  });

  test(
    'credential and raw RPC tables keep sensitive data out of plain fields',
    () {
      final sshColumns = LocalDataSchema.table(
        'ssh_profiles',
      ).columns.map((column) => column.name).toSet();
      expect(sshColumns, isNot(contains('password')));
      expect(sshColumns, isNot(contains('private_key')));
      expect(sshColumns, contains('credential_ref'));

      final rpcLogs = LocalDataSchema.table('raw_rpc_logs');
      expect(rpcLogs.requiresExportRedaction, isTrue);
      expect(
        rpcLogs.columns.map((column) => column.name),
        contains('redacted_json'),
      );
      expect(
        rpcLogs.columns.map((column) => column.name),
        isNot(contains('raw_json')),
      );
    },
  );

  test('generates stable create statements for tables and indexes', () {
    final statements = LocalDataSchema.createStatements;

    expect(
      statements,
      contains(startsWith('CREATE TABLE IF NOT EXISTS ssh_profiles')),
    );
    expect(
      statements,
      contains(startsWith('CREATE TABLE IF NOT EXISTS raw_rpc_logs')),
    );
    expect(
      statements,
      contains(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_known_hosts_endpoint '
        'ON known_hosts (host, port, key_type);',
      ),
    );
    expect(statements.length, greaterThan(LocalDataSchema.tables.length));
  });

  test('override profiles do not claim to store server effective config', () {
    final table = LocalDataSchema.table('codex_override_profiles');

    expect(table.authority, LocalDataAuthority.localOnly);
    expect(table.notes, contains('explicit override'));
    expect(table.notes, contains('not server effective'));
  });
}
