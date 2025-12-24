<template>
    <div class="raw-wrapper">
        <button class="copy-btn" type="button" @click="copyContent">{{ copied ? '已复制' : '复制' }}</button>
        <pre class="raw-content">{{ content }}</pre>
    </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useToast } from '@/plugins/toast'

const props = defineProps<{
    content: string
}>()

const copied = ref(false)
const toast = useToast()

const copyContent = async () => {
    if (!props.content) return
    try {
        if (navigator?.clipboard?.writeText) {
            await navigator.clipboard.writeText(props.content)
        } else {
            const textarea = document.createElement('textarea')
            textarea.value = props.content
            textarea.setAttribute('readonly', '')
            textarea.style.position = 'absolute'
            textarea.style.left = '-9999px'
            document.body.appendChild(textarea)
            textarea.select()
            document.execCommand('copy')
            document.body.removeChild(textarea)
        }
        copied.value = true
        toast.success('复制成功')
        window.setTimeout(() => (copied.value = false), 1500)
    } catch (error) {
        console.error('Copy failed', error)
    }
}
</script>

<style scoped lang="scss">
.raw-wrapper {
    position: relative;
    height: 100%;
}

.raw-content {
    margin: 0;
    line-height: 1.5;
    background: #fff;
    border: 1px solid #eee;
    border-radius: 6px;
    padding: 10px;
    white-space: pre-wrap;
    word-break: break-word;
    font-family: ui-monospace, SFMono-Regular, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New",
        monospace;
    color: #444;
    height: 100%;
    overflow: auto;
}

.copy-btn {
    position: absolute;
    right: 10px;
    top: 10px;
    background: #2d8cf0;
    color: #fff;
    border: none;
    padding: 6px 10px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 12px;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
    transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.copy-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.12);
}
</style>
