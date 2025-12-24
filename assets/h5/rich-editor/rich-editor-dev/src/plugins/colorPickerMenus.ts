import { createApp, h } from 'vue'
import { createVuetify } from 'vuetify'
import { VColorPicker } from 'vuetify/components'
import { DomEditor, IDomEditor, IDropPanelMenu } from '@wangeditor/editor'
import type { DOMElement } from '@wangeditor/editor/dist/editor/src/utils/dom'

type ColorMark = 'color' | 'bgColor'

const TEXT_COLOR_SVG =
    '<svg viewBox="0 0 1024 1024"><path d="M544.256 201.984l203.776 570.624h-77.44l-54.912-154.624H392.704l-54.912 154.624h-76.032l203.648-570.624h78.848z m-39.552 83.776h-1.536l-94.784 271.744h191.488l-95.168-271.744zM130.304 773.056h763.52v55.232h-763.52v-55.232z"></path></svg>'

const BG_COLOR_SVG =
    '<svg viewBox="0 0 1024 1024"><path d="M510.030769 315.076923l84.676923 196.923077h-177.230769l76.8-196.923077h15.753846zM945.230769 157.538462v708.923076c0 43.323077-35.446154 78.769231-78.769231 78.769231H157.538462c-43.323077 0-78.769231-35.446154-78.769231-78.769231V157.538462c0-43.323077 35.446154-78.769231 78.769231-78.769231h708.923076c43.323077 0 78.769231 35.446154 78.769231 78.769231z m-108.307692 643.938461L600.615385 216.615385c-5.907692-11.815385-15.753846-19.692308-29.538462-19.692308h-139.815385c-11.815385 0-23.630769 7.876923-27.56923 19.692308l-216.615385 584.861538c-3.938462 11.815385 3.938462 25.6 17.723077 25.6h80.738462c11.815385 0 23.630769-9.846154 27.56923-21.661538l63.015385-175.261539h263.876923l68.923077 175.261539c3.938462 11.815385 15.753846 21.661538 27.569231 21.661538h80.738461c13.784615 0 23.630769-13.784615 19.692308-25.6z"></path></svg>'

const DEFAULT_TEXT_COLOR = '#2c3e50'
const DEFAULT_BG_COLOR = '#ffffff'
const vuetify = createVuetify()

class ColorPickerMenu implements IDropPanelMenu {
    readonly title: string
    readonly tag = 'button'
    readonly iconSvg: string
    readonly showDropPanel = true
    private panelContentElemCache: DOMElement | null = null
    private dot?: HTMLDivElement
    private label?: HTMLSpanElement
    private pickerUpdater?: (val: string) => void
    private readonly mark: ColorMark
    private readonly defaultValue: string

    constructor(options: { title: string; iconSvg: string; mark: ColorMark; defaultValue: string }) {
        this.title = options.title
        this.iconSvg = options.iconSvg
        this.mark = options.mark
        this.defaultValue = options.defaultValue
    }

    private getMarkValue(editor: IDomEditor): string {
        const marks = (editor as any).marks as Record<string, unknown> | null | undefined
        if (marks && typeof marks[this.mark] === 'string' && marks[this.mark]) {
            return marks[this.mark] as string
        }

        const textNode = DomEditor.getSelectedTextNode(editor)
        const val = textNode && (textNode as any)[this.mark]
        if (typeof val === 'string' && val) return val
        return this.defaultValue
    }

    isActive(editor: IDomEditor): boolean {
        return false
    }

    getValue(editor: IDomEditor): string | boolean {
        return ''
    }

    isDisabled(editor: IDomEditor): boolean {
        return false
    }

    exec(editor: IDomEditor, value: string | boolean) {
        // DropPanel menu 不需要实现
    }

    private applyMark(editor: IDomEditor, value: string) {
        editor.addMark(this.mark, value)
        this.syncDisplay(editor)
    }

    private buildControl(editor: IDomEditor): HTMLDivElement {
        const wrapper = document.createElement('div')
        wrapper.style.display = 'flex'
        wrapper.style.flexDirection = 'column'
        wrapper.style.gap = '8px'
        wrapper.style.textAlign = 'left'

        const titleRow = document.createElement('div')
        titleRow.style.display = 'flex'
        titleRow.style.alignItems = 'center'
        titleRow.style.justifyContent = 'space-between'

        const title = document.createElement('div')
        title.textContent = this.mark === 'color' ? '当前文字颜色' : '当前背景颜色'
        title.style.fontSize = '12px'
        title.style.fontWeight = '600'
        title.style.color = '#444'

        const current = document.createElement('div')
        current.style.display = 'inline-flex'
        current.style.alignItems = 'center'
        current.style.gap = '6px'
        current.style.fontSize = '12px'
        current.style.color = '#666'

        const dot = document.createElement('div')
        dot.style.width = '16px'
        dot.style.height = '16px'
        dot.style.borderRadius = '4px'
        dot.style.border = '1px solid #ddd'

        const text = document.createElement('span')

        current.appendChild(dot)
        current.appendChild(text)
        titleRow.appendChild(title)
        titleRow.appendChild(current)

        const mountPoint = document.createElement('div')
    
        const apply = (val: string) => this.applyMark(editor, val)
        const pickerApp = createApp({
            data: () => ({ color: this.getMarkValue(editor) }),
            methods: {
                updateColor(val: string) {
                    this.color = val
                }
            },
            render() {
                return h(VColorPicker, {
                    modelValue: this.color,
                    'onUpdate:modelValue': (val: string) => {
                        this.color = val
                        apply(val)
                    },
                    mode: 'hexa',
                    showSwatches: false,
                    elevation: 0
                })
            }
        })

        pickerApp.use(vuetify)
        const vm = pickerApp.mount(mountPoint) as any
        this.pickerUpdater = (val: string) => vm.updateColor?.(val)

        this.dot = dot
        this.label = text

        wrapper.appendChild(titleRow)
        wrapper.appendChild(mountPoint)
        return wrapper
    }

    private syncDisplay(editor: IDomEditor) {
        const val = this.getMarkValue(editor)
        if (this.dot) this.dot.style.background = val
        if (this.label) this.label.textContent = val
        if (this.pickerUpdater) this.pickerUpdater(val)
    }

    getPanelContentElem(editor: IDomEditor): DOMElement {
        if (this.panelContentElemCache) {
            this.syncDisplay(editor)
            return this.panelContentElemCache
        }

        const container = document.createElement('div')
        container.style.padding = '10px'
        container.style.minWidth = '220px'
        container.style.display = 'flex'
        container.style.flexDirection = 'column'
        container.style.gap = '10px'

        const control = this.buildControl(editor)
        container.appendChild(control)

        this.panelContentElemCache = container as DOMElement
        this.syncDisplay(editor)
        return container as DOMElement
    }
}

export const textColorPickerMenu = {
    key: 'textColorPicker',
    factory() {
        return new ColorPickerMenu({
            title: '文字色',
            iconSvg: TEXT_COLOR_SVG,
            mark: 'color',
            defaultValue: DEFAULT_TEXT_COLOR
        })
    }
}

export const bgColorPickerMenu = {
    key: 'bgColorPicker',
    factory() {
        return new ColorPickerMenu({
            title: '背景色',
            iconSvg: BG_COLOR_SVG,
            mark: 'bgColor',
            defaultValue: DEFAULT_BG_COLOR
        })
    }
}
