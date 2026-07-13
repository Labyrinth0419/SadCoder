import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_composer_mention.dart';

void main() {
  group('ChatComposerMention', () {
    test('is present only when its exact token remains at the same range', () {
      const mention = ChatComposerMention(
        token: '@lib/main.dart',
        start: 5,
        end: 19,
      );

      expect(mention.isPresentIn('open @lib/main.dart'), isTrue);
      expect(mention.isPresentIn('open @lib/app.dart'), isFalse);
      expect(mention.isPresentIn('@lib/main.dart'), isFalse);
      expect(
        const ChatComposerMention(
          token: '@lib/main.dart',
          start: -1,
          end: 13,
        ).isPresentIn('open @lib/main.dart'),
        isFalse,
      );
      expect(
        const ChatComposerMention(
          token: '@lib/main.dart',
          start: 6,
          end: 6,
        ).isPresentIn('open @lib/main.dart'),
        isFalse,
      );
    });

    test('reports overlap with replaced composer ranges', () {
      const mention = ChatComposerMention(token: '@a.dart', start: 4, end: 11);

      expect(mention.overlapsRange(0, 4), isFalse);
      expect(mention.overlapsRange(11, 20), isFalse);
      expect(mention.overlapsRange(0, 5), isTrue);
      expect(mention.overlapsRange(5, 8), isTrue);
      expect(mention.overlapsRange(10, 20), isTrue);
    });
  });

  test('prunes mentions that no longer match the composer text', () {
    final mentions = [
      const ChatComposerMention(token: '@keep.dart', start: 0, end: 10),
      const ChatComposerMention(token: '@drop.dart', start: 11, end: 20),
    ];

    pruneChatComposerMentions(mentions, '@keep.dart @changed.dart');

    expect(mentions, hasLength(1));
    expect(mentions.single.token, '@keep.dart');
  });

  test('removes only mentions overlapping an inserted range', () {
    final mentions = [
      const ChatComposerMention(token: '@left.dart', start: 0, end: 10),
      const ChatComposerMention(token: '@hit.dart', start: 12, end: 21),
      const ChatComposerMention(token: '@right.dart', start: 24, end: 35),
    ];

    removeChatComposerMentionsOverlappingRange(mentions, start: 11, end: 22);

    expect(mentions.map((mention) => mention.token), [
      '@left.dart',
      '@right.dart',
    ]);
  });

  test('builds turn text elements using UTF-8 byte ranges', () {
    const text = '打开 @src/main.dart';
    final mentions = [
      const ChatComposerMention(token: '@src/main.dart', start: 3, end: 17),
      const ChatComposerMention(token: '@missing.dart', start: 18, end: 31),
    ];

    final elements = chatComposerTextElements(text: text, mentions: mentions);

    expect(elements, hasLength(1));
    expect(elements.single.start, 7);
    expect(elements.single.end, 21);
  });
}
