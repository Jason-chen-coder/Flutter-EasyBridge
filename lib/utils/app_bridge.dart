import 'dart:async';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// AppBridge: A simple, versioned bidirectional bridge between Flutter and H5.
///
/// # Features:
/// - Singleton pattern for easy global access
/// - Injects a small JS SDK that exposes `window.AppBridge` for third-party H5.
/// - Request/Response (both directions) with timeout and errors.
/// - Event emitting and listening (both directions).
/// - Method routing on Flutter side with white-listed handlers.
/// - Built-in methods for H5 to call (e.g., easyBridge.getInfo)
///
/// # Singleton Usage (Flutter):
/// ```dart
/// // Access the singleton instance anywhere
/// final bridge = AppBridge.instance;
/// 
/// // Initialize in your webview widget
/// await bridge.attach(controller);
/// 
/// // Default handlers (easyBridge.getInfo) are automatically registered
/// 
/// // Register custom methods
/// bridge.register('user.getProfile', (params) async => {...});
/// 
/// // Listen to events from H5
/// bridge.onEvent('app.visibility', (p) { ... });
/// 
/// // Invoke methods registered in H5
/// final jsResult = await bridge.invokeJs('page.getState');
/// 
/// // Emit events to H5
/// await bridge.emitEventToJs('app.ready', {'status': 'initialized'});
/// ```
///
/// # JavaScript Usage (H5):
/// ```javascript
/// // Get app info (built-in method)
/// const info = await AppBridge.invoke('easyBridge.getInfo');
/// console.log(info); 
/// // Result: {
/// //   success: true,
/// //   data: {
/// //     appName: "easy_bridge",
/// //     packageName: "com.example.easy_bridge",
/// //     version: "1.0.0",
/// //     buildNumber: "1",
/// //     platform: "android" | "ios" | "macos" | "windows" | "linux"
/// //   }
/// // }
///
/// // Register a method for Flutter to call
/// AppBridge.register('page.getState', async () => ({ ready: true }));
///
/// // Listen to events from Flutter
/// AppBridge.on('app.visibility', payload => console.log(payload));
///
/// // Emit events to Flutter
/// AppBridge.emit('app.ready', { timestamp: Date.now() });
///
/// // Get available methods
/// const capabilities = await AppBridge.invoke('easyBridge.getCapabilities');
/// console.log(capabilities.methods); // List of all available methods
/// ```
///
/// # Default Methods Available to H5:
/// - `easyBridge.getInfo` - Get current app information (version, platform, etc.)
/// - `easyBridge.getCapabilities` - Get bridge version and available features
///
/// # Adding Custom Methods:
/// ```dart
/// bridge.register('custom.method', (params) async {
///   return {
///     'success': true,
///     'data': params,
///   };
/// });
/// ```
class AppBridge {
  AppBridge._({this.version = '1.0'}) {
    // Initialize default handlers immediately when singleton is created
    _initDefaultHandlers();
  }

  static final AppBridge _instance = AppBridge._(version: '1.0');

  static AppBridge get instance => _instance;

  final String version;
  InAppWebViewController? _controller;

  final Map<String, FutureOr<dynamic> Function(dynamic params)> _routes = {};
  final Map<String, void Function(dynamic params)> _eventListeners = {};

  final Map<String, _PendingRequest> _pendingJsRequests = {};

  /// UserScript that injects the JS SDK at document start.
  UserScript get userScript => UserScript(
        source: _jsSdkSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        contentWorld: ContentWorld.PAGE,
      );

  /// Attach to a created webview controller and set up handler.
  Future<void> attach(InAppWebViewController controller) async {
    _controller = controller;

    // Built-in capability API
    register('easyBridge.getCapabilities', (params) async => {
          'version': version,
          'methods': _routes.keys.toList(),
          'features': {
            'events': true,
            'requestFromFlutter': true,
            'requestFromJs': true,
          }
        });

    _controller?.addJavaScriptHandler(
      handlerName: 'bridge:message',
      callback: (args) async {
        final dynamic message = args.isNotEmpty ? args[0] : null;
        await _handleIncomingJsMessage(message);
        return null;
      },
    );
  }

