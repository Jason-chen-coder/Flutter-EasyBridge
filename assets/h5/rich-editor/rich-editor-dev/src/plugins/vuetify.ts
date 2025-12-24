import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import { md3 } from 'vuetify/blueprints'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
export const vuetifyConfig = createVuetify({
    defaults: {
        VBtn: {
            color: 'primary',
            rounded: 'xs',
            variant: 'flat',
        },
    },
    components,
    directives,
    blueprint: md3,
    theme: {
        defaultTheme: 'light',
        themes: {
            light: {
                dark: false,
                colors: {
                    'on-primary': '#FFFFFF',
                    primary: '#31DA9F',// 主色
                    secondary: '#424242',
                    accent: '#82B1FF',
                    error: '#FF5252',
                    info: '#2196F3',
                    success: '#4CAF50',
                    warning: '#FFC107',
                    customGreen: '#00C853', // 自定义颜色
                },
            },
            dark: {
                dark: true,
                colors: {
                    primary: '#90CAF9',
                    secondary: '#B0BEC5',
                    accent: '#FF4081',
                    error: '#FF5252',
                    info: '#2196F3',
                    success: '#4CAF50',
                    warning: '#FFC107',
                },
            },
        },
    },
})