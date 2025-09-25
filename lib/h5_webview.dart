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
      // Use online URL directly and ensure HTTPS
      url = widget.onlineUrl!;
      if (url.startsWith('http://')) {
        url = url.replaceFirst('http://', 'https://');
      }
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
            
            setState(() {
              _isLoaded = false;
            });
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri != null) {
              print('[H5Webview] Navigation to: ${uri.toString()}');
              
              // 防止HTTP到HTTPS的循环重定向
              if (_lastUrl != null && 
                  ((_lastUrl!.startsWith('http://') && uri.toString().startsWith('https://')) ||
                   (_lastUrl!.startsWith('https://') && uri.toString().startsWith('http://')))) {
                final httpUrl = _lastUrl!.replaceFirst('https://', '').replaceFirst('http://', '');
                final newUrl = uri.toString().replaceFirst('https://', '').replaceFirst('http://', '');
                
                if (httpUrl == newUrl) {
                  _redirectCount++;
                  if (_redirectCount > 3) {
                    print('[H5Webview] Preventing redirect loop between HTTP/HTTPS');
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
          onConsoleMessage: (controller, consoleMessage) =>
              print('console: ${consoleMessage.message}'),
        ),
        if (!_isLoaded)
          Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  // 提供公共接口供外部调用
  InAppWebViewController? get controller => _controller;
  bool get isLoaded => _isLoaded;
}