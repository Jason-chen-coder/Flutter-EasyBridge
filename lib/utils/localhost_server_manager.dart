import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class LocalhostServerManager {
  LocalhostServerManager._();
  static final LocalhostServerManager _instance = LocalhostServerManager._();
  factory LocalhostServerManager() => _instance;

  HttpServer? _server;
  bool _running = false;
  int _port = 8080;

  // Assets mode: document root for assets (e.g., 'assets/h5')
  String? _assetsDocumentRoot;

  // File system mode: directory path for file system files
  String? _fileSystemDocumentRoot;

  /// Start the unified server that can serve both assets and file system files.
  ///
  /// [assetsDocumentRoot]: If provided, the server will serve files from Flutter assets
  ///   (e.g., 'assets/h5'). Files will be loaded using rootBundle.
  /// [fileSystemDocumentRoot]: If provided, the server will serve files from the file system
  ///   directory. Files will be read directly from disk.
  /// [port]: Preferred port number (default: 8080). If unavailable, will try nearby ports.
  ///
  /// Returns the base URL (e.g. http://127.0.0.1:8080).
  ///
  /// Note: Only one mode can be active at a time. If both are provided, fileSystemDocumentRoot takes precedence.
  Future<String> start({
    String? assetsDocumentRoot,
    String? fileSystemDocumentRoot,
    int port = 8080,
  }) async {
    // If server is already running with the same configuration, return existing URL
    if (_running) {
      if (fileSystemDocumentRoot != null && _fileSystemDocumentRoot == fileSystemDocumentRoot) {
        return baseUrl;
      }
      if (assetsDocumentRoot != null && _fileSystemDocumentRoot == null && _assetsDocumentRoot == assetsDocumentRoot) {
        return baseUrl;
      }
      // Configuration changed, stop and restart
      await stop();
    }

    // Determine mode: file system takes precedence
    if (fileSystemDocumentRoot != null) {
      final directory = Directory(fileSystemDocumentRoot);
      if (!await directory.exists()) {
        throw Exception('Directory does not exist: $fileSystemDocumentRoot');
      }
      _fileSystemDocumentRoot = fileSystemDocumentRoot;
      _assetsDocumentRoot = null;
    } else if (assetsDocumentRoot != null) {
      _assetsDocumentRoot = assetsDocumentRoot;
      _fileSystemDocumentRoot = null;
    } else {
      throw Exception('Either assetsDocumentRoot or fileSystemDocumentRoot must be provided');
    }

    // Strategy: Try preferred port first, then use _findAvailablePort to find next available port
    // and continue trying nearby ports. This combines direct binding (most reliable) with
    // pre-check optimization (skips obviously unavailable ports).

    // First, try the preferred port directly
    if (await _tryStartServer(port)) {
      _log("Successfully started on preferred port $port");
      return baseUrl;
    }

    // Preferred port unavailable, use _findAvailablePort to find next available port
    final int nextAvailablePort = await _findAvailablePort(preferred: port + 1, range: 19);

    // Build list of ports to try: start from the found port, then try nearby ports
    final portsToTry = <int>[nextAvailablePort];
    for (int i = 1; i <= 9; i++) {
      final candidate = nextAvailablePort + i;
      if (candidate != port) { // Skip preferred port (already tried)
        portsToTry.add(candidate);
      }
    }

    // Try to bind to each port in sequence
    for (final candidate in portsToTry) {
      if (await _tryStartServer(candidate)) {
        _log("Successfully started on port $candidate (preferred: $port was unavailable)");
        return baseUrl;
      }
    }

    // Fallback: use ephemeral port
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      _port = server.port;
      _running = true;
      _startRequestHandler(server);
      _log("Started on ephemeral port $_port (mode: ${_fileSystemDocumentRoot != null ? 'file system' : 'assets'})");
      return baseUrl;
    } catch (e) {
      _running = false;
      _server = null;
      _log("Failed to start on ephemeral port: $e", isError: true);
      rethrow;
    }
  }

  /// Start file system server (convenience method for backward compatibility)
  /// This is equivalent to calling start(fileSystemDocumentRoot: directoryPath, port: port)
  Future<String> startFileSystemServer(String directoryPath, {int port = 8080}) async {
    return start(fileSystemDocumentRoot: directoryPath, port: port);
  }

  /// Try to start server on a specific port
  Future<bool> _tryStartServer(int port) async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      _port = port;
      _running = true;
      _startRequestHandler(server);
      _log("Started on port $port (mode: ${_fileSystemDocumentRoot != null ? 'file system' : 'assets'})");
      return true;
    } catch (e) {
      _log("Port $port unavailable: $e", isError: true);
      return false;
    }
  }

  /// Start the unified request handler
  void _startRequestHandler(HttpServer server) {
    server.listen((HttpRequest request) async {
      try {
        // Handle CORS preflight requests
        if (request.method == 'OPTIONS') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.add('Access-Control-Allow-Origin', '*')
            ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            ..headers.add('Access-Control-Allow-Headers', 'Content-Type')
            ..close();
          return;
        }

        // Parse the requested path
        final requestedPath = request.uri.path;

        // Remove leading slash and decode URL encoding
        final relativePath = Uri.decodeComponent(
            requestedPath.startsWith('/') ? requestedPath.substring(1) : requestedPath
        );

        // Security: prevent directory traversal attacks
        final safePath = path.normalize(relativePath);
        if (safePath.contains('..')) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('Forbidden: Directory traversal not allowed')
            ..close();
          return;
        }

        // Route to appropriate handler based on mode
        if (_fileSystemDocumentRoot != null) {
          await _handleFileSystemRequest(request, safePath);
        } else if (_assetsDocumentRoot != null) {
          await _handleAssetsRequest(request, safePath);
        } else {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Server not configured')
            ..close();
        }
      } catch (e) {
        _log("Request handling error: $e", isError: true);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Internal server error: $e')
          ..close();
      }
    });
  }

  /// Handle file system requests
  Future<void> _handleFileSystemRequest(HttpRequest request, String safePath) async {
    final documentRoot = Directory(_fileSystemDocumentRoot!);
    final file = File(path.join(documentRoot.path, safePath));

    // If path is a directory, try index.html
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.directory) {
        final indexFile = File(path.join(file.path, 'index.html'));
        if (await indexFile.exists()) {
          await _serveFileSystemFile(request, indexFile);
          return;
        }
      } else {
        await _serveFileSystemFile(request, file);
        return;
      }
    }

    // Try with index.html if path ends with / or is empty
    if (request.uri.path.endsWith('/') || request.uri.path.isEmpty) {
      final indexFile = File(path.join(documentRoot.path, safePath, 'index.html'));
      if (await indexFile.exists()) {
        await _serveFileSystemFile(request, indexFile);
        return;
      }
    }

    // File not found
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('File not found: ${request.uri.path}')
      ..close();
  }

  /// Handle assets requests
  Future<void> _handleAssetsRequest(HttpRequest request, String safePath) async {
    // Build the asset path
    // safePath is relative to the document root (e.g., 'app1/dist/index.html')
    // We need to prepend the assets document root (e.g., 'assets/h5')
    final assetPath = path.join(_assetsDocumentRoot!, safePath).replaceAll('\\', '/');

    try {
      // Try to load the asset
      final byteData = await rootBundle.load(assetPath);
      final content = byteData.buffer.asUint8List();
      final extension = path.extension(assetPath).toLowerCase();

      await _serveContent(request, content, extension);
    } catch (e) {
      // If direct path fails, try with index.html for directory-like paths
      if (request.uri.path.endsWith('/') || request.uri.path.isEmpty || !assetPath.contains('.')) {
        final indexPath = path.join(assetPath, 'index.html').replaceAll('\\', '/');
        try {
          final byteData = await rootBundle.load(indexPath);
          final content = byteData.buffer.asUint8List();
          await _serveContent(request, content, '.html');
          return;
        } catch (_) {
          // Fall through to 404
        }
      }

      _log("Asset not found: $assetPath", isError: true);
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Asset not found: ${request.uri.path}')
        ..close();
    }
  }

  /// Serve a file system file with proper MIME types and CORS headers
  Future<void> _serveFileSystemFile(HttpRequest request, File file) async {
    final content = await file.readAsBytes();
    final extension = path.extension(file.path).toLowerCase();
    await _serveContent(request, content, extension);
  }

  /// Serve content with proper MIME types and CORS headers
  Future<void> _serveContent(HttpRequest request, List<int> content, String extension) async {
    final contentType = _getContentType(extension);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse(contentType)
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..headers.add('Access-Control-Allow-Headers', 'Content-Type')
      ..headers.contentLength = content.length
      ..add(content)
      ..close();
  }

  /// Get MIME type based on file extension
  String _getContentType(String extension) {
    switch (extension) {
      case '.html':
        return 'text/html; charset=utf-8';
      case '.js':
        return 'application/javascript; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.svg':
        return 'image/svg+xml';
      case '.ico':
        return 'image/x-icon';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      case '.ttf':
        return 'font/ttf';
      case '.eot':
        return 'application/vnd.ms-fontobject';
      case '.mp4':
        return 'video/mp4';
      case '.webm':
        return 'video/webm';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  String get baseUrl => 'http://127.0.0.1:$_port';
  bool get isRunning => _running;

  /// Get file system server base URL (for backward compatibility)
  String get fileSystemServerBaseUrl => baseUrl;

  Future<void> stop() async {
    if (_server != null && _running) {
      try {
        await _server?.close(force: true);
        _log("Stopped server on port $_port");
      } catch (e) {
        _log("Error stopping server: $e", isError: true);
      }
    }
    _running = false;
    _server = null;
    _assetsDocumentRoot = null;
    _fileSystemDocumentRoot = null;
  }

  /// Stop file system server (for backward compatibility)
  Future<void> stopFileSystemServer() async {
    await stop();
  }

  /// Find an available port starting from the preferred port.
  ///
  /// This method checks ports sequentially and returns the first available one.
  /// Note: This is a pre-check. The actual binding in _tryStartServer is the authoritative check.
  ///
  /// [preferred]: The preferred port number to start checking from
  /// [range]: Maximum number of ports to check beyond the preferred port (default: 20)
  /// Returns: The first available port found, or the preferred port if none found (caller should handle fallback)
  Future<int> _findAvailablePort({required int preferred, int range = 20}) async {
    // Try preferred port first
    if (await _isPortFree(preferred)) {
      return preferred;
    }

    // Try nearby ports
    for (int offset = 1; offset <= range; offset++) {
      final candidate = preferred + offset;
      if (await _isPortFree(candidate)) {
        return candidate;
      }
    }

    // If no port found in range, return preferred (caller will use ephemeral port as fallback)
    return preferred;
  }

  /// Check if a port is free by attempting to bind to it.
  ///
  /// This is a lightweight check that doesn't hold the port.
  /// The actual binding in _tryStartServer is the authoritative check.
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
    if (isError) {
      print("⚠️ [LocalhostServer] $message");
    } else {
      print("✅ [LocalhostServer] $message");
    }
  }
}
