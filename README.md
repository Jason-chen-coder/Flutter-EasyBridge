# Flutter H5 混合开发框架

一个基于 Flutter + WebView + 本地 HTTP 服务器的混合开发解决方案，支持 Flutter 基座与 H5 应用之间的双向通信。

## 📋 项目概述

该框架提供了一套完整的 Flutter 与 H5 应用交互机制，包括：

- 🔄 **双向通信**: Flutter ↔ H5 方法调用和事件传递
- 🌐 **本地服务器**: 内置 HTTP 服务器加载本地 H5 资源
- 🔌 **桥接系统**: 基于 AppBridge 的通信桥梁
- 📱 **响应式 UI**: 实时消息展示和交互界面
- 🛡️ **类型安全**: 完整的错误处理和超时机制

## 🏗️ 项目结构

```
flutter_h5/
├── lib/
│   ├── local_h5_webview.dart          # 可复用的 H5 WebView 组件
│   └── utils/
│       ├── app_bridge.dart            # 核心桥接器
│       └── localhost_server_manager.dart # 本地服务器管理
├── assets/h5/                         # H5 应用资源
│   └── app1/                          # 示例 H5 应用
│       └── dist/                      # 构建输出目录
│           ├── index.html             # 主页面
│           ├── app.js                 # JavaScript 逻辑
│           └── style.css              # 样式文件
└── README.md                          # 本文档
```

## 🚀 快速开始

### 1. 基本用法

```dart
import 'package:flutter/material.dart';
import 'local_h5_webview.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: LocalH5WebView(
          appName: 'app1',  // 对应 assets/h5/app1/dist/index.html
          onWebViewCreated: (controller) {
            print('WebView 创建完成');
          },
        ),
      ),
    );
  }
}
```

### 2. 创建新的 H5 应用

在 `assets/h5/` 下创建新目录，如 `app2/`：

```
assets/h5/app2/
└── dist/              # 构建输出目录
    ├── index.html     # 必需：主页面（固定入口文件）
    ├── app.js         # 建议：JavaScript 逻辑
    └── style.css      # 可选：样式文件
```

## 🔧 核心组件

### LocalH5WebView

可复用的 WebView 组件，负责加载和显示 H5 应用。

**参数说明：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `appName` | `String` | 必需 | H5 应用目录名，对应 `assets/h5/<appName>/dist/`，入口文件固定为 `index.html` |
| `onWebViewCreated` | `WebViewCreatedCallback?` | `null` | WebView 创建回调 |
| `onLoadStop` | `Function(String)?` | `null` | 页面加载完成回调 |
| `onLoadError` | `Function(String, int, String)?` | `null` | 页面加载错误回调 |
| `onProgress` | `Function(int)?` | `null` | 加载进度回调 |

### AppBridge

核心桥接器，负责 Flutter 与 H5 之间的通信。

**特性：**
- 双向方法调用（Request/Response）
- 双向事件传递（Fire-and-Forget）
- 自动错误处理和超时机制
- 类型安全的参数传递

### LocalhostServerManager

本地 HTTP 服务器管理器，自动处理端口分配和资源服务。

**特性：**
- 自动端口分配和冲突处理
- 支持多种静态资源类型
- 开发模式下的调试日志
- 单例模式，避免重复启动

## 📡 通信协议

### 1. 方法调用 (Request/Response)

#### Flutter → H5

**Flutter 端发起调用：**

```dart
// 基本调用
final result = await _bridge.invokeJs('h5.methodName', parameters);

// 示例：获取 H5 应用信息
final info = await _bridge.invokeJs('h5.getInfo');

// 示例：发送消息到 H5
final reply = await _bridge.invokeJs('page.echo', {'message': 'Hello H5'});
```

**H5 端注册方法：**

```javascript
// 注册方法供 Flutter 调用
window.AppBridge.register('h5.getInfo', async function() {
  return {
    page: 'app1',
    name: document.title,
    version: '1.0.0',
    ts: Date.now()
  };
});

window.AppBridge.register('page.echo', async function(params) {
  const message = params.message;
  return {
    reply: 'H5 已收到: ' + message,
    ts: Date.now()
  };
});
```

