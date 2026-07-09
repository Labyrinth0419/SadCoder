import 'package:flutter/foundation.dart';

import 'mcp_server_status_reader.dart';

typedef McpServerStatusReaderProvider = McpServerStatusReader? Function();

enum McpServerStatusListStatus { idle, loading, loaded, failed }

class McpServerStatusController extends ChangeNotifier {
  McpServerStatusController({
    required McpServerStatusReaderProvider readerProvider,
  }) : _readerProvider = readerProvider;

  final McpServerStatusReaderProvider _readerProvider;
  McpServerStatusListStatus _status = McpServerStatusListStatus.idle;
  McpServerStatusPage? _page;
  Object? _error;
  int _generation = 0;

  McpServerStatusListStatus get status => _status;
  McpServerStatusPage? get page => _page;
  List<McpServerStatus> get servers => _page?.servers ?? const [];
  Object? get error => _error;

  Future<void> refresh({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _setState(status: McpServerStatusListStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: McpServerStatusListStatus.loading, error: null);
    try {
      final page = await reader.listMcpServers(
        threadId: threadId,
        cursor: cursor,
        limit: limit,
        detail: detail,
      );
      if (generation != _generation) {
        return;
      }
      _page = page;
      _setState(status: McpServerStatusListStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: McpServerStatusListStatus.failed, error: error);
    }
  }

  void _setState({required McpServerStatusListStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
