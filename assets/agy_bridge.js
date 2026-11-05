/**
 * Antigravity Remote Flutter InAppWebView 桥接脚本 (assets/agy_bridge.js)
 *
 * 1. 仅在非 Google 登录页的工作区页面运行，绝不干扰 accounts.google.com 登录表单与 CSP/TrustedTypes
 * 2. 不注入任何破坏网页布局或触发 TrustedTypes 的 style/innerHTML
 * 3. 提取消息流、CoT 思考过程、工具调用胶囊及待确认权限弹窗
 * 4. 暴露 window.AgyBridge 与 window.__agyFlutterControl 供 Flutter 原生层双向调用
 */
(function () {
  const host = (location.hostname || '').toLowerCase();
  if (
    host.includes('accounts.google.com') ||
    host.includes('myaccount.google.com') ||
    host.includes('ogs.google.com')
  ) {
    return;
  }

  if (window.__agyFlutterBridgeReady) {
    if (window.AgyBridge && window.AgyBridge.syncNow) {
      window.AgyBridge.syncNow();
    }
    return;
  }
  window.__agyFlutterBridgeReady = true;

  window.__agySelectors = window.__agySelectors || {
    messageContainer: '[data-message-id], [role="article"], .message-row, .chat-turn, main article',
    userIndicator: '[data-role="user"], .user-message, [aria-label*="User"], [aria-label*="You"]',
    thinkingBlock: 'details, [data-thinking], .thinking-block, [aria-label*="Thinking"]',
    toolChip: '[data-tool-call], .tool-call-card, [aria-label*="Tool"], [aria-label*="Command"]',
    inputBox: 'textarea, [contenteditable="true"][role="textbox"], div[contenteditable="true"]',
    sendButton: 'button[aria-label*="Send"], button[aria-label*="Submit"], button[type="submit"]',
    newChatButton: 'button[aria-label*="New"], a[aria-label*="New"], button[title*="New"], button[aria-label*="Create"]',
    approveKeywords: ['allow', 'approve', 'proceed', 'accept', 'run', 'confirm', '允许', '确认', '继续'],
    denyKeywords: ['deny', 'reject', 'cancel', 'block', '拒绝', '取消']
  };

  function detectUserEmail() {
    try {
      const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/;
      const candidates = document.querySelectorAll(
        '[aria-label*="@"], [title*="@"], [data-email], a[href*="SignOutOptions"], img[alt*="@"]'
      );
      for (const el of candidates) {
        const raw =
          (el.getAttribute('data-email') || '') +
          ' ' +
          (el.getAttribute('aria-label') || '') +
          ' ' +
          (el.getAttribute('title') || '') +
          ' ' +
          (el.getAttribute('alt') || '');
        const m = raw.match(emailRegex);
        if (m) return m[0];
      }
    } catch (_) {}
    return '';
  }

  function detectNeedsLogin() {
    const s = window.__agySelectors;
    const hasInput = !!document.querySelector(s.inputBox);
    if (hasInput) return false;

    const linksAndBtns = Array.from(
      document.querySelectorAll('a[href*="accounts.google.com"], button, a[role="button"]')
    );
    for (const el of linksAndBtns) {
      const href = (el.getAttribute('href') || '').toLowerCase();
      const txt = ((el.innerText || '') + ' ' + (el.getAttribute('aria-label') || '')).toLowerCase().trim();
      if (
        href.includes('accounts.google.com/servicelogin') ||
        href.includes('accounts.google.com/v3/signin') ||
        txt === 'sign in' ||
        txt === 'sign in with google' ||
        txt === '登录' ||
        txt === '使用 google 账号登录'
      ) {
        return true;
      }
    }
    return false;
  }

  function collectState() {
    const needsLogin = detectNeedsLogin();
    const userEmail = detectUserEmail();
    const s = window.__agySelectors;
    const hasInputBox = !!document.querySelector(s.inputBox);
    const nodes = needsLogin ? [] : Array.from(document.querySelectorAll(s.messageContainer));

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

    let approveBtn = null;
    let denyBtn = null;
    if (!needsLogin) {
      const btns = Array.from(document.querySelectorAll('button, [role="button"]'));
      for (const b of btns) {
        if (b.disabled || b.offsetParent === null) continue;
        const lbl = ((b.innerText || '') + ' ' + (b.getAttribute('aria-label') || '')).toLowerCase().trim();
        if (!approveBtn && s.approveKeywords.some((k) => lbl === k || lbl.startsWith(k + ' '))) approveBtn = b;
        if (!denyBtn && s.denyKeywords.some((k) => lbl === k || lbl.startsWith(k + ' '))) denyBtn = b;
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
        summary: box
          ? (box.innerText || '').slice(0, 260).replace(/\s+/g, ' ').trim()
          : '云端 Agent 请求执行权限',
        approveLabel: (approveBtn.innerText || '允许执行').trim(),
        denyLabel: (denyBtn.innerText || '拒绝').trim()
      };
    }

    return {
      url: location.href,
      host: location.hostname,
      title: document.title || 'Remote Agent',
      needsLogin: needsLogin,
      isAuthenticated: !needsLogin && (!!userEmail || hasInputBox),
      hasInputBox: hasInputBox,
      userEmail: userEmail,
      turns: turns,
      approval: approval
    };
  }

  let scheduled = false;
  let lastJson = '';
  function syncToFlutter(force) {
    if (scheduled && !force) return;
    scheduled = true;
    setTimeout(() => {
      scheduled = false;
      try {
        const state = collectState();
        const jsonStr = JSON.stringify(state);
        if (force || jsonStr !== lastJson) {
          lastJson = jsonStr;
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('onAgyStateSync', state);
          }
        }
      } catch (err) {}
    }, 80);
  }

  const obs = new MutationObserver(() => syncToFlutter(false));
  if (document.documentElement || document.body) {
    obs.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      characterData: true
    });
  }

  const bridgeApi = {
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
        el.textContent = text;
        el.dispatchEvent(new InputEvent('input', { bubbles: true, data: text }));
      }
      setTimeout(() => {
        const btn = document.querySelector(window.__agySelectors.sendButton);
        if (btn && !btn.disabled) btn.click();
        else el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
        syncToFlutter(true);
      }, 60);
      return true;
    },
    resolveApproval: function (allow) {
      const btn = allow ? window.__agyApproveBtn : window.__agyDenyBtn;
      if (btn) {
        btn.click();
        setTimeout(() => syncToFlutter(true), 90);
        return true;
      }
      return false;
    },
    approveTool: function () {
      return this.resolveApproval(true);
    },
    denyTool: function () {
      return this.resolveApproval(false);
    },
    setFreeze: function () {},
    newSession: function () {
      const btn = document.querySelector(window.__agySelectors.newChatButton);
      if (btn) {
        btn.click();
        setTimeout(() => syncToFlutter(true), 100);
        return true;
      }
      return false;
    },
    syncNow: function () {
      syncToFlutter(true);
    }
  };

  window.__agyFlutterControl = bridgeApi;
  window.AgyBridge = bridgeApi;

  syncToFlutter(true);
})();
