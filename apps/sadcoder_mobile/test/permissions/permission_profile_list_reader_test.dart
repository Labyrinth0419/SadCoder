import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/permissions/codex_permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('PermissionProfileListPage parses profile entries', () {
    final page = PermissionProfileListPage.fromJson({
      'data': [
        {'id': ':workspace', 'description': 'Workspace write', 'allowed': true},
        {'id': ':danger-full-access', 'allowed': false},
        'custom',
        {'description': 'missing id'},
        '',
        42,
      ],
      'nextCursor': '3',
    });

    expect(page.nextCursor, '3');
    expect(page.profiles, hasLength(3));
    expect(page.profiles[0].id, ':workspace');
    expect(page.profiles[0].label, ':workspace / Workspace write');
    expect(page.profiles[0].allowed, true);
    expect(page.profiles[1].id, ':danger-full-access');
    expect(page.profiles[1].allowed, false);
    expect(page.profiles[2].id, 'custom');
  });

  test('PermissionProfileListPage treats missing profile arrays as empty', () {
    expect(PermissionProfileListPage.fromJson({}).profiles, isEmpty);
    expect(
      PermissionProfileListPage.fromJson({'data': ':workspace'}).profiles,
      isEmpty,
    );
  });

  test('CodexPermissionProfileListReader follows pagination', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return switch (request.params?['cursor']) {
        null => {
          'data': [
            {'id': ':read-only', 'allowed': true},
          ],
          'nextCursor': '1',
        },
        '1' => {
          'data': [
            {'id': ':workspace', 'allowed': true},
          ],
        },
        _ => {'data': <Object?>[]},
      };
    });
    final reader = CodexPermissionProfileListReader(
      CodexAppServerClient(transport),
    );

    final page = await reader.listPermissionProfiles(cwd: '/repo');

    expect(page.profiles.map((profile) => profile.id), [
      ':read-only',
      ':workspace',
    ]);
    expect(requests.map((request) => request.method), [
      'permissionProfile/list',
      'permissionProfile/list',
    ]);
    expect(requests.first.params, {'cwd': '/repo'});
    expect(requests.last.params, {'cursor': '1', 'cwd': '/repo'});
  });
}
