<script setup>
import RichEditor from './components/RichEditor.vue'
import AppToast from './components/AppToast.vue'
import { installToast } from './plugins/toast'
import { onMounted, ref, getCurrentInstance } from 'vue'
const toastRef = ref(null)

onMounted(() => {
  // 注册 toast 实例
  if (toastRef.value) {
    installToast(getCurrentInstance().appContext.app, toastRef.value)
  }

  if (window.as) {
    window.as.getCapabilities().then((capabilities) => {
      console.log('get alab studio capabilities:', JSON.stringify(capabilities))
    })
  }
})
</script>

<template>
  <RichEditor />
  <AppToast ref="toastRef" />
</template>

<style scoped>
header {
  line-height: 1.5;
}
</style>
