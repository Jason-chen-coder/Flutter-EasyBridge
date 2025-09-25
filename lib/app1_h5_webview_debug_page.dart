// Reusable widget to load local H5 packaged under assets/h5/<appName>/index.html
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'utils/app_bridge.dart';
import 'h5_webview.dart';

typedef WebViewCreatedCallback =
    void Function(InAppWebViewController controller);

// 消息数据类
class MessageItem {
  final String eventName;
  final String content;
  final DateTime timestamp;
  final String direction; // 'h5-to-flutter' or 'flutter-to-h5'

  MessageItem({
    required this.eventName,
    required this.content,
    required this.timestamp,
    required this.direction,
  });
}

class App1H5WebviewDebugPage extends StatefulWidget {
  /// appName should correspond to the folder name under assets/h5, e.g. "app1" or "app2"
  /// The entry point will be assets/h5/<appName>/dist/index.html
  /// This is ignored if onlineUrl is provided
  final String appName;

  final WebViewCreatedCallback? onWebViewCreated;
  final void Function(String url)? onLoadStop;
  final void Function(String url, int code, String message)? onLoadError;
  final void Function(int progress)? onProgress;

  const App1H5WebviewDebugPage({
    Key? key,
    required this.appName,
    this.onWebViewCreated,
    this.onLoadStop,
    this.onLoadError,
    this.onProgress,
  }) : super(key: key);

  @override
  _App1H5WebviewDebugPageState createState() => _App1H5WebviewDebugPageState();
}

class _App1H5WebviewDebugPageState extends State<App1H5WebviewDebugPage> {
  final AppBridge _bridge = AppBridge();
  dynamic _lastH5Reply;
  String? _arrowOutMsg; // Flutter -> H5
  String? _arrowInMsg; // H5 -> Flutter
  // Unified message list with timestamps
  final List<MessageItem> _unifiedMessageLogs = <MessageItem>[];

  // Add text controller for input field
  final TextEditingController _messageController = TextEditingController();

  // Scroll controller for unified message list
  final ScrollController _unifiedMessageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupBridgeMethods();
    _setupBridgeEvents();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  String _formatTs(DateTime dt) {
    final y = dt.year;
    final m = _twoDigits(dt.month);
    final d = _twoDigits(dt.day);
    final h = _twoDigits(dt.hour);
    final mi = _twoDigits(dt.minute);
    final s = _twoDigits(dt.second);
    return '$y-$m-$d $h:$mi:$s';
  }

