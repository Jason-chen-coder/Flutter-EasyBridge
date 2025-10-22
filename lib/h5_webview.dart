// Reusable widget to load local H5 packaged under assets/h5/<appName>/index.html or online URLs
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'utils/localhost_server_manager.dart';
import 'utils/app_bridge.dart';

typedef WebViewCreatedCallback =
    void Function(InAppWebViewController controller);

class H5Webview extends StatefulWidget {
  /// appName should correspond to the folder name under assets/h5, e.g. "app1" or "app2"
  /// The entry point will be assets/h5/<appName>/dist/index.html
  /// This is ignored if onlineUrl or localFilePath is provided
  final String appName;

  /// Optional online URL to load instead of local assets
  /// If provided, appName is ignored and this URL will be loaded directly
  /// Example: 'https://example.com/app' or 'http://localhost:3000'
  final String? onlineUrl;

  /// Optional file system path to load instead of assets
  /// If provided, this will be used with file:// protocol
  /// Example: '/path/to/app/dist/index.html'
  final String? localFilePath;

  /// External bridge instance - if provided, this will be used instead of creating a new one
  /// This allows external control over bridge methods and events
  final AppBridge bridge;

  /// Optional hero tag for shared element transition
  /// If provided, the loading progress indicator will be wrapped in a Hero widget
  final String heroTag;

  /// Optional hero icon for shared element transition
  /// If provided along with heroTag, this icon will be displayed during loading
  final Widget heroIcon;

  final WebViewCreatedCallback? onWebViewCreated;
  final void Function(String url)? onLoadStop;
  final void Function(String url, int code, String message)? onLoadError;

  const H5Webview({
    Key? key,
    required this.appName,
    required this.bridge,
    this.onlineUrl,
    this.localFilePath,
    required this.heroTag,
    required this.heroIcon,
    this.onWebViewCreated,
    this.onLoadStop,
    this.onLoadError,
  }) : super(key: key);

  @override
  H5WebviewState createState() => H5WebviewState();
}

class H5WebviewState extends State<H5Webview> {
  final LocalhostServerManager _serverManager = LocalhostServerManager();
  InAppWebViewController? _controller;
  Key _webViewKey = UniqueKey();
  String? _initialUrl;
  int _progress = 0;
  bool _isLoaded = false;
  int _redirectCount = 0;
  String? _lastUrl;

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
    } else if (widget.localFilePath != null) {
      // Use local file system path with file:// protocol
      url = 'file://${widget.localFilePath}';
      print('[H5Webview] Loading local file: $url');
    } else {
      // Use local assets with localhost server
      url = await _serverManager.start(documentRoot: 'assets/h5');

      // Try to find index.html in the dist subdirectory first, then fallback to app directory
      String path = '/${widget.appName}/dist/index.html';

      url = '$url$path';
      print('[H5Webview] Loading local assets: $url');
    }

    setState(() {
      _progress = 0;
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
      return Center(
        child: SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(strokeWidth: 6),
        ),
      );
    }
    bool showH5Page = _progress >= 100 || _isLoaded;
    return Stack(
      children: [
        InAppWebView(
          key: _webViewKey,
          initialUrlRequest: URLRequest(url: WebUri(_initialUrl!)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useOnLoadResource: true,
            useShouldOverrideUrlLoading: true,
            allowUniversalAccessFromFileURLs: true,
            allowFileAccessFromFileURLs: true,
            allowsInlineMediaPlayback: true,
            useWideViewPort: true,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            clearCache: false,
            cacheEnabled: true,
          ),
          initialUserScripts: UnmodifiableListView<UserScript>([
            widget.bridge.userScript,
          ]),
          onProgressChanged: (controller, progress) {
            setState(() {
              _progress = progress;
            });
          },
          onWebViewCreated: (controller) async {
            _controller = controller;
            await widget.bridge.attach(controller);

            if (widget.onWebViewCreated != null) {
              widget.onWebViewCreated!(controller);
            }
          },
          onLoadStart: (c, url) {
            // 检测重定向循环
            if (_lastUrl == url?.toString()) {
              _redirectCount++;
              if (_redirectCount > 5) {
                print('[H5Webview] Redirect loop detected, stopping load');
                _controller?.stopLoading();
                return;
              }
            } else {
              _redirectCount = 0;
              _lastUrl = url?.toString();
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri != null) {
              print('[H5Webview] Navigation to: ${uri.toString()}');

              // 防止HTTP到HTTPS的循环重定向
              if (_lastUrl != null &&
                  ((_lastUrl!.startsWith('http://') &&
                          uri.toString().startsWith('https://')) ||
                      (_lastUrl!.startsWith('https://') &&
                          uri.toString().startsWith('http://')))) {
                final httpUrl = _lastUrl!
                    .replaceFirst('https://', '')
                    .replaceFirst('http://', '');
                final newUrl = uri
                    .toString()
                    .replaceFirst('https://', '')
                    .replaceFirst('http://', '');

                if (httpUrl == newUrl) {
                  _redirectCount++;
                  if (_redirectCount > 3) {
                    print(
                      '[H5Webview] Preventing redirect loop between HTTP/HTTPS',
                    );
                    return NavigationActionPolicy.CANCEL;
                  }
                }
              }
            }
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStop: (c, url) async {
            if (mounted) {
              setState(() {
                _isLoaded = true;
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
          onConsoleMessage:
              (controller, consoleMessage) =>
                  print('console: ${consoleMessage.message}'),
        ),
          AnimatedOpacity(
            opacity: showH5Page ? 0.0 : 1.0,
            duration: Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(strokeWidth: 6),
                    ),
                  ),
                  //
                    // 共享元素过渡 终点 - 显示应用图标
                    Center(
                      child: Hero(
                        tag: widget.heroTag,
                        child: Material(
                          color: Colors.transparent,
                          child: ClipOval(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              width: 60,
                              height: 60,
                              child: widget.heroIcon,
                            ),
                          ),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 提供公共接口供外部调用
  InAppWebViewController? get controller => _controller;
  bool get isLoaded => _isLoaded;
}
