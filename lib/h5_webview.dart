// Reusable widget to load local H5 packaged under assets/h5/<appName>/index.html or online URLs
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'utils/localhost_server_manager.dart';
import 'utils/app_bridge.dart';

typedef WebViewCreatedCallback = void Function(InAppWebViewController controller);

class H5Webview extends StatefulWidget {
  /// appName should correspond to the folder name under assets/h5, e.g. "app1" or "app2"
  /// The entry point will be assets/h5/<appName>/dist/index.html
  /// This is ignored if onlineUrl is provided
  final String appName;

  /// Optional online URL to load instead of local assets
  /// If provided, appName is ignored and this URL will be loaded directly
  /// Example: 'https://example.com/app' or 'http://localhost:3000'
  final String? onlineUrl;

  /// External bridge instance - if provided, this will be used instead of creating a new one
  /// This allows external control over bridge methods and events
  final AppBridge bridge;

  final WebViewCreatedCallback? onWebViewCreated;
  final void Function(String url)? onLoadStop;
  final void Function(String url, int code, String message)? onLoadError;
  final void Function(int progress)? onProgress;


  const H5Webview({
    Key? key,
    required this.appName,
    required this.bridge,
    this.onlineUrl,
    this.onWebViewCreated,
    this.onLoadStop,
    this.onLoadError,
    this.onProgress,
  }) : super(key: key);

  @override
  H5WebviewState createState() => H5WebviewState();
}

class H5WebviewState extends State<H5Webview> {
  final LocalhostServerManager _serverManager = LocalhostServerManager();
  InAppWebViewController? _controller;
  Key _webViewKey = UniqueKey();
  String? _initialUrl;
  bool _isLoaded = false;
  int _progress = 0; // 0-100

  @override
  void initState() {
    super.initState();
      _startServerAndLoad();
  }

  Future<void> _startServerAndLoad() async {
    String url;
    
    if (widget.onlineUrl != null) {
      // Use online URL directly
      url = widget.onlineUrl!;
      print('[H5Webview] Loading online URL: $url');
    } else {
      // Use local assets with localhost server
      final baseUrl = await _serverManager.start(documentRoot: 'assets/h5');
      
      // Try to find index.html in the dist subdirectory first, then fallback to app directory
      String path = '/${widget.appName}/dist/index.html';
      
      url = '$baseUrl$path';
      print('[H5Webview] Loading local assets: $url');
    }
    
    setState(() {
      _initialUrl = url;
      _webViewKey = UniqueKey();
    });

    // If controller already exists, load the URL immediately
    if (_controller != null && _initialUrl != null) {
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(_initialUrl!)),
      );
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller?.dispose();
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // show a placeholder while computing the initial URL / starting server
    if (_initialUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        InAppWebView(
          key: _webViewKey,
          initialUrlRequest: URLRequest(
            url: WebUri(_initialUrl!),
          ),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              javaScriptEnabled: true,
              useOnLoadResource: true,
            ),
            ios: IOSInAppWebViewOptions(
              allowsInlineMediaPlayback: true,
            ),
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            widget.bridge.userScript,
          ]),
          onWebViewCreated: (controller) async {
            _controller = controller;
            await widget.bridge.attach(controller);

            if (widget.onWebViewCreated != null) {
              widget.onWebViewCreated!(controller);
            }
          },
          onLoadStart: (c, url) {
            setState(() {
              _isLoaded = false;
              _progress = 0;
            });
          },
          onLoadStop: (c, url) async {
            if (mounted) {
              setState(() {
                _isLoaded = true;
                _progress = 100;
              });
            }
            if (widget.onLoadStop != null) {
              widget.onLoadStop!(url?.toString() ?? '');
            }
          },
          onLoadError: (controller, url, code, message) {
            if (widget.onLoadError != null) {
              widget.onLoadError!(url?.toString() ?? '', code, message);
            }
          },
          onConsoleMessage: (controller, consoleMessage) =>
              print('console: ${consoleMessage.message}'),
          onProgressChanged: (c, progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
            if (widget.onProgress != null) {
              widget.onProgress!(progress);
            }
            print('progress $progress');
          },
        ),
        if (!_isLoaded)
          Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
        // Top progress bar for H5 loading
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: (_progress >= 100) ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: (_progress <= 0 || _progress >= 100)
                    ? null
                    : (_progress / 100),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 提供公共接口供外部调用
  InAppWebViewController? get controller => _controller;
  bool get isLoaded => _isLoaded;
  int get progress => _progress;
} 