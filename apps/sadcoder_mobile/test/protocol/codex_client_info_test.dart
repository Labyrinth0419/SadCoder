import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_client_info.dart';

void main() {
  test('keeps app package version separate from app-server client version', () {
    expect(sadcoderMobileClientName, 'sadcoder-mobile');
    expect(sadcoderMobileClientVersion, '1.0.0');
    expect(sadcoderMobileAppVersion, '1.0.0+1');
  });

  test('keeps app diagnostics version aligned with pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final versionLine = pubspec.firstWhere(
      (line) => line.trimLeft().startsWith('version:'),
    );
    final pubspecVersion = versionLine.split(':').last.trim();

    expect(sadcoderMobileAppVersion, pubspecVersion);
  });
}
