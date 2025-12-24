<template>
    <div class="split">
        <template v-if="previewOnly">
            <div class="pane preview-pane">
                <PreviewContent class="preview-content" :html="previewHtml" />
            </div>
        </template>
        <template v-else>
            <!-- 左：编辑区 -->
            <div class="pane editor-pane">
                <EditorPane v-model="valueHtml" :mode="mode" @editorReady="handleEditorReady"
                    @fullScreenChange="handleFullScreenChange" />
            </div>
            <!-- 右：预览区 -->
            <div v-if="showEditorPreview" class="pane preview-pane">
                <div class="preview-pane-content">
                    <div class="tab-header">
                        <button class="tab-btn" :class="{ active: activeTab === 'preview' }"
                            @click="activeTab = 'preview'">
                            实时预览
                        </button>
                        <button class="tab-btn" :class="{ active: activeTab === 'raw' }" @click="activeTab = 'raw'">
                            真实数据
                        </button>
                    </div>
                    <div class="tab-panel" v-if="activeTab === 'preview'">
                        <PreviewContent class="preview-content" :html="previewHtml" />
                    </div>
                    <div class="tab-panel" v-else>
                        <RawDataEcho class="raw-content" :content="valueHtml" />
                    </div>
                </div>
            </div>
        </template>
    </div>
</template>

<script setup lang="ts">
import '@wangeditor/editor/dist/css/style.css'
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { i18nChangeLanguage } from '@wangeditor/editor'
import type { IDomEditor } from '@wangeditor/editor'
import DOMPurify from 'dompurify'
import EditorPane from './EditorPane.vue'
import PreviewContent from './PreviewContent.vue'
import RawDataEcho from './RawDataEcho.vue'

// const valueHtml = ref(
//     `<p style="text-align: center;"><img src="https://cdn.vuetifyjs.com/docs/images/one/logos/vuetify-logo-light.png" alt="logo" data-href="https://cdn.vuetifyjs.com/docs/images/one/logos/vuetify-logo-light.png" style="width: 384.00px;height: 120.00px;"></p><h1 style="text-align: center;"><span style="color: rgb(231, 95, 51);">标题</span></h1><h2 style="text-align: center;"><span style="color: rgb(255, 255, 255); background-color: rgb(54, 88, 226);">标题A</span></h2><h3><u>标题A1</u></h3><p><strong>文本</strong></p><blockquote><em>文本</em></blockquote><p><s>文本</s></p><p>示例公式：<span data-w-e-type="formula" data-w-e-is-void data-w-e-is-inline data-value="c = \\pm\\sqrt{a^2 + b^2}"></span></p><p>示例链接： </p><div data-w-e-type="link-card" data-w-e-is-void data-title="https://vuetifyjs.com/en/" data-link="https://vuetifyjs.com/en/" data-iconImgSrc="https://vuetifyjs.com/favicon.ico">
//     <div class="info-container">
//       <div class="title-container"><p>https://vuetifyjs.com/en/</p></div>
//       <div class="link-container"><span>https://vuetifyjs.com/en/</span></div>
//     </div>
//     <div class="icon-container">
//       <img src="https://vuetifyjs.com/favicon.ico"/>
//     </div>
//   </div><p> </p><p>示例表格：</p><table style="width: 100%;"><tbody><tr><th colSpan="1" rowSpan="1" width="auto">姓名</th><th colSpan="1" rowSpan="1" width="auto">年龄</th></tr><tr><td colspan="1" rowspan="1" width="auto" style="text-align: center;">小明</td><td colspan="1" rowspan="1" width="auto" style="text-align: center;">6</td></tr><tr><td colspan="1" rowspan="1" width="auto" style="text-align: center;">小红</td><td colspan="1" rowspan="1" width="auto" style="text-align: center;">5</td></tr></tbody></table><p>示例代码：</p><pre><code class="language-javascript">let a = 1;</code></pre><p><br></p>`
// )
const valueHtml = ref('');
const activeTab = ref<'preview' | 'raw'>('preview')
const currentLang = ref<'zh-CN' | 'en'>('zh-CN')
const previewOnly = ref(false)
const showEditorPreview = ref(false)
const editorRef = ref<IDomEditor | null>(null)

const mode = 'default'

// 右侧预览内容
const previewHtml = computed(() => {
    const raw = valueHtml.value || ''
    return DOMPurify.sanitize(raw)
})

const detectLangFromUrl = () => {
    const params = new URLSearchParams(window.location.search)
    const local = params.get('local')?.toLowerCase()
    if (local === 'en') return 'en'
    if (local === 'zh' || local === 'zh-cn') return 'zh-CN'
    return 'zh-CN'
}

const detectPreviewFromUrl = () => {
    const params = new URLSearchParams(window.location.search)
    const preview = params.get('preview')?.toLowerCase()
    return preview === '1' || preview === 'true' || preview === 'yes'
}

const detectShowEditorPreviewFromUrl = () => {
    const params = new URLSearchParams(window.location.search)
    const preview = params.get('showEditorPreview')?.toLowerCase()
    return preview === '1' || preview === 'true' || preview === 'yes'
}

