import '../../turns/turn_text_element.dart';

class ChatComposerMention {
  const ChatComposerMention({
    required this.token,
    required this.start,
    required this.end,
  });

  final String token;
  final int start;
  final int end;

  bool isPresentIn(String text) {
    return start >= 0 &&
        end <= text.length &&
        end > start &&
        text.substring(start, end) == token;
  }

  bool overlapsRange(int rangeStart, int rangeEnd) {
    return start < rangeEnd && end > rangeStart;
  }

  TurnTextElement toTextElement(String text) {
    return TurnTextElement.fromCodeUnitRange(
      text: text,
      start: start,
      end: end,
    );
  }
}

void pruneChatComposerMentions(
  List<ChatComposerMention> mentions,
  String text,
) {
  mentions.removeWhere((mention) => !mention.isPresentIn(text));
}

void removeChatComposerMentionsOverlappingRange(
  List<ChatComposerMention> mentions, {
  required int start,
  required int end,
}) {
  mentions.removeWhere((mention) => mention.overlapsRange(start, end));
}

List<TurnTextElement> chatComposerTextElements({
  required String text,
  required Iterable<ChatComposerMention> mentions,
}) {
  return [
    for (final mention in mentions)
      if (mention.isPresentIn(text)) mention.toTextElement(text),
  ];
}