  /// Initialize default handlers that can be called from H5
  Future<void> _initDefaultHandlers() async {
    register('easyBridge.getInfo', (params) async => await _getAppInfo());
  }

  /// Get application information
  Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'success': true,
        'data': {
          'appName': packageInfo.appName,
          'packageName': packageInfo.packageName,
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : Platform.isWindows
                      ? 'windows'
                      : Platform.isLinux
                          ? 'linux'
                          : Platform.isMacOS
                              ? 'macos'
                              : 'unknown',
        }
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  void detach() {
    _controller = null;
    _pendingJsRequests.clear();
  }

  /// Register a Flutter handler for a method (JS -> Flutter requests).
  void register(String method, FutureOr<dynamic> Function(dynamic params) handler) {
    print('[AppBridge] Registering method: $method');
    _routes[method] = handler;
  }

  void unregister(String method) {
    _routes.remove(method);
  }

  /// Listen to events emitted by JS (JS -> Flutter events).
  void onEvent(String event, void Function(dynamic params) listener) {
    _eventListeners[event] = listener;
  }

  void offEvent(String event) {
    _eventListeners.remove(event);
  }

  /// Emit an event to JS (Flutter -> JS events).
  Future<void> emitEventToJs(String event, [dynamic params]) async {
    await _sendToJs({
      'v': version,
      'type': 'event',
      'method': event,
      'params': params,
    });
  }

  /// Invoke a JS-registered method and get the result (Flutter -> JS request/response).
  Future<dynamic> invokeJs(String method, [dynamic params, Duration timeout = const Duration(seconds: 10)]) async {
    final String id = _generateId();
    final completer = Completer<dynamic>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _pendingJsRequests.remove(id);
        completer.completeError(_BridgeTimeoutError());
      }
    });
    _pendingJsRequests[id] = _PendingRequest(completer: completer, timer: timer);

    await _sendToJs({
      'v': version,
      'type': 'request',
      'id': id,
      'method': method,
      'params': params,
    });

    return completer.future;
  }

  // Internal: process messages from JS
  Future<void> _handleIncomingJsMessage(dynamic message) async {
    if (message is! Map) return;

    final String? type = message['type'] as String?;

    if (type == 'response') {
      final String? id = message['id'] as String?;
      if (id != null && _pendingJsRequests.containsKey(id)) {
        final pending = _pendingJsRequests.remove(id)!;
        pending.timer.cancel();
        if (message['error'] != null) {
          pending.completer.completeError(_BridgeRemoteError(message['error']));
        } else {
          pending.completer.complete(message['result']);
        }
      }
      return;
    }

    if (type == 'event') {
      final String? event = message['method'] as String?;
      final dynamic params = message['params'];
      if (event != null && _eventListeners.containsKey(event)) {
        try {
          _eventListeners[event]!(params);
        } catch (_) {}
      }
      return;
    }

    if (type == 'request') {
      final String? id = message['id'] as String?;
      final String? method = message['method'] as String?;
      final dynamic params = message['params'];

      if (id == null || method == null) return;

      try {
        print('[AppBridge] Handling request: method=$method, params=$params');
        final handler = _routes[method];
        if (handler == null) {
          print('[AppBridge] Method not found: $method, available methods: ${_routes.keys.toList()}');
          await _sendToJs({
            'v': version,
            'type': 'response',
            'id': id,
            'error': {
              'code': -32601,
              'message': 'Method not found: $method',
            },
          });
          return;
        }

        final result = await handler(params);
        print('[AppBridge] Method result: $result');
        await _sendToJs({
          'v': version,
          'type': 'response',
          'id': id,
          'result': result,
        });
      } catch (e) {
        await _sendToJs({
          'v': version,
          'type': 'response',
          'id': id,
          'error': {
            'code': -32000,
            'message': e.toString(),
          },
        });
      }
      return;
    }
  }

  Future<void> _sendToJs(Map<String, dynamic> message) async {
    if (_controller == null) return;
    await _controller!.callAsyncJavaScript(
      functionBody: 'window.__bridge_onNativeMessage(message);',
      arguments: {
        'message': message,
      },
    );
  }

  String _generateId() => '${DateTime.now().millisecondsSinceEpoch}-${_idCounter++}';

  static int _idCounter = 0;
}