const BRIDGE_METHOD_SET = 'richEditor.setValueHtml'
const BRIDGE_METHOD_GET = 'richEditor.getValueHtml'
const BRIDGE_METHOD_CHANGED = 'richEditor.valueHtmlChanged'
const BRIDGE_METHOD_SET_FULLSCREEN = 'richEditor.setFullScreen'
const BRIDGE_EVENT_FULLSCREEN = 'richEditor.fullScreenChange'
let stopValueWatcher: (() => void) | null = null

const normalizeIncomingHtml = (payload: unknown) => {
    if (typeof payload === 'string') return payload
    if (payload && typeof payload === 'object') {
        const maybeObj = payload as Record<string, unknown>
        if (typeof maybeObj.valueHtml === 'string') return maybeObj.valueHtml
        if (typeof maybeObj.html === 'string') return maybeObj.html
        if (typeof maybeObj.value === 'string') return maybeObj.value
    }
    return ''
}

const registerBridgeMethods = () => {
    const bridge = (window as any).AppBridge
    if (!bridge || typeof bridge.register !== 'function') {
        console.warn('[RichEditor] AppBridge 未发现，暂不注册通信方法')
        return
    }

    bridge.register(BRIDGE_METHOD_SET, (params: unknown) => {
        console.log('[RichEditor] setValueHtml', params)
        valueHtml.value = normalizeIncomingHtml(params)
        return { success: true }
    })

    bridge.register(BRIDGE_METHOD_GET, () => {
        console.log('[RichEditor] getValueHtml', valueHtml.value)
        return { valueHtml: valueHtml.value }
    })

    bridge.register(BRIDGE_METHOD_SET_FULLSCREEN, (params: unknown) => {
        const editor = editorRef.value
        if (!editor) {
            return { success: false, message: 'editor not ready' }
        }
        const shouldFullScreen = (() => {
            if (typeof params === 'boolean') return params
            if (params && typeof params === 'object') {
                const p = params as Record<string, unknown>
                if (typeof p.isFullScreen === 'boolean') return p.isFullScreen
                if (typeof p.fullScreen === 'boolean') return p.fullScreen
                if (typeof p.value === 'boolean') return p.value
            }
            return false
        })()

        try {
            if (shouldFullScreen) {
                editor.fullScreen?.()
            } else {
                editor.unFullScreen?.()
            }
            return { success: true }
        } catch (err) {
            console.error('[RichEditor] setFullScreen failed', err)
            return { success: false, message: String(err) }
        }
    })

    // 当内容变更时通知 Flutter
    stopValueWatcher = watch(
        valueHtml,
        (html) => {
            bridge.emit(BRIDGE_METHOD_CHANGED, { valueHtml: html || '' })
        },
        { immediate: false }
    )
}

const unregisterBridgeMethods = () => {
    const bridge = (window as any).AppBridge
    if (!bridge || typeof bridge.unregister !== 'function') return
    if (typeof stopValueWatcher === 'function') {
        stopValueWatcher()
        stopValueWatcher = null
    }
    bridge.unregister(BRIDGE_METHOD_SET)
    bridge.unregister(BRIDGE_METHOD_GET)
    bridge.unregister(BRIDGE_METHOD_SET_FULLSCREEN)
}

const emitFullScreenChange = (isFullScreen: boolean) => {
    const bridge = (window as any).AppBridge
    if (!bridge || typeof bridge.emit !== 'function') {
        console.warn('[RichEditor] AppBridge 未发现，无法发送全屏事件')
        return
    }
    bridge.emit(BRIDGE_EVENT_FULLSCREEN, { isFullScreen })
}

const handleFullScreenChange = (isFullScreen: boolean) => {
    emitFullScreenChange(isFullScreen)
}

const handleEditorReady = (editor: IDomEditor) => {
    editorRef.value = editor
}

onMounted(() => {
    const lang = detectLangFromUrl()
    currentLang.value = lang
    previewOnly.value = detectPreviewFromUrl()
    showEditorPreview.value = detectShowEditorPreviewFromUrl()
    i18nChangeLanguage(lang)
    registerBridgeMethods()
})

onBeforeUnmount(() => {
    unregisterBridgeMethods()
})
</script>
<style src="@wangeditor/editor/dist/css/style.css"></style>

<style lang="scss" scoped>
.split {
    display: flex;
    width: 100%;
    height: 100vh;
    gap: 20px;
}

.pane {
    flex: 1;
    overflow: hidden;
    background: #fff;
    display: flex;
    flex-direction: column;
    min-width: 0;
}

.preview-pane-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 12px;
    overflow: auto;
}

.tab-header {
    display: inline-flex;
    background: #f5f5f5;
    border-radius: 8px;
    padding: 4px;
    gap: 6px;
    align-self: flex-start;
}

.tab-btn {
    border: none;
    background: transparent;
    padding: 8px 12px;
    border-radius: 6px;
    cursor: pointer;
    color: #555;
    font-weight: 600;
}

.tab-btn.active {
    background: #fff;
    color: #333;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

.tab-panel {
    flex: 1;
    border: 1px solid #f0f0f0;
    border-radius: 8px;
    padding: 10px;
    background: #fafafa;
    overflow: auto;
}
</style>
