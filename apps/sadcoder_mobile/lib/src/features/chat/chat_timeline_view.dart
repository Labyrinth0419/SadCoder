import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import 'chat_timeline_controller.dart';

class ChatTimelineConversation extends StatefulWidget {
  const ChatTimelineConversation({
    super.key,
    required this.compact,
    required this.timelineController,
    required this.onLoadOlderHistory,
    required this.timeline,
    this.header,
  });

  final bool compact;
  final ChatTimelineController? timelineController;
  final VoidCallback onLoadOlderHistory;
  final Widget timeline;
  final Widget? header;

  @override
  State<ChatTimelineConversation> createState() =>
      _ChatTimelineConversationState();
}

class _ChatTimelineConversationState extends State<ChatTimelineConversation> {
  final ScrollController _scrollController = ScrollController();
  String? _lastSelectedThreadId;
  bool _nearBottom = true;
  bool _showJumpToLatest = false;
  Offset? _jumpButtonOffset;

  static const Size _jumpButtonSize = Size(46, 46);

  @override
  void initState() {
    super.initState();
    _lastSelectedThreadId = widget.timelineController?.selectedThreadId;
    _scrollController.addListener(_handleScroll);
    widget.timelineController?.addListener(_handleTimelineChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void didUpdateWidget(ChatTimelineConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineController != widget.timelineController) {
      oldWidget.timelineController?.removeListener(_handleTimelineChanged);
      widget.timelineController?.addListener(_handleTimelineChanged);
      _lastSelectedThreadId = widget.timelineController?.selectedThreadId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    }
  }

  @override
  void dispose() {
    widget.timelineController?.removeListener(_handleTimelineChanged);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final nearBottom = _scrollController.position.extentAfter < 96;
    if (_scrollController.position.extentBefore < 96) {
      widget.onLoadOlderHistory();
    }
    if (nearBottom != _nearBottom || (_showJumpToLatest && nearBottom)) {
      setState(() {
        _nearBottom = nearBottom;
        if (nearBottom) {
          _showJumpToLatest = false;
        }
      });
    }
  }

  void _handleTimelineChanged() {
    final selectedThreadId = widget.timelineController?.selectedThreadId;
    final selectedThreadChanged = selectedThreadId != _lastSelectedThreadId;
    _lastSelectedThreadId = selectedThreadId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (selectedThreadChanged) {
        _jumpToLatest();
        return;
      }
      if (_nearBottom) {
        _animateToLatest();
      } else if (!_showJumpToLatest) {
        setState(() => _showJumpToLatest = true);
      }
    });
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    if (mounted) {
      setState(() {
        _nearBottom = true;
        _showJumpToLatest = false;
      });
    }
  }

  void _animateToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (mounted && _showJumpToLatest) {
      setState(() => _showJumpToLatest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
      child: Stack(
        children: [
          ListView(
            key: const ValueKey('chat-main-conversation'),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 8 : 16,
              widget.compact ? 8 : 14,
              widget.compact ? 8 : 16,
              widget.compact ? 48 : 52,
            ),
            children: [
              if (widget.header != null) widget.header!,
              widget.timeline,
            ],
          ),
          if (_showJumpToLatest)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final offset = _clampJumpButtonOffset(
                    _jumpButtonOffset ?? _defaultJumpButtonOffset(size),
                    size,
                  );
                  if (_jumpButtonOffset != offset) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _jumpButtonOffset = offset);
                      }
                    });
                  }
                  return Stack(
                    children: [
                      Positioned(
                        left: offset.dx,
                        top: offset.dy,
                        width: _jumpButtonSize.width,
                        height: _jumpButtonSize.height,
                        child: GestureDetector(
                          key: const ValueKey('chat-jump-to-latest'),
                          onPanUpdate: (details) {
                            setState(() {
                              _jumpButtonOffset = _clampJumpButtonOffset(
                                offset + details.delta,
                                size,
                              );
                            });
                          },
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: context.l10n.timelineJumpToLatest,
                            onPressed: _jumpToLatest,
                            child: const Icon(Icons.south, size: 19),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Offset _defaultJumpButtonOffset(Size size) {
    return Offset(size.width - _jumpButtonSize.width - 16, size.height - 64);
  }

  Offset _clampJumpButtonOffset(Offset offset, Size size) {
    const margin = 8.0;
    final maxX = size.width - _jumpButtonSize.width - margin;
    final maxY = size.height - _jumpButtonSize.height - margin;
    return Offset(
      _clampDouble(offset.dx, margin, maxX),
      _clampDouble(offset.dy, margin, maxY),
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (max < min) {
      return min;
    }
    return value.clamp(min, max).toDouble();
  }
}
