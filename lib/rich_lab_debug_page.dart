import 'package:easy_bridge/h5_webview.dart';
import 'package:easy_bridge/utils/app_bridge.dart';
import 'package:flutter/material.dart';

class RichLabDebugPage extends StatefulWidget {
  final String appName;
  final String heroTag;
  final Widget heroIcon;
  const RichLabDebugPage({
    super.key,
    required this.appName,
    required this.heroTag,
    required this.heroIcon,
  });

  @override
  State<RichLabDebugPage> createState() => _RichLabDebugPageState();
}

class _RichLabDebugPageState extends State<RichLabDebugPage> {
  final AppBridge _bridge = AppBridge.instance;
  String? _lastFetchedHtml;
  bool _showLeftPanel = true;
  bool _isFullScreen = false;
  final GlobalKey<H5WebviewState> _h5WebviewKey = GlobalKey<H5WebviewState>();

  @override
  void initState() {
    super.initState();
    _bridge.onEvent('richEditor.valueHtmlChanged', (params) {
      if (!mounted) return;
      final updatedHtml =
          params is Map && params['valueHtml'] != null
              ? params['valueHtml'].toString()
              : params?.toString();
      setState(() {
        _lastFetchedHtml = updatedHtml;
      });
    });
    _bridge.onEvent('richEditor.fullScreenChange', (params) {
      final isFullScreen = params is Map && params['isFullScreen'] == true;
      debugPrint(
        '[RichLabDebugPage] fullScreenChange -> isFullScreen: $isFullScreen, raw: $params',
      );
      if (mounted && _isFullScreen != isFullScreen) {
        setState(() {
          _isFullScreen = isFullScreen;
        });
      }
    });
  }

  @override
  void dispose() {
    _bridge.offEvent('richEditor.valueHtmlChanged');
    _bridge.offEvent('richEditor.fullScreenChange');
    super.dispose();
  }

  Future<void> _setValueHtml() async {
    final html = """
     <p style="text-align: center;"><img src="https://cdn.vuetifyjs.com/docs/images/one/logos/vuetify-logo-light.png" alt="logo" data-href="https://cdn.vuetifyjs.com/docs/images/one/logos/vuetify-logo-light.png" style="width: 384.00px;height: 120.00px;"></p><h1 style="text-align: center;"><span style="color: rgb(231, 95, 51);">标题</span></h1><h2 style="text-align: center;"><span style="color: rgb(255, 255, 255); background-color: rgb(54, 88, 226);">标题A</span></h2><h3><u>标题A1</u></h3><p><strong>文本</strong></p><blockquote><em>文本</em></blockquote><p><s>文本</s></p><p>示例公式：<span data-w-e-type="formula" data-w-e-is-void data-w-e-is-inline data-value="c = \\pm\\sqrt{a^2 + b^2}"></span></p><p>示例链接： </p><div data-w-e-type="link-card" data-w-e-is-void data-title="https://vuetifyjs.com/en/" data-link="https://vuetifyjs.com/en/" data-iconImgSrc="https://vuetifyjs.com/favicon.ico">
    <div class="info-container">
      <div class="title-container"><p>https://vuetifyjs.com/en/</p></div>
      <div class="link-container"><span>https://vuetifyjs.com/en/</span></div>
    </div>
    <div class="icon-container">
      <img src="https://vuetifyjs.com/favicon.ico"/>
    </div>
  </div><p> </p><p>示例表格：</p><table style="width: 100%;"><tbody><tr><th colSpan="1" rowSpan="1" width="auto">姓名</th><th colSpan="1" rowSpan="1" width="auto">年龄</th></tr><tr><td colspan="1" rowspan="1" width="auto" style="text-align: center;">小明</td><td colspan="1" rowspan="1" width="auto" style="text-align: center;">6</td></tr><tr><td colspan="1" rowspan="1" width="auto" style="text-align: center;">小红</td><td colspan="1" rowspan="1" width="auto" style="text-align: center;">5</td></tr></tbody></table><p>示例代码：</p><pre><code class="language-javascript">let a = 1;</code></pre><p><br></p>""";
    try {
      await _bridge.invokeJs('richEditor.setValueHtml', {'valueHtml': html});
    } catch (e) {
      print(e);
    }
  }

  Future<void> _getValueHtml() async {
    try {
      final result = await _bridge.invokeJs('richEditor.getValueHtml');
      if (mounted) {
        setState(() {
          // H5 返回 { valueHtml: '...' }
          _lastFetchedHtml =
              result is Map && result['valueHtml'] != null
                  ? result['valueHtml'].toString()
                  : result?.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastFetchedHtml = '获取失败: $e';
        });
      }
    }
  }

  Future<void> _exitFullScreen() async {
    try {
      await _bridge.invokeJs('richEditor.setFullScreen', {
        'isFullScreen': false,
      });
    } catch (e) {
      debugPrint('exit full screen failed: $e');
      setState(() {
        _isFullScreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h5Webview = H5Webview(
      key: _h5WebviewKey,
      appName: widget.appName,
      heroTag: widget.heroTag,
      heroIcon: widget.heroIcon,
      bridge: _bridge,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _showLeftPanel = !_showLeftPanel;
          });
        },
        icon: Icon(_showLeftPanel ? Icons.close : Icons.menu),
        label: Text(_showLeftPanel ? '隐藏操作区' : '显示操作区'),
      ),
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    // 左侧操作区域
                    if (_showLeftPanel)
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: const Border(
                              right: BorderSide(color: Colors.black12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                offset: const Offset(2, 0),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            spacing: 10,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _setValueHtml,
                                      child: const Text('1.设置 value'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: _getValueHtml,
                                      child: const Text('2.获取 value'),
                                    ),
                                  ],
                                ),
                              ),
                              if (_lastFetchedHtml != null)
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 10,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Text(
                                                  _lastFetchedHtml!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    // 右侧渲染区域（非全屏时展示）
                    Expanded(
                      flex: 3,
                      child:
                          _isFullScreen
                              ? const SizedBox.shrink()
                              : Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    width: 1,
                                    color: Color(0xffEEEEEE),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: h5Webview,
                              ),
                    ),
                  ],
                ),
                // 全屏覆盖层：沿用同一个 H5Webview 实例，确保状态/内容不重载
                if (_isFullScreen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 1,
                                  color: Color(0xffEEEEEE),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: h5Webview,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _exitFullScreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
