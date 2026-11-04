/**
 * Antigravity Remote Flutter InAppWebView 桥接脚本 (assets/agy_bridge.js)
 *
 * 1. 自动剥离网页毛玻璃、阴影动画及屏幕外 DOM 重绘开销
 * 2. 提取消息流、CoT 思考过程、工具调用胶囊 (Bash/Edit/Search) 及待确认权限弹窗
 * 3. 通过 flutter_inappwebview 的 callHandler('onAgyStateSync') 实时同步到 Flutter 原生渲染层
 */
(function () {
  if (window.__agyFlutterBridgeReady) return;
  window.__agyFlutterBridgeReady = true;

  window.__agySelectors = window.__agySelectors || {
    messageContainer: '[data-message-id], [role="article"], .message-row, .chat-turn, main article',
    userIndicator: '[data-role="user"], .user-message, [aria-label*="User"], [aria-label*="You"]',
    thinkingBlock: 'details, [data-thinking], .thinking-block, [aria-label*="Thinking"]',
    toolChip: '[data-tool-call], .tool-call-card, [aria-label*="Tool"], [aria-label*="Command"]',
    inputBox: 'textarea, [contenteditable="true"][role="textbox"], div[contenteditable="true"]',
    sendButton: 'button[aria-label*="Send"], button[aria-label*="Submit"], button[type="submit"]',
    approveKeywords: ['allow', 'approve', 'proceed', 'accept', 'run', 'confirm', '允许', '确认', '继续'],
    denyKeywords: ['deny', 'reject', 'cancel', 'block', '拒绝', '取消']
  };

  function applyPerformanceCss(freezeVisuals) {
    let style = document.getElementById('__agy_flutter_perf');
    if (!style) {
      style = document.createElement('style');
      style.id = '__agy_flutter_perf';
      document.head.appendChild(style);
    }
    style.textContent = `
      * {
        animation: none !important;
        transition: none !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        box-shadow: none !important;
      }
      article, [data-message-id], pre, code {
        content-visibility: auto !important;
        contain-intrinsic-size: 1px 100px !important;
      }
      ${freezeVisuals ? 'body > *:not(script) { content-visibility: hidden !important; }' : ''}
    `;
  }

  applyPerformanceCss(true);

  function collectState() {
    const isLogin = location.hostname.includes('accounts.google.com');
    const s = window.__agySelectors;
    const nodes = isLogin ? [] : Array.from(document.querySelectorAll(s.messageContainer));

    const turns = [];
    nodes.forEach((node, idx) => {
      const text = (node.innerText || '').trim();
      if (!text) return;

      const isUser =
        node.matches(s.userIndicator) ||
        !!node.querySelector(s.userIndicator) ||
        (node.getAttribute('data-author') || '').toLowerCase() === 'user';

      let thinking = '';
      const thinkEl = node.querySelector(s.thinkingBlock);
      if (thinkEl) thinking = (thinkEl.innerText || '').trim();

      const codeBlocks = [];
      node.querySelectorAll('pre code, pre').forEach((pre) => {
        const c = (pre.innerText || '').trim();
        if (c && !codeBlocks.includes(c)) codeBlocks.push(c);
      });

      const toolCalls = [];
      node.querySelectorAll(s.toolChip).forEach((chip, tIdx) => {
        const label = (chip.innerText || '').trim();
        if (label) {
          toolCalls.push({
            id: `tc_${idx}_${tIdx}`,
            type: label.toLowerCase().includes('edit') ? 'edit' : 'bash',
            title: label.split('\n')[0].slice(0, 60),
            detail: label,
            status: 'done'
          });
        }
      });

      let body = text;
      if (thinking && body.startsWith(thinking)) {
        body = body.slice(thinking.length).trim();
      }

      turns.push({
        id: node.getAttribute('data-message-id') || `turn_${idx}`,
        role: isUser ? 'user' : 'agent',
        modelName: 'Gemini 4 Argon',
        timestamp: '实时同步',
        thinking: thinking,
        thinkingDuration: '2.4s',
        content: body,
        toolCalls: toolCalls,
        codeBlocks: codeBlocks
      });
    });

    // 检测待审批按钮
    let approveBtn = null;
    let denyBtn = null;
    if (!isLogin) {
      const btns = Array.from(document.querySelectorAll('button, [role="button"]'));
      for (const b of btns) {
        if (b.disabled || b.offsetParent === null) continue;
        const lbl = ((b.innerText || '') + ' ' + (b.getAttribute('aria-label') || '')).toLowerCase().trim();
        if (!approveBtn && s.approveKeywords.some(k => lbl === k || lbl.startsWith(k + ' '))) approveBtn = b;
        if (!denyBtn && s.denyKeywords.some(k => lbl === k || lbl.startsWith(k + ' '))) denyBtn = b;
      }
    }

    let approval = { pending: false };
    if (approveBtn && denyBtn) {
      window.__agyApproveBtn = approveBtn;
      window.__agyDenyBtn = denyBtn;
      const box = approveBtn.closest('[role="dialog"], article, section, div');
      const codeEl = box ? box.querySelector('code, pre') : null;
      approval = {
        pending: true,
        commandOrFile: codeEl ? (codeEl.innerText || '').trim() : 'Bash / File Tool Execution',
        summary: box ? (box.innerText || '').slice(0, 260).replace(/\s+/g, ' ').trim() : '云端 Agent 请求执行权限',
        approveLabel: (approveBtn.innerText || '允许执行').trim(),
        denyLabel: (denyBtn.innerText || '拒绝').trim()
      };
    }

    return {
      url: location.href,
      title: document.title || 'Remote Agent',
      needsLogin: isLogin,
      turns: turns,
      approval: approval
    };
  }

  let scheduled = false;
  let lastJson = '';
  function syncToFlutter() {
    if (scheduled) return;
    scheduled = true;
    setTimeout(() => {
      scheduled = false;
      try {
        const state = collectState();
        const jsonStr = JSON.stringify(state);
        if (jsonStr !== lastJson) {
          lastJson = jsonStr;
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('onAgyStateSync', state);
          }
        }
      } catch (err) {}
    }, 80);
  }

  const obs = new MutationObserver(syncToFlutter);
  obs.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

  window.__agyFlutterControl = {
    sendPrompt: function (text) {
      const el = document.querySelector(window.__agySelectors.inputBox);
      if (!el) return false;
      el.focus();
      if (el.tagName.toLowerCase() === 'textarea' || el.tagName.toLowerCase() === 'input') {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set;
        if (setter) setter.call(el, text);
        else el.value = text;
        el.dispatchEvent(new Event('input', { bubbles: true }));
      } else {
        el.innerText = text;
        el.dispatchEvent(new InputEvent('input', { bubbles: true, data: text }));
      }
      setTimeout(() => {
        const btn = document.querySelector(window.__agySelectors.sendButton);
        if (btn && !btn.disabled) btn.click();
        else el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
        syncToFlutter();
      }, 60);
      return true;
    },
    resolveApproval: function (allow) {
      const btn = allow ? window.__agyApproveBtn : window.__agyDenyBtn;
      if (btn) {
        btn.click();
        setTimeout(syncToFlutter, 90);
        return true;
      }
      return false;
    },
    setFreeze: function (freeze) {
      applyPerformanceCss(!!freeze);
    }
  };

  syncToFlutter();
})();
