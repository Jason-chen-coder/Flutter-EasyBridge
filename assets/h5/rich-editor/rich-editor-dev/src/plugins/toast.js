let toastInstance = null

export const useToast = () => {
  return {
    success: (message, timeout = 3000) => {
      if (toastInstance) {
        toastInstance.show({
          message,
          color: 'success',
          timeout,
        })
      }
    },
    error: (message, timeout = 3000) => {
      if (toastInstance) {
        toastInstance.show({
          message,
          color: 'error',
          timeout,
        })
      }
    },
    info: (message, timeout = 3000) => {
      if (toastInstance) {
        toastInstance.show({
          message,
          color: 'info',
          timeout,
        })
      }
    },
    warning: (message, timeout = 3000) => {
      if (toastInstance) {
        toastInstance.show({
          message,
          color: 'warning',
          timeout,
        })
      }
    },
    // 自定义 toast
    custom: (options) => {
      if (toastInstance) {
        toastInstance.show(options)
      }
    },
  }
}

// 注册 toast 实例
export const installToast = (app, instance) => {
  toastInstance = instance
  app.config.globalProperties.$toast = useToast()
}