class _PendingRequest {
  _PendingRequest({required this.completer, required this.timer});
  final Completer<dynamic> completer;
  final Timer timer;
}

class _BridgeTimeoutError implements Exception {
  @override
  String toString() => 'BridgeTimeout(-32001): request timed out';
}

class _BridgeRemoteError implements Exception {
  _BridgeRemoteError(this.errorObj);
  final dynamic errorObj;
  @override
  String toString() => 'BridgeRemoteError: $errorObj';
}

// JS SDK injected at document start.
const String _jsSdkSource = r"""
(function () {
  if (window.AppBridge) return;

  const listeners = new Map();      // event -> Set<fn>
  const serverHandlers = new Map(); // method -> fn(params) => result
  const pending = new Map();        // id -> {resolve,reject,timer}
  let reqId = 0;

  function genId() { return `${Date.now()}-${++reqId}`; }

  function addListener(event, fn) {
    if (!listeners.has(event)) listeners.set(event, new Set());
    listeners.get(event).add(fn);
  }
  function removeListener(event, fn) {
    listeners.get(event)?.delete(fn);
  }
  function emitLocal(event, payload) {
    const set = listeners.get(event);
    if (!set) return;
    for (const fn of set) try { fn(payload); } catch (_) {}
  }

  async function sendMessage(msg) {
    if (window.AppBridge && typeof window.AppBridge.postMessage === 'function') {
      // If native provided a postMessage proxy, prefer it
      window.AppBridge.postMessage(msg);
      return;
    }
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
      await window.flutter_inappwebview.callHandler('bridge:message', msg);
      return;
    }
    throw new Error('No native bridge available');
  }

  // Native -> JS entry point
  window.__bridge_onNativeMessage = function (msg) {
    try {
      if (!msg || typeof msg !== 'object') return;
      const { type } = msg;
      if (type === 'response') {
        const { id, result, error } = msg;
        const entry = id && pending.get(id);
        if (!entry) return;
        pending.delete(id);
        clearTimeout(entry.timer);
        if (error) entry.reject(Object.assign(new Error(error.message || 'BridgeError'), error));
        else entry.resolve(result);
        return;
      }
      if (type === 'event') {
        const { method, params } = msg;
        emitLocal(method, params);
        return;
      }
      if (type === 'request') {
        const { id, method, params } = msg;
        const fn = serverHandlers.get(method);
        if (!id) return;
        if (!fn) {
          sendMessage({ v: '1.0', type: 'response', id, error: { code: -32601, message: `Method not found: ${method}` } });
          return;
        }
        Promise.resolve()
          .then(() => fn(params))
          .then(result => sendMessage({ v: '1.0', type: 'response', id, result }))
          .catch(err => sendMessage({ v: '1.0', type: 'response', id, error: { code: -32000, message: String(err && err.message || err) } }));
        return;
      }
    } catch (_) {}
  };

  const AppBridge = {
    version: '1.0',
    invoke(method, params = {}, options = {}) {
      const id = genId();
      const timeoutMs = options.timeoutMs || 10000;
      const message = { v: '1.0', type: 'request', id, method, params };
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          pending.delete(id);
          reject(Object.assign(new Error('BridgeTimeout'), { code: -32001 }));
        }, timeoutMs);
        pending.set(id, { resolve, reject, timer });
        sendMessage(message).catch(err => {
          clearTimeout(timer);
          pending.delete(id);
          reject(err);
        });
      });
    },
    on(event, handler) { addListener(event, handler); return () => removeListener(event, handler); },
    off(event, handler) { removeListener(event, handler); },
    emit(event, params) { return sendMessage({ v: '1.0', type: 'event', method: event, params }); },
    register(method, handler) { serverHandlers.set(method, handler); },
    unregister(method) { serverHandlers.delete(method); },
    async getCapabilities() { return this.invoke('easyBridge.getCapabilities'); }
  };

  window.AppBridge = AppBridge;
})();
"""; 