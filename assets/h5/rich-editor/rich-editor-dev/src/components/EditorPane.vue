<template>
    <div class="editor-shell">
        <Toolbar class="toolbar" :editor="editorRef" :defaultConfig="toolbarConfig" :mode="mode" />
        <Editor class="editor" v-model="innerValue" :defaultConfig="editorConfig" :mode="mode"
            @onCreated="handleCreated" />
    </div>
</template>

<script setup lang="ts">
import '@wangeditor/editor/dist/css/style.css'
import { shallowRef, ref, watch, onBeforeUnmount } from 'vue'
import { Editor, Toolbar } from '@wangeditor/editor-for-vue'
import { Boot, IEditorConfig, IToolbarConfig, IDomEditor } from '@wangeditor/editor'
import markdownModule from '@wangeditor/plugin-md'
import formulaModule from '@wangeditor/plugin-formula'
import linkCardModule from '@wangeditor/plugin-link-card'
// import { bgColorPickerMenu, textColorPickerMenu } from '../plugn/colorPickerMenus'

const props = withDefaults(
    defineProps<{
        modelValue: string
        mode?: string
    }>(),
    {
        mode: 'default'
    }
)

const emit = defineEmits<{
    (e: 'update:modelValue', value: string): void
    (e: 'editorReady', editor: IDomEditor): void
    (e: 'fullScreenChange', isFullScreen: boolean): void
}>()

// 注册插件（只注册一次）
let modulesRegistered = false
let menusRegistered = false
if (!modulesRegistered) {
    Boot.registerModule(markdownModule)
    Boot.registerModule(formulaModule)
    Boot.registerModule(linkCardModule)
    modulesRegistered = true
}
// if (!menusRegistered) {
//     Boot.registerMenu(bgColorPickerMenu)
//     Boot.registerMenu(textColorPickerMenu)
//     menusRegistered = true
// }

const editorRef = shallowRef<IDomEditor>()
const innerValue = ref(props.modelValue)

watch(
    () => props.modelValue,
    val => {
        if (val !== innerValue.value) {
            innerValue.value = val ?? ''
        }
    }
)

watch(innerValue, val => emit('update:modelValue', val))

const readFileAsDataUrl = (file: File) =>
    new Promise<string>((resolve, reject) => {
        const reader = new FileReader()
        reader.onload = () => resolve(reader.result as string)
        reader.onerror = () => reject(reader.error)
        reader.readAsDataURL(file)
    })

const toolbarConfig: Partial<IToolbarConfig> = {
    // insertKeys: {
    //     index: 9,
    //     keys: ['bgColorPicker', 'textColorPicker']
    // },
    excludeKeys: [
        'emotion',
        'group-video',
        'insertVideo',
        'uploadVideo'
    ]
}

const editorConfig: Partial<IEditorConfig> = {
    placeholder: '请输入内容...',
    hoverbarKeys: {
        formula: {
            menuKeys: ['editFormula']
        },
        link: {
            menuKeys: ['editLink', 'unLink', 'viewLink', 'convertToLinkCard']
        }
    },
    MENU_CONF: {
        uploadImage: {
            // Keep upload menu enabled by converting picked files to base64
            async customUpload(file: File, insertFn: (url: string, alt?: string) => void) {
                try {
                    const base64 = await readFileAsDataUrl(file)
                    insertFn(base64, file.name || '')
                } catch (err) {
                    console.error('图片读取失败', err)
                }
            }
        },
        convertToLinkCard: {
            async getLinkCardInfo(linkText: string, linkUrl: string) {
                const title = linkText?.trim() || linkUrl
                let iconImgSrc = ''
                try {
                    const url = new URL(linkUrl)
                    iconImgSrc = `${url.origin}/favicon.ico`
                } catch (err) {
                    // ignore invalid url
                }
                return { title, iconImgSrc }
            }
        }
    }
}

const handleCreated = (editor: any) => {
    editorRef.value = editor
    emit('editorReady', editor)
    editor.on('fullScreen', () => emit('fullScreenChange', true))
    editor.on('unFullScreen', () => emit('fullScreenChange', false))
}

onBeforeUnmount(() => {
    const editor = editorRef.value
    if (editor) editor.destroy()
})
</script>

<style scoped>
.editor-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
}

.toolbar {
    border-bottom: 1px solid #eee;
}

.editor {
    flex: 1;
    overflow: hidden;
}
</style>
