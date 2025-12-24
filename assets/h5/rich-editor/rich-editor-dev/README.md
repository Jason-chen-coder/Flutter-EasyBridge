# rich-editor

This template should help get you started developing with Vue 3 in Vite.

## Recommended IDE Setup

[VS Code](https://code.visualstudio.com/) + [Vue (Official)](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Recommended Browser Setup

- Chromium-based browsers (Chrome, Edge, Brave, etc.):
  - [Vue.js devtools](https://chromewebstore.google.com/detail/vuejs-devtools/nhdogjmejiglipccpnnnanhbledajbpd)
  - [Turn on Custom Object Formatter in Chrome DevTools](http://bit.ly/object-formatters)
- Firefox:
  - [Vue.js devtools](https://addons.mozilla.org/en-US/firefox/addon/vue-js-devtools/)
  - [Turn on Custom Object Formatter in Firefox DevTools](https://fxdx.dev/firefox-devtools-custom-object-formatters/)

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).

## Project Setup

```sh
npm install
```

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Compile and Minify for Production

```sh
npm run build
```

## URL 查询参数（RichEditor.vue）

- `local`: 设置语言，支持 `zh`/`zh-cn` 和 `en`（默认 `zh-CN`）。
- `preview`: 仅显示预览，不渲染编辑器；值 `1`/`true`/`yes` 视为开启。
- `showEditorPreview`: 在正常模式下是否显示右侧预览区；值 `1`/`true`/`yes` 视为开启。

示例：

- 预览模式 + 中文：`http://localhost:5173/?preview=1&local=zh`
- 显示预览区 + 英文：`http://localhost:5173/?showEditorPreview=1&local=en`

## AppBridge 交互事件与方法

在 H5 侧通过 `window.AppBridge` 注册：

### 方法

- `richEditor.setValueHtml(params)`: 设置内容。`params` 可为字符串或对象 `{ valueHtml | html | value }`。
- `richEditor.getValueHtml()`: 获取内容，返回 `{ valueHtml }`。
- `richEditor.setFullScreen(params)`: 控制全屏，布尔或对象 `{ isFullScreen | fullScreen | value }`，`true` 进入全屏，`false` 退出。

### 事件

- `richEditor.valueHtmlChanged`: 内容变更时发送，载荷 `{ valueHtml }`。
- `richEditor.fullScreenChange`: 全屏状态变更时发送，载荷 `{ isFullScreen }`。