  void _appendMessage(String eventName, String content, String direction) {
    // 检查是否需要自动滚动（只有在接近底部时才滚动）
    bool shouldAutoScroll = false;
    if (_unifiedMessageScrollController.hasClients) {
      final position = _unifiedMessageScrollController.position;
      // 如果距离底部小于 100 像素，认为用户在底部，需要自动滚动
      shouldAutoScroll = (position.maxScrollExtent - position.pixels) < 100;
    } else {
      // 如果还没有客户端，默认自动滚动
      shouldAutoScroll = true;
    }

    setState(() {
      _unifiedMessageLogs.add(
        MessageItem(
          eventName: eventName,
          content: content,
          timestamp: DateTime.now(),
          direction: direction,
        ),
      );
    });

    // 只有在需要时才自动滚动到底部
    if (shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_unifiedMessageScrollController.hasClients) {
          _unifiedMessageScrollController.animateTo(
            _unifiedMessageScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildMessageItem(
    MessageItem messageItem,
    String messageType,
    Color typeColor,
  ) {
    // Determine if it's an error message
    final isError = messageItem.content.startsWith('Error:');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isError ? Colors.red[300]! : Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withOpacity(0.3)),
                ),
                child: Text(
                  messageType,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 事件名
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  messageItem.eventName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTs(messageItem.timestamp),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              messageItem.content,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red[700] : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 设置 bridge 方法(H5 调用 Flutter方法)
  void _setupBridgeMethods() {
    // Add page.h5ToFlutter method with debug functionality
    _bridge.register('page.h5ToFlutter', (params) async {
      print('[DEBUG] page.h5ToFlutter called with params: $params');

      // Handle different parameter formats
      String message;
      String? from;
      if (params is Map) {
        message = params['message']?.toString() ?? 'No message';
        from = params['from']?.toString();
      } else if (params is String) {
        message = params;
      } else {
        message = params?.toString() ?? 'null';
      }

      // Create full message with context
      final fullMessage = from != null ? '$message (from: $from)' : message;

      print('[DEBUG] Extracted message: $message, from: $from');

      // Update UI immediately using setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _arrowInMsg = fullMessage;
          });
          _appendMessage('page.h5ToFlutter', fullMessage, 'h5-to-flutter');
        }
      });

      // Create the reply
      final Map<String, Object> reply = {
        'reply': 'Flutter 已收到: $fullMessage',
        'page': 'app1',
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      // Update outgoing message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _arrowOutMsg = reply.toString();
          });
        }
      });

      print('[DEBUG] Returning reply: $reply');
      return reply;
    });

    // Add app.getInfo method with debug functionality
    _bridge.register('app.getInfo', (params) async {
      print('[DEBUG] app.getInfo called with params: $params');

      // Update UI to show incoming request
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _arrowInMsg = 'Get App Info';
          });
          _appendMessage('app.getInfo', 'H5 请求获取 App 信息', 'h5-to-flutter');
        }
      });

      final info = await PackageInfo.fromPlatform();
      final Map<String, Object?> result = {
        'appName': info.appName,
        'packageName': info.packageName,
        'version': info.version,
        'buildNumber': info.buildNumber,
        'buildSignature': info.buildSignature,
        'installerStore': info.installerStore,
      };

      // Update UI to show outgoing response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _arrowOutMsg = result.toString();
          });
        }
      });

      print('[DEBUG] app.getInfo returning: $result');
      return result;
    });
  }

  // 设置 bridge 事件监听(H5 主动发送事件)
  void _setupBridgeEvents() {
    // Add page.ready event handler
    _bridge.onEvent('page.ready', (payload) {
      debugPrint('App1 - H5 page.ready: $payload');
      _appendMessage('page.ready', payload.toString(), 'h5-to-flutter');
    });

    // 监听 H5 推送的消息
    _bridge.onEvent('h5.pushMessage', (payload) {
      final message =
          payload is Map && payload['message'] != null
              ? payload['message'].toString()
              : payload.toString();
      debugPrint('App1 - H5 push message: $message');
      _appendMessage('h5.pushMessage', '推送消息: $message', 'h5-to-flutter');
    });
  }

  // Method to send custom message from input field
  Future<void> _sendCustomMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (mounted) {
      setState(() {
        _arrowOutMsg = message;
      });
    }
    try {
      final res = await _bridge.invokeJs('page.echo', {'message': message});
      if (mounted) {
        setState(() {
          _lastH5Reply = res;
          _arrowInMsg = res?.toString();
        });
        _appendMessage('page.echo', res.toString(), 'flutter-to-h5');
        _messageController.clear(); // Clear input after successful send
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastH5Reply = {'error': e.toString()};
          _arrowInMsg = 'Error: ${e.toString()}';
        });
        _appendMessage('page.echo', 'Error: ${e.toString()}', 'flutter-to-h5');
      }
    }
  }

  @override
  void dispose() {
    _bridge.detach(); // 清理外部管理的 bridge
    _messageController.dispose(); // Dispose text controller
    _unifiedMessageScrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: SafeArea(
        child: Row(
          children: [
            // Left: Flutter controls and received messages
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Flutter 基座",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D96A),
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '消息列表',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(60, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _unifiedMessageLogs.clear();
                              });
                            },
                            child: const Text('清空', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              _unifiedMessageLogs.isEmpty
                                  ? const Center(
                                    child: Text(
                                      '暂无消息',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    controller: _unifiedMessageScrollController,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _unifiedMessageLogs.length,
                                    itemBuilder: (context, index) {
                                      final messageItem = _unifiedMessageLogs[index];
                                      return _buildMessageItem(
                                        messageItem,
                                        messageItem.direction == 'h5-to-flutter' 
                                            ? '[H5 → Flutter]' 
                                            : '[Flutter → H5]',
                                        messageItem.direction == 'h5-to-flutter' 
                                            ? Colors.orange 
                                            : Colors.blue,
                                      );
                                    },
                                  ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: const Color(0xFF00D96A),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (mounted) {
                              setState(() {
                                _arrowOutMsg = 'Get H5 Info';
                              });
                            }
                            try {
                              final res = await _bridge.invokeJs('h5.getInfo');
                              if (mounted) {
                                setState(() {
                                  _lastH5Reply = res;
                                  _arrowInMsg = res?.toString();
                                });
                                _appendMessage('h5.getInfo', res.toString(), 'flutter-to-h5');
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _lastH5Reply = {'error': e.toString()};
                                  _arrowInMsg = 'Error: ${e.toString()}';
                                });
                                _appendMessage(
                                  'h5.getInfo',
                                  'Error: ${e.toString()}',
                                  'flutter-to-h5',
                                );
                              }
                            }
                          },
                          child: const Text('获取 H5 应用信息'),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final message =
                                'Flutter 推送消息 - ${_formatTs(DateTime.now())}';
                            try {
                              await _bridge
                                  .emitEventToJs('flutter.pushMessage', {
                                    'message': message,
                                    'from': 'flutter',
                                    'timestamp':
                                        DateTime.now().millisecondsSinceEpoch,
                                  });
                              if (mounted) {
                                setState(() {
                                  _arrowOutMsg = '已推送: $message';
                                });
                                _appendMessage(
                                  'flutter.pushMessage',
                                  '已推送: $message',
                                  'flutter-to-h5',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _arrowOutMsg = 'Error: ${e.toString()}';
                                });
                                _appendMessage(
                                  'flutter.pushMessage',
                                  'Error: ${e.toString()}',
                                  'flutter-to-h5',
                                );
                              }
                            }
                          },
                          child: const Text('推送消息给 H5'),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: '输入要发送给 H5 的消息',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _sendCustomMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: const Color(0xFF00D96A),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _sendCustomMessage,
                              child: const Text('发送给H5'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Middle: arrows and messages
            Container(
              width: 140,
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.blueGrey),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 120,
                      child: Text(
                        _arrowOutMsg == null ? '' : '${_arrowOutMsg!}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Icon(Icons.arrow_back, color: Colors.green),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 120,
                      child: Text(
                        _arrowInMsg == null ? '' : '${_arrowInMsg!}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right: H5 WebView
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: H5Webview(
                    appName: widget.appName,
                    bridge: _bridge,
                    onWebViewCreated: widget.onWebViewCreated,
                    onLoadStop: (url) {
                      // Handle onLoadStop with additional debug functionality
                      // Try calling a JS method to fetch state
                      _bridge
                          .invokeJs('page.getState')
                          .then((state) {
                            debugPrint('JS page.getState -> $state');
                            _appendMessage('page.getState', state.toString(), 'flutter-to-h5');
                          })
                          .catchError((e) {
                            debugPrint('JS page.getState error -> $e');
                            _appendMessage(
                              'page.getState',
                              'Error: ${e.toString()}',
                              'flutter-to-h5',
                            );
                          });

                      if (widget.onLoadStop != null) {
                        widget.onLoadStop!(url);
                      }
                    },
                    onLoadError: widget.onLoadError,
                    onProgress: widget.onProgress,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
