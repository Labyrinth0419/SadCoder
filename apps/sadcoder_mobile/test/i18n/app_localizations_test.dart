import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  test('supports the initial en-US and zh-CN locales', () async {
    expect(AppLocalizations.supportedLocales, const [
      Locale('en', 'US'),
      Locale('zh', 'CN'),
    ]);
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(
      AppLocalizations.delegate.isSupported(const Locale('en', 'US')),
      isTrue,
    );
    expect(
      AppLocalizations.delegate.isSupported(const Locale('zh', 'CN')),
      isTrue,
    );
    expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);

    final zh = await AppLocalizations.delegate.load(const Locale('zh', 'CN'));
    expect(zh.locale, const Locale('zh', 'CN'));

    final fallback = await AppLocalizations.delegate.load(const Locale('fr'));
    expect(fallback.locale, const Locale('en', 'US'));
  });

  test('keeps English and Chinese resource maps complete', () {
    final values = AppLocalizations.debugValues;
    final englishKeys = values['en']!.keys.toSet();
    final chineseKeys = values['zh']!.keys.toSet();

    expect(chineseKeys.difference(englishKeys), isEmpty);
    expect(englishKeys.difference(chineseKeys), isEmpty);
    for (final entry in values.entries) {
      for (final message in entry.value.entries) {
        expect(
          message.value.trim(),
          isNotEmpty,
          reason: '${entry.key}.${message.key} must not be blank',
        );
      }
    }
  });

  test('formats numbers dates and file sizes with the active locale', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en', 'US'));
    expect(en.tokenCount(1234), '1,234 tokens');
    expect(en.workspaceFilesLoadedBytes(1536, 1048576), '1.5 KB / 1 MB loaded');
    expect(en.rateLimitResetsAt(1730947200), contains('2024'));
    expect(en.rateLimitResetsAt(1730947200), isNot(contains('1730947200')));

    final zh = await AppLocalizations.delegate.load(const Locale('zh', 'CN'));
    expect(zh.tokenCount(1234), '1,234 个 token');
    expect(zh.workspaceFilesLoadedBytes(1536, 1048576), '已加载 1.5 KB / 1 MB');
    expect(zh.rateLimitResetsAt(1730947200), contains('2024'));
    expect(zh.rateLimitResetsAt(1730947200), isNot(contains('1730947200')));
  });
}
