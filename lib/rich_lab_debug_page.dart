import 'package:easy_bridge/h5_webview.dart';
import 'package:easy_bridge/utils/app_bridge.dart';
import 'package:flutter/material.dart';

class RichLabDebugPage extends StatefulWidget {
  final String appName;
  final String heroTag;
  final Widget heroIcon;
  final String onlineUrl;
  const RichLabDebugPage({
    super.key,
    required this.appName,
    required this.heroTag,
    required this.heroIcon,
    this.onlineUrl = '',
  });

  @override
  State<RichLabDebugPage> createState() => _RichLabDebugPageState();
}

class _RichLabDebugPageState extends State<RichLabDebugPage> {
  final AppBridge _bridge = AppBridge.instance;
  String? _lastSetStatus;
  String? _lastFetchedHtml;

  Future<void> _setValueHtml() async {
    final html ="""
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
      if (mounted) {
        setState(() {
          _lastSetStatus = '已设置 valueHtml';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastSetStatus = '设置失败: $e';
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _setValueHtml,
                  child: const Text('设置 valueHtml'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _getValueHtml,
                  child: const Text('获取 valueHtml'),
                ),
                const SizedBox(width: 12),
                if (_lastSetStatus != null)
                  Text(
                    _lastSetStatus!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (_lastFetchedHtml != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '最新获取：${_lastFetchedHtml!}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          Expanded(
            child: H5Webview(
              appName: widget.appName,
              onlineUrl: widget.onlineUrl,
              heroTag: widget.heroTag,
              heroIcon: widget.heroIcon,
              bridge: _bridge,
            ),
          ),
        ],
      ),
    );
  }
}