#### H5 → Flutter

**H5 端发起调用：**

```javascript
// 基本调用
const result = await window.AppBridge.invoke('flutter.methodName', parameters);

// 示例：获取 Flutter 应用信息
const appInfo = await window.AppBridge.invoke('app.getInfo');

// 示例：发送消息到 Flutter
const reply = await window.AppBridge.invoke('page.h5ToFlutter', {
  message: 'Hello Flutter',
  from: 'app1'
});
```

**Flutter 端注册方法：**

```dart
// 注册方法供 H5 调用
_bridge.register('app.getInfo', (params) async {
  final info = await PackageInfo.fromPlatform();
  return {
    'appName': info.appName,
    'version': info.version,
    'buildNumber': info.buildNumber,
  };
});

_bridge.register('page.h5ToFlutter', (params) async {
  final message = params['message']?.toString() ?? '';
  return {
    'reply': 'Flutter 已收到: $message',
    'ts': DateTime.now().millisecondsSinceEpoch,
  };
});
```

### 2. 事件系统 (Fire-and-Forget)

#### Flutter → H5

**Flutter 发送事件：**

```dart
// 发送事件到 H5（无需等待返回）
await _bridge.emitEventToJs('user.login', {'userId': 123});
```

**H5 监听事件：**

```javascript
// 监听 Flutter 发送的事件

window.AppBridge.on('user.login', function(payload) {
  console.log('用户登录:', payload.userId);
});
```

#### H5 → Flutter

**H5 发送事件：**

```javascript
// 发送事件到 Flutter（无需等待返回）
window.AppBridge.emit('page.ready', { ts: Date.now(), page: 'app1' });
window.AppBridge.emit('user.action', { action: 'click', target: 'button1' });
```

**Flutter 监听事件：**

```dart
// 监听 H5 发送的事件
_bridge.onEvent('page.ready', (payload) {
  print('H5 页面准备完成: $payload');
});

_bridge.onEvent('user.action', (payload) {
  print('用户操作: ${payload['action']}');
});
```

## 📚 标准 API 清单

### Flutter 端提供的方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `page.h5ToFlutter` | `{message: string, from?: string}` | `{reply: string, page: string, ts: number}` | 接收 H5 消息并回复 |
| `app.getInfo` | - | `{appName, packageName, version, buildNumber, ...}` | 获取 Flutter 应用信息 |
| `bridge.getCapabilities` | - | `{version, methods, features}` | 获取桥接器能力 |

### H5 端提供的方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `page.getState` | - | `{ready: boolean, ts: number, page: string}` | 获取页面状态 |
| `page.echo` | `{message: string}` | `{reply: string, page: string, ts: number}` | 回音测试 |
| `h5.getInfo` | - | `{page, name, version, userAgent, href, ts}` | 获取 H5 应用信息 |

### 标准事件

#### Flutter → H5 事件

| 事件名 | 数据格式 | 说明 |
|--------|----------|------|
| `user.login` | `{userId: number, username: string}` | 用户登录状态 |

#### H5 → Flutter 事件

| 事件名 | 数据格式 | 说明 |
|--------|----------|------|
| `page.ready` | `{ts: number, page: string}` | 页面加载完成 |
| `user.action` | `{action: string, target: string, data?: any}` | 用户操作事件 |

## 🚦 生命周期

### 1. 初始化流程

```
1. Flutter 启动本地 HTTP 服务器
   └── LocalhostServerManager.start()
   
2. WebView 组件初始化
   └── LocalH5WebView 创建
   
3. 加载 H5 应用
   └── http://127.0.0.1:PORT/<appName>/dist/index.html
   
4. 注入 AppBridge JavaScript SDK
   └── window.AppBridge 可用
   
5. 双向注册方法和事件监听器
   ├── Flutter: _bridge.register() / _bridge.onEvent()
   └── H5: AppBridge.register() / AppBridge.on()
   
6. H5 页面就绪
   └── H5 发送 page.ready 事件
   
7. Flutter 响应并建立连接
   └── 调用 page.getState 获取初始状态
```

