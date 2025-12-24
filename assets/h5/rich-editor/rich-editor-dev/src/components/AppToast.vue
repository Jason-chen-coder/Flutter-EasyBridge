<template>
  <v-snackbar v-model="state.show" :timeout="state.timeout" location="top" variant="flat" class="app-toast-wrapper"
    color="transparent">
    <div class="toast-container" :class="state.color">
      <div class="toast-content">
        <img v-if="state.iconSvg" :src="state.iconSvg" :alt="state.color" class="toast-icon" />
        <span class="toast-text" :title="state.message">{{ state.message }}</span>
      </div>
      <button class="toast-close-btn" @click="handleClose" aria-label="Close">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="18" y1="6" x2="6" y2="18"></line>
          <line x1="6" y1="6" x2="18" y2="18"></line>
        </svg>
      </button>
    </div>
  </v-snackbar>
</template>

<script setup>
import { reactive } from 'vue'
import icSuccess from '@/assets/svgs/ic_success.svg'
import icWarning from '@/assets/svgs/ic_warning.svg'
import icError from '@/assets/svgs/ic_warning_triangle.svg'

const state = reactive({
  show: false,
  message: '',
  color: 'success',
  iconSvg: icSuccess,
  timeout: 3000,
})

// 暴露全局方法
const show = (options = {}) => {
  const {
    message = '',
    color = 'success',
    timeout = 3000,
  } = options

  state.message = message
  state.color = color
  state.timeout = timeout

  // 根据 color 类型自动选择对应的 SVG 图标
  switch (color) {
    case 'error':
      state.iconSvg = icError
      break
    case 'warning':
      state.iconSvg = icWarning
      break
    case 'success':
    case 'info':
    default:
      state.iconSvg = icSuccess
      break
  }

  state.show = true
}

const hide = () => {
  state.show = false
}

const handleClose = () => {
  hide()
}

// 暴露方法给全局使用
defineExpose({
  show,
  hide,
})
</script>

<style scoped>
/* 隐藏 Snackbar 的默认背景 */
:deep(.app-toast-wrapper) {
  --snackbar-padding-x: 0 !important;
  --snackbar-padding-y: 0 !important;
  background-color: transparent !important;
}

:deep(.app-toast-wrapper .v-snackbar__content) {
  padding: 0 !important;
  background-color: transparent !important;
}

/* 主容器 - 类似Flutter的Container */
.toast-container {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background-color: #ffffff;
  border-radius: 24px;
  min-height: 46px;
  max-width: 560px;
  margin: 4px 0;
  padding: 0 24px;
}

/* 不同类型的背景颜色 */
.toast-container.error {
  background-color: #FDEDEE !important;
}

.toast-container.warning {
  background-color: #FDF7ED !important;
}

.toast-container.success {
  background-color: #EDFDF7 !important;
}

/* 内容区域（图标+文本） */
.toast-content {
  display: flex;
  align-items: center;
  padding-block: 10px;

  gap: 16px;
  flex: 1;
  min-width: 0;
}

/* 图标样式 */
.toast-icon {
  width: 30px;
  height: 30px;
  min-width: 30px;
  min-height: 30px;
  flex-shrink: 0;
}

/* 文本样式 */
.toast-text {
  color: #333333;
  font-size: 14px;
  line-height: 1.5;
  word-break: break-word;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
}

/* 关闭按钮 */
.toast-close-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  min-width: 32px;
  margin-left: 23px;
  background: none;
  border: none;
  cursor: pointer;
  color: #999999;
  padding: 0;
  border-radius: 50%;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.toast-close-btn:hover {
  background-color: rgba(0, 0, 0, 0.05);
  color: #666666;
}

.toast-close-btn:active {
  background-color: rgba(0, 0, 0, 0.1);
}

.toast-close-btn svg {
  stroke-linecap: round;
  stroke-linejoin: round;
}
</style>
