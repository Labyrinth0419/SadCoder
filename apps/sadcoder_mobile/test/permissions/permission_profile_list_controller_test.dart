import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_controller.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';

void main() {
  test('refresh loads permission profiles from the current reader', () async {
    final reader = _FakePermissionProfileListReader(
      page: const PermissionProfileListPage(
        profiles: [PermissionProfileSummary(id: ':workspace')],
      ),
    );
    final controller = PermissionProfileListController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);
    final statuses = <PermissionProfileListStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh(cwd: '/repo');

    expect(reader.cwdValues, ['/repo']);
    expect(controller.status, PermissionProfileListStatus.loaded);
    expect(controller.profiles.single.id, ':workspace');
    expect(statuses, [
      PermissionProfileListStatus.loading,
      PermissionProfileListStatus.loaded,
    ]);
  });

  test(
    'refresh without a reader returns to idle and clears profiles',
    () async {
      _FakePermissionProfileListReader? reader =
          _FakePermissionProfileListReader(
            page: const PermissionProfileListPage(
              profiles: [PermissionProfileSummary(id: ':workspace')],
            ),
          );
      final controller = PermissionProfileListController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, PermissionProfileListStatus.idle);
      expect(controller.profiles, isEmpty);
    },
  );

  test('refresh records failures', () async {
    final controller = PermissionProfileListController(
      readerProvider: () => _FailingPermissionProfileListReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, PermissionProfileListStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakePermissionProfileListReader implements PermissionProfileListReader {
  _FakePermissionProfileListReader({required this.page});

  final PermissionProfileListPage page;
  final cwdValues = <String?>[];

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    cwdValues.add(cwd);
    return page;
  }
}

class _FailingPermissionProfileListReader
    implements PermissionProfileListReader {
  @override
  Future<PermissionProfileListPage> listPermissionProfiles({String? cwd}) {
    throw StateError('permission profile list failed');
  }
}
