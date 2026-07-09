import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/security/permission_risk.dart';

void main() {
  group('isHighRiskPermissionState', () {
    test('detects approval never', () {
      expect(
        isHighRiskPermissionState(approvalPolicy: {'type': 'never'}),
        isTrue,
      );
      expect(isHighRiskPermissionValue(approvalPolicy: 'never'), isTrue);
    });

    test('detects danger full access sandbox values', () {
      expect(
        isHighRiskPermissionState(sandboxPolicy: {'type': 'dangerFullAccess'}),
        isTrue,
      );
      expect(
        isHighRiskPermissionValue(sandboxMode: 'danger-full-access'),
        isTrue,
      );
      expect(
        isHighRiskPermissionValue(sandboxMode: 'dangerFullAccess'),
        isTrue,
      );
    });

    test('detects danger full access permission profiles', () {
      expect(
        isHighRiskPermissionState(permissionProfile: ':danger-full-access'),
        isTrue,
      );
      expect(
        isHighRiskPermissionState(
          permissionProfile: {'id': ':danger-full-access'},
        ),
        isTrue,
      );
    });

    test('does not flag normal permission states', () {
      expect(
        isHighRiskPermissionState(
          approvalPolicy: {'type': 'on-request'},
          sandboxPolicy: {'type': 'workspace-write'},
          permissionProfile: ':workspace',
        ),
        isFalse,
      );
      expect(
        isHighRiskPermissionValue(
          approvalPolicy: 'on-request',
          sandboxMode: 'workspace-write',
          permissionProfile: ':workspace',
        ),
        isFalse,
      );
    });
  });
}