### 2. 运行时交互

```
用户操作 → 方法调用/事件发送 → 对端处理 → 返回结果/触发监听器
```

### 3. 清理流程

```
1. 组件销毁时调用 dispose()
2. _bridge.detach() - 分离桥接器
3. _controller?.dispose() - 释放 WebView 控制器
4. 清理资源和监听器
```

## 🔒 错误处理

### 超时机制

所有方法调用都有默认超时时间（10秒），超时后会抛出 `TimeoutException`：

```dart
try {
  final result = await _bridge.invokeJs('some.method');
} on TimeoutException {
  print('调用超时');
} catch (e) {
  print('调用失败: $e');
}
```

### 错误传播

- JavaScript 错误会传播到 Flutter 端
- Flutter 错误会传播到 H5 端
- 所有错误都包含详细的错误信息和堆栈跟踪

### 错误处理示例

**Flutter 端：**

```dart
try {
  final result = await _bridge.invokeJs('nonexistent.method');
} catch (e) {
  // 处理错误
  setState(() {
    _errorMessage = '调用失败: $e';
  });
}
```

**H5 端：**

```javascript
try {
  const result = await window.AppBridge.invoke('nonexistent.method');
} catch (error) {
  console.error('调用失败:', error.message);
  // 显示错误信息给用户
}
```

## 🎨 UI 界面说明

应用界面采用左中右三栏布局：

### 左侧：Flutter 基座
- **接收 H5 消息区域**: 显示 H5 主动发送的消息和事件
- **接收 Flutter→H5 回复区域**: 显示 Flutter 调用 H5 方法后的返回结果
- **操作按钮**:
  - "获取 H5 应用信息" - 调用 `h5.getInfo`
  - "发送给H5" - 发送自定义消息到 H5

### 中间：交互指示器
- **蓝色右箭头**: Flutter → H5 的消息
- **绿色左箭头**: H5 → Flutter 的消息
- **实时显示当前传输的消息内容**

### 右侧：H5 应用
- **完整的 H5 应用界面**
- **消息展示区域**: 显示与 Flutter 的交互记录
- **操作按钮**:
  - "获取 App 版本信息" - 调用 Flutter 的 `app.getInfo`
  - "发送给 Flutter" - 发送自定义消息到 Flutter

## 🔧 开发指南

### 添加新的方法

**1. Flutter 端添加方法：**

```dart
_bridge.register('custom.method', (params) async {
  // 处理逻辑
  return {'result': 'success'};
});
```

**2. H5 端调用：**

```javascript
const result = await window.AppBridge.invoke('custom.method', {
  param1: 'value1'
});
```

### 添加新的事件

**1. 定义事件监听器：**

```dart
// Flutter 端
_bridge.onEvent('custom.event', (payload) {
  print('收到自定义事件: $payload');
});
```

```javascript
// H5 端
window.AppBridge.on('custom.event', function(payload) {
  console.log('收到自定义事件:', payload);
});
```

**2. 发送事件：**

```dart
// Flutter 发送
await _bridge.emitEventToJs('custom.event', {'data': 'value'});
```

```javascript
// H5 发送
window.AppBridge.emit('custom.event', {data: 'value'});
```

### 创建新的 H5 应用

**1. 创建目录结构：**

```
assets/h5/myapp/
└── dist/
    ├── index.html
    ├── app.js
    └── style.css
```

**2. 基本的 HTML 模板：**

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>我的应用</title>
    <link rel="stylesheet" href="style.css" />
  </head>
  <body>
    <main>
      <h1>我的 H5 应用</h1>
      <!-- 应用内容 -->
    </main>
    <script src="app.js"></script>
  </body>
