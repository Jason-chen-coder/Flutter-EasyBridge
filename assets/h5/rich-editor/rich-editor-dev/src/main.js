import { createApp } from 'vue'
import App from './App.vue'
import { createVuetify } from 'vuetify'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import { vuetifyConfig } from './plugins/vuetify'

import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'
import 'katex/dist/katex.min.css'
import './assets/styles/main.css'
import { i18n } from './plugins/i18n'


const app = createApp(App)
app.use(i18n)
app.use(vuetifyConfig)
app.mount('#app')
