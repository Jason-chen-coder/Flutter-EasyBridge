document.addEventListener('DOMContentLoaded', function () {
  const infoBtn = document.getElementById('get-app-info-btn');
  const sendBtn = document.getElementById('send-to-flutter-btn');
  const inputEl = document.getElementById('h5-input');
  const fromFlutterList = document.getElementById('from-flutter-list');
  const repliesList = document.getElementById('flutter-replies-list');

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

  function appendItem(listEl, text, messageType = 'h5-to-flutter') {
    if (!listEl) return;
    
    // 检查是否需要自动滚动（只有在接近底部时才滚动）
    const shouldAutoScroll = (listEl.scrollTop + listEl.clientHeight) >= (listEl.scrollHeight - 100);
    
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
    
    const ts = document.createElement('span');
    ts.className = 'ts';
    ts.textContent = formatTs();
    
    header.appendChild(typeBadge);
    header.appendChild(ts);
    
    // Create payload
    const payload = document.createElement('div');
    payload.className = 'payload';
    payload.textContent = text;
    
    li.appendChild(header);
    li.appendChild(payload);
    
    listEl.appendChild(li);
    
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
      return { ready: true, ts: Date.now(), page: 'app1' };
    });
    window.AppBridge.register('page.echo', async function (params) {
      const text = params && params.message;
      appendItem(fromFlutterList, text, 'flutter-to-h5');
      return { reply: 'H5 已收到: ' + text, page: 'app1', ts: Date.now() };
    });
    window.AppBridge.register('h5.getInfo', async function () {
      const metaVersion = document.querySelector('meta[name="app-version"]')?.getAttribute('content');
      return {
        page: 'app1',
        name: document.title || 'H5 App1',
        version: metaVersion || '1.0.0',
        userAgent: navigator.userAgent,
        href: location.href,
        ts: Date.now(),
      };
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
      appendItem(repliesList, JSON.stringify(info), 'h5-to-flutter');
    } catch (e) {
      appendItem(repliesList, 'Error: ' + (e && e.message || e), 'h5-to-flutter');
    }
  });

  // H5 sends a message to Flutter and expects a reply
  sendBtn?.addEventListener('click', async function () {
    const text = (inputEl && typeof inputEl.value === 'string' ? inputEl.value : '').trim() || 'Hello from H5';
    try {
      const res = await window.AppBridge.invoke('page.h5ToFlutter', { message: text, from: 'app1' });
      appendItem(repliesList, JSON.stringify(res), 'h5-to-flutter');
      if (inputEl) inputEl.value = '';
    } catch (e) {
      appendItem(repliesList, 'Error: ' + (e && e.message || e), 'h5-to-flutter');
    }
  });
});