import { createI18n } from 'vue-i18n'
import en from '@/locales/en.json'
import zh from '@/locales/zh.json'

const messages = {
  en: en,
  zh: zh
}

// 从 URL 查询参数读取语言
const getLocaleFromUrl = () => {
  const params = new URLSearchParams(window.location.search)
  const urlLocale = params.get('locale')
  // 验证 locale 参数是否为有效值
  if (urlLocale && (urlLocale === 'en' || urlLocale === 'zh')) {
    return urlLocale
  }
  return null
}

// 从 localStorage 获取保存的语言，默认为中文
const getStoredLocale = () => {
  return localStorage.getItem('locale') || 'zh'
}

// 保存语言到 localStorage
const saveLocale = (locale) => {
  localStorage.setItem('locale', locale)
}

// 获取初始语言：优先级为 URL > localStorage > 默认值
const getInitialLocale = () => {
  const urlLocale = getLocaleFromUrl()
  if (urlLocale) {
    saveLocale(urlLocale) // 将 URL 中的语言保存到 localStorage
    return urlLocale
  }
  return getStoredLocale()
}

const i18n = createI18n({
  legacy: false, // composition API 模式
  locale: getInitialLocale(),
  fallbackLocale: 'zh',
  messages: messages,
  globalInjection: true,
  missingWarn: false,
  fallbackWarn: false
})

export { i18n, saveLocale }

