/**
 * Antigravity Remote Flutter InAppWebView 桥接脚本 (assets/agy_bridge.js)
 *
 * 1. 仅在非 Google 登录页的工作区页面运行，绝不干扰 accounts.google.com 登录表单与 CSP/TrustedTypes
 * 2. 支持穿透开放 Shadow DOM (querySelectorAllDeep)，适配 Google Boq/Wiz 组件树
 * 3. 提取真实消息流、当前激活模型 (Gemini 4 Argon / 3.8 Flash / Claude 5.5)、思考过程、工具调用胶囊、
 *    Implementation Plan 的单独 Proceed 确认按钮及敏感命令审批弹窗
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
    inputBox: 'textarea, [contenteditable="true"][role="textbox"], div[contenteditable="true"], rich-textarea textarea',
    sendButton: 'button[aria-label*="Send"], button[aria-label*="Submit"], button[aria-label*="Run"], button[type="submit"]',
    stopButton: 'button[aria-label*="Stop"], button[aria-label*="Cancel"], button[title*="Stop"]',
    newChatButton: 'button[aria-label*="New"], a[aria-label*="New"], button[title*="New"], button[aria-label*="Create"]',
    planProceedKeywords: ['proceed', 'proceed with plan', 'execute plan', 'approve plan', '继续执行计划', '批准计划'],
    approveKeywords: ['allow', 'allow once', 'always allow', 'approve', 'proceed', 'accept', 'run command', 'confirm', '允许', '确认', '继续'],
    denyKeywords: ['deny', 'reject', 'cancel', 'block', '拒绝', '取消']
  };

  function querySelectorAllDeep(selector, root) {
    const startRoot = root || document;
    const results = [];
    try {
      const direct = startRoot.querySelectorAll(selector);
      for (let i = 0; i < direct.length; i++) {
        results.push(direct[i]);
      }
      const allNodes = startRoot.querySelectorAll('*');
      for (let i = 0; i < allNodes.length; i++) {
        const sr = allNodes[i].shadowRoot;
        if (sr) {
          const nested = querySelectorAllDeep(selector, sr);
          for (let j = 0; j < nested.length; j++) {
            results.push(nested[j]);
          }
        }
      }
    } catch (_) {}
    return results;
  }

  function querySelectorDeep(selector) {
    const all = querySelectorAllDeep(selector, document);
    for (let i = 0; i < all.length; i++) {
      const el = all[i];
      if (!el.disabled && el.offsetParent !== null) {
        return el;
      }
    }
    return all[0] || null;
  }

  function detectUserEmail() {
    try {
      const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/;
      const candidates = querySelectorAllDeep(
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
    const hasInput = !!querySelectorDeep(s.inputBox);
    if (hasInput) return false;

    const linksAndBtns = querySelectorAllDeep(
      'a[href*="accounts.google.com"], button, a[role="button"]'
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

  function detectActiveModelAndThinking() {
    let detectedModel = '';
    let detectedThinking = '';
    try {
      const candidates = querySelectorAllDeep('button, [role="button"], [role="combobox"], span');
      for (const el of candidates) {
        if (el.offsetParent === null) continue;
        const txt = ((el.innerText || '') + ' ' + (el.getAttribute('aria-label') || '')).trim();
        if (!txt || txt.length > 80) continue;
        const lower = txt.toLowerCase();
        if (!detectedModel) {
          if (lower.includes('gemini 4 argon') || lower.includes('argon')) {
            detectedModel = 'Gemini 4 Argon';
          } else if (lower.includes('gemini 3.8 flash') || lower.includes('3.8 flash')) {
            detectedModel = 'Gemini 3.8 Flash';
          } else if (lower.includes('claude opus 5.5') || lower.includes('opus 5.5')) {
            detectedModel = 'Claude Opus 5.5 (Thinking)';
          } else if (lower.includes('claude sonnet 5.5') || lower.includes('sonnet 5.5')) {
            detectedModel = 'Claude Sonnet 5.5 (Thinking)';
          }
        }
        if (!detectedThinking) {
          if (/\bhigh\b/i.test(txt)) detectedThinking = 'High';
          else if (/\bmedium\b/i.test(txt)) detectedThinking = 'Medium';
          else if (/\blow\b/i.test(txt)) detectedThinking = 'Low';
          else if (/\bfast\b/i.test(txt)) detectedThinking = 'Fast';
        }
      }
    } catch (_) {}
    return {
      modelName: detectedModel || window.__agyPreferredModel || 'Gemini 4 Argon',
      thinkingLevel: detectedThinking || window.__agyPreferredThinking || 'High'
    };
  }

  function collectState() {
    const needsLogin = detectNeedsLogin();
    const userEmail = detectUserEmail();
    const s = window.__agySelectors;
    const hasInputBox = !!querySelectorDeep(s.inputBox);
    const stopBtn = querySelectorDeep(s.stopButton);
    const isGenerating = !!(stopBtn && !stopBtn.disabled && stopBtn.offsetParent !== null);
    const { modelName, thinkingLevel } = detectActiveModelAndThinking();
    const nodes = needsLogin ? [] : querySelectorAllDeep(s.messageContainer);

    const turns = [];
    nodes.forEach((node, idx) => {
      const text = (node.innerText || '').trim();
      if (!text) return;

      const isUser =
        (node.matches && node.matches(s.userIndicator)) ||
        !!(node.querySelector && node.querySelector(s.userIndicator)) ||
        (node.getAttribute('data-author') || '').toLowerCase() === 'user';

      let thinking = '';
      const thinkEl = node.querySelector ? node.querySelector(s.thinkingBlock) : null;
      if (thinkEl) thinking = (thinkEl.innerText || '').trim();

      const codeBlocks = [];
      if (node.querySelectorAll) {
        node.querySelectorAll('pre code, pre').forEach((pre) => {
          const c = (pre.innerText || '').trim();
          if (c && !codeBlocks.includes(c)) codeBlocks.push(c);
        });
      }

      const toolCalls = [];
      if (node.querySelectorAll) {
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
      }

      let body = text;
      if (thinking && body.startsWith(thinking)) {
        body = body.slice(thinking.length).trim();
      }

      const isLastAgentTurn = !isUser && idx === nodes.length - 1;
      turns.push({
        id: node.getAttribute('data-message-id') || `turn_${idx}`,
        role: isUser ? 'user' : 'agent',
        modelName: modelName,
        timestamp: '实时同步',
        thinking: thinking,
        thinkingDuration: isLastAgentTurn && isGenerating ? '思考中' : '2.4s',
        thinkingActive: isLastAgentTurn && isGenerating,
        content: body,
        toolCalls: toolCalls,
        codeBlocks: codeBlocks
      });
    });

    // 检测 Implementation Plan 的单独 Proceed 按钮，或敏感工具执行的 Approve/Deny 按钮对
    let planProceedBtn = null;
    let approveBtn = null;
    let denyBtn = null;
    if (!needsLogin) {
      const btns = querySelectorAllDeep('button, [role="button"]');
      for (const b of btns) {
        if (b.disabled || b.offsetParent === null) continue;
        const inner = (b.innerText || '').replace(/\s+/g, ' ').trim();
        const aria = (b.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim();
        const candidates = [inner.toLowerCase(), aria.toLowerCase()].filter(Boolean);

        for (const c of candidates) {
          if (
            !planProceedBtn &&
            s.planProceedKeywords.some((k) => c === k || c.endsWith(' ' + k) || c.startsWith(k + ' '))
          ) {
            planProceedBtn = b;
          }
          if (
            !approveBtn &&
            s.approveKeywords.some((k) => c === k || c.endsWith(' ' + k) || c.startsWith(k + ' '))
          ) {
            approveBtn = b;
          }
          if (
            !denyBtn &&
            s.denyKeywords.some((k) => c === k || c.endsWith(' ' + k) || c.startsWith(k + ' '))
          ) {
            denyBtn = b;
          }
        }
      }
    }

    let approval = { pending: false };
    if (planProceedBtn && !denyBtn) {
      window.__agyApproveBtn = planProceedBtn;
      window.__agyDenyBtn = null;
      const box = planProceedBtn.closest
        ? planProceedBtn.closest('[role="dialog"], article, section, div')
        : null;
      approval = {
        pending: true,
        approvalType: 'plan',
        commandOrFile: 'Implementation Plan 待审阅确认',
        summary: box
          ? (box.innerText || '').slice(0, 260).replace(/\s+/g, ' ').trim()
          : '云端 Agent 已生成实现计划 (Implementation Plan)，点击 Proceed 批准继续执行',
        approveLabel: (planProceedBtn.innerText || 'Proceed · 批准执行计划').trim(),
        denyLabel: '修改意见'
      };
    } else if (approveBtn && denyBtn) {
      window.__agyApproveBtn = approveBtn;
      window.__agyDenyBtn = denyBtn;
      const box = approveBtn.closest
        ? approveBtn.closest('[role="dialog"], article, section, div')
        : null;
      const codeEl = box && box.querySelector ? box.querySelector('code, pre') : null;
      approval = {
        pending: true,
        approvalType: 'tool',
        commandOrFile: codeEl ? (codeEl.innerText || '').trim() : 'Bash / File Tool Execution',
        summary: box
          ? (box.innerText || '').slice(0, 260).replace(/\s+/g, ' ').trim()
          : '云端 Agent 请求敏感命令或文件操作权限',
        approveLabel: (approveBtn.innerText || 'Proceed · 允许执行').trim(),
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
      isGenerating: isGenerating,
      activeModel: modelName,
      thinkingLevel: thinkingLevel,
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

  function clickButtonByKeywords(keywords) {
    const btns = querySelectorAllDeep('button, [role="button"], [role="menuitem"], [role="option"]');
    for (const b of btns) {
      if (b.disabled || b.offsetParent === null) continue;
      const txt = ((b.innerText || '') + ' ' + (b.getAttribute('aria-label') || '') + ' ' + (b.getAttribute('title') || '')).toLowerCase();
      if (keywords.some((k) => txt.includes(k.toLowerCase()))) {
        b.click();
        return true;
      }
    }
    return false;
  }

  const bridgeApi = {
    sendPrompt: function (text) {
      const el = querySelectorDeep(window.__agySelectors.inputBox);
      if (!el) return false;
      el.focus();
      if (el.tagName && (el.tagName.toLowerCase() === 'textarea' || el.tagName.toLowerCase() === 'input')) {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set;
        if (setter) setter.call(el, text);
        else el.value = text;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      } else {
        el.textContent = text;
        el.dispatchEvent(new InputEvent('input', { bubbles: true, data: text }));
      }
      setTimeout(() => {
        const btn = querySelectorDeep(window.__agySelectors.sendButton);
        if (btn && !btn.disabled) btn.click();
        else el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
        syncToFlutter(true);
      }, 80);
      return true;
    },
    stopGeneration: function () {
      const btn = querySelectorDeep(window.__agySelectors.stopButton);
      if (btn) {
        btn.click();
        setTimeout(() => syncToFlutter(true), 80);
        return true;
      }
      return false;
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
    setModelAndThinking: function (modelName, thinkingLevel) {
      window.__agyPreferredModel = modelName;
      window.__agyPreferredThinking = thinkingLevel;
      try {
        clickButtonByKeywords(['gemini', 'claude', 'model', 'argon', 'flash']);
        setTimeout(() => {
          clickButtonByKeywords([modelName]);
          if (thinkingLevel) {
            setTimeout(() => clickButtonByKeywords([thinkingLevel]), 120);
          }
          syncToFlutter(true);
        }, 120);
      } catch (_) {}
      syncToFlutter(true);
      return true;
    },
    openProjectSelector: function () {
      return clickButtonByKeywords(['project', 'repository', 'github', 'create project', 'new remote project']);
    },
    triggerAttachment: function (kind) {
      if (kind === 'upload') {
        const fileInput = querySelectorDeep('input[type="file"]');
        if (fileInput) {
          fileInput.click();
          return true;
        }
      }
      return clickButtonByKeywords([
        kind === 'drive' ? 'drive' : kind === 'github' ? 'github' : 'attach',
        'add resource',
        'upload'
      ]);
    },
    openPluginManager: function () {
      const clicked = clickButtonByKeywords(['customizations', 'marketplace', 'plugins', 'plugin']);
      if (!clicked) {
        this.sendPrompt('/plugin');
      }
      return true;
    },
    setFreeze: function () {},
    newSession: function () {
      const btn = querySelectorDeep(window.__agySelectors.newChatButton);
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
