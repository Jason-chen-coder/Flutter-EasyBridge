<template>
    <div ref="containerRef" id="editor-content-view" class="editor-content-view" v-html="html"></div>
</template>

<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'
import Prism from 'prismjs'
import katex from 'katex'
import 'prismjs/themes/prism.css'
import 'prismjs/components/prism-markup'
import 'prismjs/components/prism-javascript'
import 'prismjs/components/prism-typescript'
import 'prismjs/components/prism-json'
import 'prismjs/components/prism-css'

const props = defineProps<{
    html: string
}>()

const containerRef = ref<HTMLElement | null>(null)

const lastHtml = ref<string>()

const enhanceContent = () => {
    const el = containerRef.value
    if (!el) return

    // Skip work if HTML has not changed (Vue v-html already updated DOM)
    if (lastHtml.value === el.innerHTML) return
    lastHtml.value = el.innerHTML

    Prism.highlightAllUnder(el)

    const formulaNodes = el.querySelectorAll<HTMLElement>('span[data-w-e-type="formula"]')
    if (!formulaNodes.length) return

    formulaNodes.forEach(node => {
        const value = node.getAttribute('data-value') || ''
        try {
            katex.render(value, node, { throwOnError: false })
        } catch (err) {
            // ignore render errors to avoid breaking preview
            console.warn('katex render error', err)
        }
    })
}

onMounted(() => {
    enhanceContent()
})

watch(
    () => props.html,
    async () => {
        await nextTick()
        enhanceContent()
    }
)
</script>
<style>
.editor-content-view p,
.editor-content-view li {
    white-space: pre-wrap;
    /* 保留空格 */
}

.editor-content-view blockquote {
    border-left: 8px solid #d0e5f2;
    padding: 10px 10px;
    margin: 10px 0;
    background-color: #f1f1f1;
}

.editor-content-view code {
    font-family: monospace;
    background-color: #eee;
    padding: 3px;
    border-radius: 3px;
}

.editor-content-view pre>code {
    display: block;
    padding: 10px;
}

.editor-content-view table {
    border-collapse: collapse;
}

.editor-content-view td,
.editor-content-view th {
    border: 1px solid #ccc;
    min-width: 50px;
    height: 20px;
}

.editor-content-view th {
    background-color: #f1f1f1;
}

.editor-content-view ul,
.editor-content-view ol {
    padding-left: 20px;
}

.editor-content-view input[type="checkbox"] {
    margin-right: 5px;
}
</style>
<style lang="scss" scoped>
:deep(.editor-content-view) {
    line-height: 1.6;
    word-break: break-word;
}

:deep(.editor-content-view strong),
:deep(.editor-content-view b) {
    font-weight: 700;
}

/* 让预览里的表格好看一点（可选） */
:deep(.editor-content-view table) {
    border-collapse: collapse;
    width: 100%;
}

:deep(.editor-content-view td),
:deep(.editor-content-view th) {
    border: 1px solid #ddd;
    padding: 6px 8px;
    text-align: left;
}

:deep(div[data-w-e-type='link-card']) {
    margin: 12px auto;
    background-color: #f1f1f1;
    border-radius: 10px;
    display: flex;
    padding: 10px 20px;
    cursor: pointer;
    gap: 12px;
}

:deep(div[data-w-e-type='link-card'] .info-container) {
    flex: 1;
    padding-right: 12px;
}

:deep(div[data-w-e-type='link-card'] .info-container p) {
    margin-top: 5px;
    font-weight: bold;
}

:deep(div[data-w-e-type='link-card'] .info-container span) {
    opacity: 0.6;
}

:deep(div[data-w-e-type='link-card'] .icon-container) {
    width: 64px;
    min-width: 64px;
    height: 64px;
    overflow: hidden;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
}

:deep(div[data-w-e-type='link-card'] .icon-container img) {
    width: 100%;
    height: 100%;
    object-fit: contain;
}
</style>
