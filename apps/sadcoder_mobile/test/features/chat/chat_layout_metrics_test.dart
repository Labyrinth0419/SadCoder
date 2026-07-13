import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_layout_metrics.dart';

void main() {
  group('chatThreadSidebarWidthFor', () {
    test('uses the full available width on very narrow surfaces', () {
      expect(chatThreadSidebarWidthFor(0), 0);
      expect(chatThreadSidebarWidthFor(280), 280);
      expect(chatThreadSidebarWidthFor(320), 320);
    });

    test('uses most of the width on overlay sidebar surfaces', () {
      expect(chatThreadSidebarWidthFor(360), closeTo(316.8, 0.001));
      expect(chatThreadSidebarWidthFor(719), closeTo(632.72, 0.001));
    });

    test('caps the docked sidebar width on larger surfaces', () {
      expect(
        chatThreadSidebarWidthFor(chatThreadSidebarOverlayBreakpoint),
        320,
      );
      expect(chatThreadSidebarWidthFor(1024), 320);
      expect(chatThreadSidebarWidthFor(1600), 320);
    });
  });
}
