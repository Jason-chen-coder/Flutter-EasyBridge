import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LocalhostServerManager {
  LocalhostServerManager._();
  static final LocalhostServerManager _instance = LocalhostServerManager._();
  factory LocalhostServerManager() => _instance;

  InAppLocalhostServer? _server;
  bool _running = false;
  int _port = 8080;
  String _documentRoot = 'assets/h5';

  /// 是否启用调试日志（默认仅在 debug 模式下开启）
  final bool _enableDebugLog = kDebugMode;

  /// Start the server if not started. Returns the base URL (e.g. http://127.0.0.1:8080).
  Future<String> start({String? documentRoot, int port = 8080}) async {
    if (_running) return baseUrl;

    if (documentRoot != null) _documentRoot = documentRoot;

    // 尝试优先使用用户指定的端口，如果不可用就自动找一个
    final int chosenPort = await _findAvailablePort(preferred: port, range: 30);

    // 在多个候选端口上尝试启动，避免竞态条件
    final portsToTry = <int>[chosenPort];
    for (int i = 1; i <= 4; i++) {
      portsToTry.add(chosenPort + i);
    }

    for (final candidate in portsToTry) {
      if (await _tryStartServer(candidate)) {
        return baseUrl;
      }
    }

    // ✅ 最后兜底：让操作系统自动分配端口 (port=0)，彻底避免 TOCTOU
    try {
      final srv = InAppLocalhostServer(documentRoot: _documentRoot!, port: 0);
      await srv.start();
      _server = srv;
      _port = srv.port; // 系统实际分配的端口
      _running = true;
      _log("Started on ephemeral port $_port");
      return baseUrl;
    } catch (e) {
      _running = false;
      _server = null;
      _log("Failed to start on ephemeral port: $e", isError: true);
      rethrow;
    }
  }

  /// 尝试启动服务
  Future<bool> _tryStartServer(int port) async {
    try {
      final srv = InAppLocalhostServer(documentRoot: _documentRoot!, port: port);
      await srv.start();
      _server = srv;
      _port = port;
      _running = true;
      _log("Started on port $port");
      return true;
    } catch (e) {
      _log("Port $port unavailable: $e", isError: true);
      return false;
    }
  }

  String get baseUrl => 'http://127.0.0.1:$_port';
  bool get isRunning => _running;

  Future<void> stop() async {
    if (_server != null && _running) {
      try {
        await _server?.close();
        _log("Stopped server on port $_port");
      } catch (e) {
        _log("Error stopping server: $e", isError: true);
      }
    }
    _running = false;
    _server = null;
  }

  Future<int> _findAvailablePort({required int preferred, int range = 20}) async {
    for (int offset = 0; offset <= range; offset++) {
      final candidate = preferred + offset;
      if (await _isPortFree(candidate)) {
        return candidate;
      }
    }
    return preferred;
  }

  Future<bool> _isPortFree(int port) async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port, shared: false);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _log(String message, {bool isError = false}) {
    if (_enableDebugLog) {
      if (isError) {
        debugPrint("⚠️ [LocalhostServer] $message");
      } else {
        debugPrint("✅ [LocalhostServer] $message");
      }
    }
  }
}