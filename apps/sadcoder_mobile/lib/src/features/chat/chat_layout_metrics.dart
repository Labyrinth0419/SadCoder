const chatThreadSidebarOverlayBreakpoint = 720.0;

double chatThreadSidebarWidthFor(double maxWidth) {
  if (maxWidth <= 320) {
    return maxWidth;
  }
  if (maxWidth < chatThreadSidebarOverlayBreakpoint) {
    return maxWidth * 0.88;
  }
  return 320;
}