</html>
```

**3. 基本的 JavaScript 模板：**

```javascript
document.addEventListener('DOMContentLoaded', function () {
  // 等待 AppBridge 就绪
  if (window.AppBridge) {
    // 注册方法
    window.AppBridge.register('myapp.getData', async function() {
      return { data: 'Hello from MyApp' };
    });
    
    // 发送就绪事件
    window.AppBridge.emit('page.ready', { 
      ts: Date.now(), 
      page: 'myapp' 
    });
  }
});
```

**4. 在 Flutter 中使用：**

```dart
LocalH5WebView(appName: 'myapp')
```

## 🔧 平台配置

### macOS 配置

在 macOS 平台上运行此应用需要配置网络权限和沙盒设置，以支持本地 HTTP 服务器和 WebView 加载。

#### 1. 网络传输安全配置

在 `macos/Runner/Info.plist` 中添加以下配置：

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoadsInWebContent</key>
  <true/>
  <key>NSAllowsLocalNetworking</key>
  <true/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>localhost</key>
    <dict>
      <key>NSIncludesSubdomains</key>
      <true/>
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
    <key>127.0.0.1</key>
    <dict>
      <key>NSIncludesSubdomains</key>
      <true/>
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
      <true/>
    </dict>
  </dict>
</dict>
```

**配置说明：**
- `NSAllowsArbitraryLoadsInWebContent`: 允许 WebView 加载任意内容
- `NSAllowsLocalNetworking`: 允许本地网络连接
- `NSExceptionDomains`: 为 localhost 和 127.0.0.1 添加 HTTP 加载异常

#### 2. 沙盒权限配置

在 `macos/Runner/DebugProfile.entitlements` 中添加：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

在 `macos/Runner/Release.entitlements` 中添加：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**权限说明：**
- `com.apple.security.app-sandbox`: 启用应用沙盒
- `com.apple.security.cs.allow-jit`: 允许 JIT 编译（调试模式需要）
- `com.apple.security.network.server`: 允许作为网络服务器运行
- `com.apple.security.network.client`: 允许网络客户端连接

#### 3. 配置验证

运行应用前，请确认：

1. ✅ Info.plist 中已添加 NSAppTransportSecurity 配置
2. ✅ entitlements 文件中已添加网络权限
3. ✅ WebView 能成功加载 `http://127.0.0.1:PORT/app1/dist/index.html`
4. ✅ 控制台无网络相关错误信息

#### 4. 常见问题

**Q: 出现 "App Transport Security" 错误**
A: 检查 Info.plist 中的 NSAppTransportSecurity 配置是否正确

**Q: 本地服务器无法启动**
A: 确认 entitlements 文件中已添加 `com.apple.security.network.server` 权限

**Q: WebView 无法加载本地内容**
A: 验证 `NSAllowsLocalNetworking` 和本地域名异常配置是否正确

## 📦 依赖项

确保在 `pubspec.yaml` 中添加必要的依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview: ^6.0.0
  package_info_plus: ^4.0.0

flutter:
  assets:
    - assets/h5/<appName>/dist/
```

## 🐛 常见问题

### Q: H5 页面加载失败？
A: 检查 `assets/h5/<appName>/dist/index.html` 目录结构和文件是否存在，确保 `flutter_inappwebview` 依赖已正确安装。

### Q: AppBridge 未定义？
A: 确保在 HTML 中的 JavaScript 代码在 `DOMContentLoaded` 事件中执行，并检查 AppBridge 是否已注入。

### Q: 方法调用超时？
A: 检查方法名是否正确注册，参数格式是否匹配，H5 端的异步方法是否正确返回。

### Q: 事件监听不生效？
A: 确保事件监听器在发送事件之前就已注册，检查事件名是否完全匹配。

## 📄 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目！

---

**🎯 快速上手建议：**
1. 先运行示例应用了解基本功能
2. 查看 `assets/h5/app1/dist/` 的代码实现
3. 参考 API 清单添加自己的方法和事件
4. 创建新的 H5 应用进行实践

## TODO
1.windows平台支持
2.H5 和app 单向通信示例