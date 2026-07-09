import '../protocol/codex_app_server_client.dart';
import 'permission_profile_list_reader.dart';

class CodexPermissionProfileListReader implements PermissionProfileListReader {
  const CodexPermissionProfileListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    final profiles = <PermissionProfileSummary>[];
    String? cursor;
    final seenCursors = <String>{};
    do {
      final result = await _client.listPermissionProfiles(
        cwd: cwd,
        cursor: cursor,
      );
      final page = PermissionProfileListPage.fromJson(result);
      profiles.addAll(page.profiles);
      cursor = page.nextCursor;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw StateError('permissionProfile/list returned a repeated cursor');
      }
    } while (cursor != null);

    return PermissionProfileListPage(profiles: List.unmodifiable(profiles));
  }
}
