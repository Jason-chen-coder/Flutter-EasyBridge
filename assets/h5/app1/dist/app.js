document.addEventListener('DOMContentLoaded', function () {
  const infoBtn = document.getElementById('get-app-info-btn');
  const sendBtn = document.getElementById('send-to-flutter-btn');
  const pushBtn = document.getElementById('push-to-flutter-btn');
  const inputEl = document.getElementById('h5-input');
  const clearBtn = document.getElementById('clear-messages-btn');
  const unifiedMessageList = document.getElementById('unified-message-list');

  function pad2(n) { return String(n).padStart(2, '0'); }
  function formatTs(date = new Date()) {
    const y = date.getFullYear();
    const m = pad2(date.getMonth() + 1);
    const d = pad2(date.getDate());
    const h = pad2(date.getHours());
    const mi = pad2(date.getMinutes());
    const s = pad2(date.getSeconds());
    return `${y}-${m}-${d} ${h}:${mi}:${s}`;
  }

  function appendItem(text, messageType = 'h5-to-flutter', eventName = 'unknown') {
    if (!unifiedMessageList) return;
    
    // 检查是否需要自动滚动（只有在接近底部时才滚动）
    const shouldAutoScroll = (unifiedMessageList.scrollTop + unifiedMessageList.clientHeight) >= (unifiedMessageList.scrollHeight - 100);
    
    const li = document.createElement('li');
    li.className = 'item';
    
    // Check if it's an error message
    const isError = text.includes('Error:') || text.includes('error');
    if (isError) {
      li.classList.add('error');
    }
    
    // Create header with type badge and timestamp
    const header = document.createElement('div');
    header.className = 'item-header';
    
    const typeBadge = document.createElement('span');
    typeBadge.className = `item-type ${messageType}`;
    typeBadge.textContent = messageType === 'h5-to-flutter' ? '[H5 → Flutter]' : '[Flutter → H5]';
    
    // Add event name badge
    const eventBadge = document.createElement('span');
    eventBadge.className = 'event-name';
    eventBadge.textContent = eventName;
    
    const ts = document.createElement('span');
    ts.className = 'ts';
    ts.textContent = formatTs();
    
    header.appendChild(typeBadge);
    header.appendChild(eventBadge);
    header.appendChild(ts);
    
    // Create payload
    const payload = document.createElement('div');
    payload.className = 'payload';
    payload.textContent = text;
    
    li.appendChild(header);
    li.appendChild(payload);
    
    unifiedMessageList.appendChild(li);
    
    // 只有在需要时才自动滚动到底部
    if (shouldAutoScroll) {
      setTimeout(() => {
        li.scrollIntoView({ behavior: 'smooth', block: 'end' });
      }, 50);
    }
  }

  // Register methods (JS -> Flutter can invoke)
  if (window.AppBridge && typeof window.AppBridge.register === 'function') {
    window.AppBridge.register('page.getState', async function () {
      // 在接收消息列表中显示这个调用
      appendItem('Flutter 请求获取页面状态', 'flutter-to-h5', 'page.getState');
      
      const result = { ready: true, ts: Date.now(), page: 'app1' };
      
      // 显示返回的结果
      setTimeout(() => {
        appendItem(`页面状态: ${JSON.stringify(result)}`, 'flutter-to-h5', 'page.getState.response');
      }, 100);
      
      return result;
    });
    window.AppBridge.register('page.echo', async function (params) {
      const text = params && params.message;
      appendItem(text, 'flutter-to-h5', 'page.echo');
      return { reply: 'H5 已收到: ' + text, page: 'app1', ts: Date.now() };
    });
    window.AppBridge.register('h5.getInfo', async function () {
      // 在接收消息列表中显示这个调用
      appendItem('Flutter 请求获取 H5 应用信息', 'flutter-to-h5', 'h5.getInfo');
      
      const metaVersion = document.querySelector('meta[name="app-version"]')?.getAttribute('content');
      const result = {
        page: 'app1',
        name: document.title || 'H5 App1',
        version: metaVersion || '1.0.0',
        userAgent: navigator.userAgent,
        href: location.href,
        ts: Date.now(),
      };
      
      // 可选：也可以显示返回的结果
      setTimeout(() => {
        appendItem(`H5 应用信息: ${JSON.stringify(result)}`, 'flutter-to-h5', 'h5.getInfo.response');
      }, 100);
      
      return result;
    });
    
    // 注册接收 Flutter 推送消息的方法
    window.AppBridge.on('flutter.pushMessage', function (payload) {
      const message = payload && payload.message ? payload.message : JSON.stringify(payload);
      appendItem(`推送消息: ${message}`, 'flutter-to-h5', 'flutter.pushMessage');
    });
  }

  // Emit a fire-and-forget event (JS -> Flutter)
  if (window.AppBridge && typeof window.AppBridge.emit === 'function') {
    window.AppBridge.emit('page.ready', { ts: Date.now(), page: 'app1' });
  }

  // Optional: log capabilities
  if (window.AppBridge && typeof window.AppBridge.getCapabilities === 'function') {
    window.AppBridge.getCapabilities().then(function (cap) {
      console.log('Capabilities:', JSON.stringify(cap));
    }).catch(function (e) { console.warn('Capabilities error:', e); });
  }

  infoBtn?.addEventListener('click', async function () {
    try {
      const info = await window.AppBridge.invoke('app.getInfo');
      appendItem(JSON.stringify(info), 'h5-to-flutter', 'app.getInfo');
    } catch (e) {
      appendItem('Error: ' + (e && e.message || e), 'h5-to-flutter', 'app.getInfo');
    }
  });

  // H5 sends a message to Flutter and expects a reply
  sendBtn?.addEventListener('click', async function () {
    const text = (inputEl && typeof inputEl.value === 'string' ? inputEl.value : '').trim() || 'Hello from H5';
    try {
      const res = await window.AppBridge.invoke('page.h5ToFlutter', { message: text, from: 'app1' });
      appendItem(JSON.stringify(res), 'h5-to-flutter', 'page.h5ToFlutter');
      if (inputEl) inputEl.value = '';
    } catch (e) {
      appendItem('Error: ' + (e && e.message || e), 'h5-to-flutter', 'page.h5ToFlutter');
    }
  });

  // H5 推送消息给 Flutter (不等待回复)
  pushBtn?.addEventListener('click', function () {
    const message = `H5 推送消息 - ${formatTs()}`;
    try {
      if (window.AppBridge && typeof window.AppBridge.emit === 'function') {
        window.AppBridge.emit('h5.pushMessage', { 
          message: message,
          from: 'app1',
          timestamp: Date.now()
        });
        appendItem(`已推送: ${message}`, 'h5-to-flutter', 'h5.pushMessage');
      } else {
        appendItem('Error: AppBridge.emit not available', 'h5-to-flutter', 'h5.pushMessage');
      }
    } catch (e) {
      appendItem('Error: ' + (e && e.message || e), 'h5-to-flutter', 'h5.pushMessage');
    }
  });

  // 清空消息列表
  clearBtn?.addEventListener('click', function () {
    if (unifiedMessageList) {
      unifiedMessageList.innerHTML = '';
    }
  });
});