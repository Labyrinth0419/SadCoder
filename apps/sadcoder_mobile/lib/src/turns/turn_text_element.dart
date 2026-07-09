import 'dart:convert';

class TurnTextElement {
  const TurnTextElement({
    required this.start,
    required this.end,
    this.placeholder,
  });

  factory TurnTextElement.fromCodeUnitRange({
    required String text,
    required int start,
    required int end,
    String? placeholder,
  }) {
    RangeError.checkValidRange(start, end, text.length);
    return TurnTextElement(
      start: utf8ByteOffset(text, start),
      end: utf8ByteOffset(text, end),
      placeholder: placeholder,
    );
  }

  final int start;
  final int end;
  final String? placeholder;

  bool get isValid => start >= 0 && end > start;

  TurnTextElement shift(int delta) {
    return TurnTextElement(
      start: start + delta,
      end: end + delta,
      placeholder: placeholder,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'byte_range': {'start': start, 'end': end},
      if (placeholder != null && placeholder!.isNotEmpty)
        'placeholder': placeholder,
    };
  }

  static int utf8ByteOffset(String text, int codeUnitOffset) {
    RangeError.checkValueInInterval(codeUnitOffset, 0, text.length);
    if (codeUnitOffset == 0) {
      return 0;
    }
    if (codeUnitOffset == text.length) {
      return utf8.encode(text).length;
    }
    return utf8.encode(text.substring(0, codeUnitOffset)).length;
  }
}
