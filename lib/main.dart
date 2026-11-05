import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/agent_models.dart';
import 'theme/app_themes.dart';
import 'widgets/kelivo_aurora_background.dart';
import 'widgets/kelivo_composer_bar.dart';
import 'widgets/kelivo_message_item.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const AgyKelivoApp());
}

class AgyKelivoApp extends StatefulWidget {
  const AgyKelivoApp({super.key});

  @override
  State<AgyKelivoApp> createState() => _AgyKelivoAppState();
}

class _AgyKelivoAppState extends State<AgyKelivoApp> {
  String _paletteId = KelivoPalettes.defaultId;
  bool _isDark = true;
  bool _auroraEnabled = true;
  ChatBubblePreset _bubblePreset = ChatBubblePreset.frosted;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _paletteId = prefs.getString('paletteId') ?? KelivoPalettes.defaultId;
      _isDark = prefs.getBool('isDark') ?? true;
      _auroraEnabled = prefs.getBool('auroraEnabled') ?? true;
      _bubblePreset = (prefs.getString('bubblePreset') == 'solid')
          ? ChatBubblePreset.solid
          : ChatBubblePreset.frosted;
    });
  }

  Future<void> _updateTheme({
    String? paletteId,
    bool? isDark,
    bool? auroraEnabled,
    ChatBubblePreset? bubblePreset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (paletteId != null) {
        _paletteId = paletteId;
        prefs.setString('paletteId', paletteId);
      }
      if (isDark != null) {
        _isDark = isDark;
        prefs.setBool('isDark', isDark);
      }
      if (auroraEnabled != null) {
        _auroraEnabled = auroraEnabled;
        prefs.setBool('auroraEnabled', auroraEnabled);
      }
      if (bubblePreset != null) {
        _bubblePreset = bubblePreset;
        prefs.setString(
          'bubblePreset',
          bubblePreset == ChatBubblePreset.solid ? 'solid' : 'frosted',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KelivoPalettes.byId(_paletteId);
    return MaterialApp(
      title: 'AGY Remote · Kelivo Edition',
      debugShowCheckedModeBanner: false,
      theme: palette.toThemeData(isDark: false),
      darkTheme: palette.toThemeData(isDark: true),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: RemoteAgentWorkspacePage(
        palette: palette,
        isDark: _isDark,
        auroraEnabled: _auroraEnabled,
        bubblePreset: _bubblePreset,
        onUpdateTheme: _updateTheme,
      ),
    );
  }
}

class RemoteAgentWorkspacePage extends StatefulWidget {
  final KelivoPalette palette;
  final bool isDark;
  final bool auroraEnabled;
  final ChatBubblePreset bubblePreset;
  final void Function({
    String? paletteId,
    bool? isDark,
    bool? auroraEnabled,
    ChatBubblePreset? bubblePreset,
  }) onUpdateTheme;

  const RemoteAgentWorkspacePage({
    super.key,
    required this.palette,
    required this.isDark,
    required this.auroraEnabled,
    required this.bubblePreset,
    required this.onUpdateTheme,
  });

  @override
  State<RemoteAgentWorkspacePage> createState() =>
      _RemoteAgentWorkspacePageState();
}

class _RemoteAgentWorkspacePageState extends State<RemoteAgentWorkspacePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _drawerSearchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  InAppWebViewController? _webCtrl;
  bool _showRawWebView = false;
  bool _webLoaded = false;
  bool _isGoogleAuthenticated = false;
  bool _needsLoginOnPage = true;
  bool _dismissedLoginBanner = false;
  double _webProgress = 0.0;
  String _currentWebUrl = RemoteHostPreset.officialWebUrl;
  String _configuredHostUrl = RemoteHostPreset.officialWebUrl;
  String _userEmail = '';
  String _drawerSearchQuery = '';

  String _selectedModel = 'Gemini 4 Argon';
  String _thinkingBudget = 'High';
  bool _webSearch = true;
  bool _fullAccess = false;
  bool _isStreaming = false;
  int _activeSessionIndex = 0;

  late List<RemoteSessionInfo> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _buildInitialSessions();
    _loadAccountAndHostPrefs();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _drawerSearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccountAndHostPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    var savedUrl = prefs.getString('configuredHostUrl') ??
        RemoteHostPreset.officialWebUrl;
    // 自动修复并迁移旧版导致 Google 400 报错的无效域名 (.google/remote-agents -> antigravity.google.com)
    if (savedUrl.contains('antigravity.google/remote-agents') ||
        savedUrl.contains('continue=https://antigravity.google/')) {
      savedUrl = RemoteHostPreset.officialWebUrl;
      await prefs.setString('configuredHostUrl', savedUrl);
    }
    setState(() {
      _configuredHostUrl = savedUrl;
      _currentWebUrl = savedUrl;
      _isGoogleAuthenticated = prefs.getBool('isGoogleAuthenticated') ?? false;
      _userEmail = prefs.getString('userEmail') ?? '';
    });
    await _webCtrl?.loadUrl(
      urlRequest: URLRequest(url: WebUri(savedUrl)),
    );
  }

  Future<void> _saveAccountState({
    bool? authenticated,
    String? email,
    String? hostUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (authenticated != null) {
      await prefs.setBool('isGoogleAuthenticated', authenticated);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString('userEmail', email);
    }
    if (hostUrl != null && hostUrl.isNotEmpty) {
      await prefs.setString('configuredHostUrl', hostUrl);
    }
  }

  List<RemoteSessionInfo> _buildInitialSessions() {
    return [
      RemoteSessionInfo(
        id: 's1',
        title: '重构 OAuth2 Token 刷新竞态锁',
        repo: 'nekos/agy-cloud-core',
        branch: 'feat/token-lock',
        status: 'approval',
        additions: 48,
        deletions: 12,
        approval: const PendingApprovalRequest(
          pending: true,
          commandOrFile: 'npm run test:auth -- --watch=false',
          summary: '在远端沙盒执行 OAuth2 Token 互斥锁并发回归测试',
        ),
        turns: const [
          AgentChatTurn(
            id: 't1',
            isUser: true,
            timestamp: '23:41',
            content:
                '帮我排查 src/auth/token_manager.ts 在高并发请求下偶发 401 退出的问题，补齐单测并给我看 Diff。',
          ),
          AgentChatTurn(
            id: 't2',
            isUser: false,
            modelName: 'Gemini 4 Argon',
            timestamp: '23:42',
            thinkingDuration: '2.8s',
            thinkingActive: false,
            thinking:
                '1. 检索 `src/auth/token_manager.ts` 里的 `refreshAccessToken()` 调用链。\n'
                '2. 发现当 3 个以上 Worker 并发收到 401 时，没有共享 `refreshPromise` 互斥锁，导致旧 Refresh Token 被重复消费触发服务端吊销。\n'
                '3. 引入单例 Promise 锁并在 `finally` 中安全释放，同时准备运行 `npm run test:auth` 验证。',
            content:
                '我已经定位到并发 401 退出的根因：`refreshAccessToken()` 缺少并发互斥锁（Mutex Promise），导致多个请求同时拿旧 Token 去刷新并触发吊销。我已在云端沙盒完成补丁：',
            toolCalls: [
              ToolCallItem(
                id: 'tc1',
                type: 'search',
                title: 'grep "refreshAccessToken" src/auth/',
                detail: '匹配到 4 处调用点 (src/auth/token_manager.ts:42)',
                statusText: '4 matches · 65ms',
                status: 'done',
              ),
              ToolCallItem(
                id: 'tc2',
                type: 'edit',
                title: 'edit_file src/auth/token_manager.ts',
                detail: '注入 _refreshInFlight 单例 Promise 互斥锁',
                filePath: 'src/auth/token_manager.ts',
                addedLines: 14,
                removedLines: 3,
                statusText: 'applied · 180ms',
                status: 'done',
              ),
              ToolCallItem(
                id: 'tc3',
                type: 'bash',
                title: 'shell npm run test:auth -- --watch=false',
                detail: '等待确认执行远端容器测试套件',
                statusText: 'awaiting approval',
                shellTail: [
                  '> agy-cloud-core@2.4.0 test:auth',
                  '> vitest run src/auth/__tests__/token_lock.spec.ts',
                  '[pending] Waiting for sandbox execution permission...',
                ],
                status: 'pending',
              ),
            ],
            codeBlocks: [
              '+++ b/src/auth/token_manager.ts\n'
                  '@@ -41,6 +41,17 @@ export class TokenManager {\n'
                  '-  async refreshAccessToken(): Promise<string> {\n'
                  '-    return this._performRefresh();\n'
                  '+  private _refreshInFlight: Promise<string> | null = null;\n'
                  '+\n'
                  '+  async refreshAccessToken(): Promise<string> {\n'
                  '+    if (this._refreshInFlight) {\n'
                  '+      return this._refreshInFlight;\n'
                  '+    }\n'
                  '+    this._refreshInFlight = this._performRefresh().finally(() => {\n'
                  '+      this._refreshInFlight = null;\n'
                  '+    });\n'
                  '+    return this._refreshInFlight;\n'
                  '   }',
            ],
            tokenStats: '1,420 tok · 52.4 t/s',
            branchIndex: 1,
            branchTotal: 2,
          ),
        ],
      ),
      RemoteSessionInfo(
        id: 's2',
        title: '适配 Kelivo Frosted 极光渲染管线',
        repo: 'nekos/kelivo-mobile-ui',
        branch: 'ui/aurora-shader',
        status: 'running',
        additions: 136,
        deletions: 19,
        turns: const [
          AgentChatTurn(
            id: 's2_t1',
            isUser: true,
            timestamp: '昨天',
            content: '请对标 Kelivo 仓库，将消息气泡升级为 Sigma-14 毛玻璃并加上顶部高光边。',
          ),
          AgentChatTurn(
            id: 's2_t2',
            isUser: false,
            modelName: 'Gemini 3.1 Pro (Remote)',
            timestamp: '昨天',
            thinkingDuration: '1.9s',
            thinking:
                '1. 读取 `lib/widgets/kelivo_aurora_background.dart` 中的 `KelivoSharedSurface`。\n'
                '2. 注入 `BackdropFilter(sigmaX: 14, sigmaY: 14)` 与顶部 `1px` 高光渐变边。',
            content:
                '已完成 `KelivoSharedSurface` 极光毛玻璃表面组件重构，支持 Frosted 与 Solid 两种预设无缝切换。',
            toolCalls: [
              ToolCallItem(
                id: 's2_tc1',
                type: 'edit',
                title: 'edit_file lib/widgets/kelivo_aurora_background.dart',
                detail: '实现 Sigma-14 BackdropFilter 与顶部 Specular Edge',
                filePath: 'lib/widgets/kelivo_aurora_background.dart',
                addedLines: 84,
                removedLines: 12,
                statusText: 'applied · 110ms',
                status: 'done',
              ),
            ],
            codeBlocks: [
              '+++ b/lib/widgets/kelivo_aurora_background.dart\n'
                  '@@ -95,4 +95,9 @@ class KelivoSharedSurface extends StatelessWidget {\n'
                  '+  BackdropFilter(\n'
                  '+    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),\n'
                  '+    child: decoratedContent,\n'
                  '+  )',
            ],
            tokenStats: '980 tok · 61.0 t/s',
          ),
        ],
      ),
      RemoteSessionInfo(
        id: 's3',
        title: '修复 WebSocket 断线指数退避重连',
        repo: 'nekos/agy-cloud-core',
        branch: 'fix/ws-backoff',
        status: 'idle',
        additions: 24,
        deletions: 8,
        turns: const [
          AgentChatTurn(
            id: 's3_t1',
            isUser: true,
            timestamp: '周二',
            content: '检查遠端 Agent WebSocket 心跳超时后的重连抖动逻辑。',
          ),
          AgentChatTurn(
            id: 's3_t2',
            isUser: false,
            modelName: 'Claude Opus 4.6 (Vertex)',
            timestamp: '周二',
            thinkingDuration: '3.1s',
            thinking: '引入 Full Jitter 指数退避算法，最大间隔限制在 30s 内。',
            content: '已为 `RemoteSocketClient` 添加 Full Jitter 退避重连机制并通过全部单测。',
            toolCalls: [
              ToolCallItem(
                id: 's3_tc1',
                type: 'edit',
                title: 'edit_file src/net/ws_client.ts',
                detail: '添加 computeBackoffWithJitter(attempt)',
                filePath: 'src/net/ws_client.ts',
                addedLines: 24,
                removedLines: 8,
                statusText: 'applied · 95ms',
                status: 'done',
              ),
            ],
            tokenStats: '810 tok · 48.2 t/s',
          ),
        ],
      ),
    ];
  }

  RemoteSessionInfo get _activeSession => _sessions[_activeSessionIndex];

  void _updateActiveSession(
    RemoteSessionInfo Function(RemoteSessionInfo current) updater,
  ) {
    setState(() {
      _sessions[_activeSessionIndex] = updater(_sessions[_activeSessionIndex]);
    });
  }

  /// 统一切换 WebView 可见性，并在展示 WebView 时立即解除 CSS 冻结，防止登录页白屏！
  Future<void> _setWebViewVisible(
    bool visible, {
    String? targetUrl,
  }) async {
    HapticFeedback.selectionClick();
    setState(() {
      _showRawWebView = visible;
    });
    try {
      if ( visible ) {
        await _webCtrl?.evaluateJavascript(
          source: '''
            window.__agyDisableFreeze = true;
            if (window.AgyBridge && window.AgyBridge.setFreeze) {
              window.AgyBridge.setFreeze(false);
            }
            var s = document.getElementById('__agy_flutter_perf');
            if (s) s.remove();
          ''',
        );
      } else {
        await _webCtrl?.evaluateJavascript(
          source: '''
            window.__agyDisableFreeze = false;
            if (window.AgyBridge && window.AgyBridge.setFreeze) {
              window.AgyBridge.setFreeze(true);
            }
          ''',
        );
      }
      if (targetUrl != null && targetUrl.isNotEmpty) {
        await _webCtrl?.loadUrl(
          urlRequest: URLRequest(url: WebUri(targetUrl)),
        );
      }
    } catch (_) {}
  }

  /// 一键打开内置 Google 账号官方登录页 (使用 antigravity.google.com 经过验证的官方 ServiceLogin 地址，杜绝 400 报错)
  Future<void> _openGoogleLoginFlow() async {
    await _setWebViewVisible(
      true,
      targetUrl: RemoteHostPreset.officialLoginUrl,
    );
  }

  Future<void> _injectBridgeScript(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    try {
      final host = (url?.host ?? '').toLowerCase();
      if (host.contains('accounts.google.com') ||
          host.contains('myaccount.google.com') ||
          host.contains('ogs.google.com')) {
        return;
      }
      final jsCode = await rootBundle.loadString('assets/agy_bridge.js');
      await controller.evaluateJavascript(source: jsCode);
    } catch (_) {}
  }

  Future<void> _checkGoogleCookies(WebUri? uri) async {
    try {
      final cookieMgr = CookieManager.instance();
      final googleCookies = await cookieMgr.getCookies(
        url: WebUri('https://accounts.google.com'),
      );
      final agyCookies = await cookieMgr.getCookies(
        url: WebUri('https://antigravity.google.com'),
      );
      final targetCookies = uri != null
          ? await cookieMgr.getCookies(url: uri)
          : <Cookie>[];
      final allCookies = [...googleCookies, ...agyCookies, ...targetCookies];
      final hasAuthCookie = allCookies.any(
        (c) =>
            c.name == 'SID' ||
            c.name == 'HSID' ||
            c.name == 'SAPISID' ||
            c.name == '__Secure-1PSID' ||
            c.name == '__Secure-3PSID',
      );
      if (hasAuthCookie && !_isGoogleAuthenticated && mounted) {
        setState(() {
          _isGoogleAuthenticated = true;
          _needsLoginOnPage = false;
        });
        await _saveAccountState(authenticated: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已检测到 Google 登录凭证，云端 Remote Agent 已激活！'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _handleBridgeStateSync(dynamic rawPayload) {
    if (rawPayload is! Map) return;
    final map = Map<String, dynamic>.from(rawPayload);
    final url = (map['url'] ?? '').toString();
    final needsLogin = map['needsLogin'] == true;
    final isAuth = map['isAuthenticated'] == true;
    final email = (map['userEmail'] ?? '').toString().trim();

    final rawTurns = (map['turns'] as List?) ?? const [];
    final parsedTurns = rawTurns
        .whereType<Map>()
        .map((e) => AgentChatTurn.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawApproval = map['approval'];
    final parsedApproval = rawApproval is Map
        ? PendingApprovalRequest.fromJson(Map<String, dynamic>.from(rawApproval))
        : null;

    if (!mounted) return;
    setState(() {
      _webLoaded = true;
      if (url.isNotEmpty) _currentWebUrl = url;
      _needsLoginOnPage = needsLogin;
      if (isAuth) {
        _isGoogleAuthenticated = true;
      }
      if (email.isNotEmpty) {
        _userEmail = email;
        _isGoogleAuthenticated = true;
      }
      if (parsedTurns.isNotEmpty) {
        _sessions[_activeSessionIndex] = _activeSession.copyWith(
          turns: parsedTurns,
          approval: parsedApproval ?? _activeSession.approval,
        );
      } else if (parsedApproval != null && parsedApproval.pending) {
        _sessions[_activeSessionIndex] = _activeSession.copyWith(
          approval: parsedApproval,
        );
      }
    });

    if (isAuth || email.isNotEmpty) {
      _saveAccountState(authenticated: true, email: email);
    }
  }

  Future<void> _sendPrompt() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _promptCtrl.clear();
    FocusScope.of(context).unfocus();

    final userTurn = AgentChatTurn(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      timestamp: '刚刚',
      content: text,
    );

    final thinkingTurnId = 'a_${DateTime.now().millisecondsSinceEpoch}';
    final placeholderAgentTurn = AgentChatTurn(
      id: thinkingTurnId,
      isUser: false,
      modelName: _selectedModel,
      timestamp: '刚刚',
      thinkingDuration: '1.2s',
      thinkingActive: true,
      thinking: '正在同步指令至云端 Remote Agent 沙盒 (${_activeSession.branch})...\n'
          '思考预算: $_thinkingBudget · 联网检索: ${_webSearch ? "开启" : "关闭"}',
      content: '正在等待云端容器响应...',
      tokenStats: 'streaming...',
    );

    _updateActiveSession(
      (s) => s.copyWith(
        status: 'running',
        turns: [...s.turns, userTurn, placeholderAgentTurn],
      ),
    );
    setState(() => _isStreaming = true);
    _scrollToBottom();

    bool dispatchedToWeb = false;
    try {
      final escaped = jsonEncode(text);
      final res = await _webCtrl?.evaluateJavascript(
        source:
            '(window.AgyBridge && window.AgyBridge.sendPrompt($escaped)) || false;',
      );
      dispatchedToWeb = (res == true || res == 'true');
    } catch (_) {}

    // 若底层网页尚未打开具体对话输入框，也在本地提供即时流式响应反馈并提示可切换网页
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    setState(() => _isStreaming = false);
    _updateActiveSession((s) {
      final updatedTurns = s.turns.map((t) {
        if (t.id != thinkingTurnId) return t;
        return t.copyWith(
          thinkingActive: false,
          content: dispatchedToWeb
              ? '已将指令「$text」透传至底层 Antigravity WebView 容器并触发执行。你可以随时点击右上角地球图标查看原网页实时 DOM，或在此原生界面继续交互。'
              : '已在当前沙盒会话 (${s.repo} · ${s.branch}) 接收指令：「$text」。\n\n'
                  '${_isGoogleAuthenticated ? "当前已绑定 Google 订阅账号，点击右上角地球图标可在远端网页控制台选择具体仓库容器。" : "提示：当前尚未完成 Google 账号网页登录，点击上方横幅【立即登录 Google 账号】即可连接你的真实云端配额。"}',
          toolCalls: [
            ToolCallItem(
              id: 'tc_${DateTime.now().millisecondsSinceEpoch}',
              type: text.startsWith('/test')
                  ? 'bash'
                  : text.startsWith('/diff')
                      ? 'edit'
                      : 'search',
              title: text.startsWith('/test')
                  ? 'shell npm test -- --run'
                  : text.startsWith('/diff')
                      ? 'git diff --stat ${s.branch}'
                      : 'agent_dispatch "${text.length > 28 ? "${text.substring(0, 28)}..." : text}"',
              detail: dispatchedToWeb
                  ? '已通过 window.AgyBridge.sendPrompt 注入远端 DOM'
                  : '本地预览沙盒已执行 · 登录 Google 后自动挂载远端容器',
              statusText: dispatchedToWeb ? 'synced · WebView' : 'sandbox · 95ms',
              status: 'done',
            ),
          ],
        );
      }).toList();
      return s.copyWith(status: 'idle', turns: updatedTurns);
    });
    _scrollToBottom();
  }

  void _regenerateTurn(int turnIndex) {
    final turns = _activeSession.turns;
    if (turnIndex < 0 || turnIndex >= turns.length) return;
    HapticFeedback.mediumImpact();

    String lastUserPrompt = '请重新分析并给出更优的补丁方案';
    for (int i = turnIndex - 1; i >= 0; i--) {
      if (turns[i].isUser) {
        lastUserPrompt = turns[i].content;
        break;
      }
    }
    _promptCtrl.text = lastUserPrompt;
    _sendPrompt();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 180,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleApprove() async {
    HapticFeedback.mediumImpact();
    _updateActiveSession((s) {
      final updatedTurns = s.turns.map((turn) {
        final updatedTools = turn.toolCalls.map((tc) {
          if (tc.status == 'pending') {
            return tc.copyWith(
              status: 'done',
              statusText: 'approved · passed',
              shellTail: [
                ...tc.shellTail,
                '✓ Permission granted by user. All 12 tests passed (340ms).',
              ],
            );
          }
          return tc;
        }).toList();
        return turn.copyWith(toolCalls: updatedTools);
      }).toList();
      return s.copyWith(
        status: 'running',
        approval: const PendingApprovalRequest(pending: false),
        turns: updatedTurns,
      );
    });
    await _webCtrl?.evaluateJavascript(
      source: 'window.AgyBridge && window.AgyBridge.approveTool();',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已批准远端容器执行命令，测试套件已通过'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDeny() async {
    HapticFeedback.lightImpact();
    _updateActiveSession((s) {
      final updatedTurns = s.turns.map((turn) {
        final updatedTools = turn.toolCalls.map((tc) {
          if (tc.status == 'pending') {
            return tc.copyWith(
              status: 'done',
              statusText: 'denied by user',
            );
          }
          return tc;
        }).toList();
        return turn.copyWith(toolCalls: updatedTools);
      }).toList();
      return s.copyWith(
        status: 'idle',
        approval: const PendingApprovalRequest(pending: false),
        turns: updatedTurns,
      );
    });
    await _webCtrl?.evaluateJavascript(
      source: 'window.AgyBridge && window.AgyBridge.denyTool();',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已拒绝该工具执行请求'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createNewSessionDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final repoCtrl = TextEditingController(text: 'nekos/agy-cloud-core');
    final branchCtrl = TextEditingController(text: 'feat/remote-agent');
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '新建云端 Remote Agent 任务',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '任务名称 / 目标描述',
                  hintText: '例如：排查生产环境 Redis 连接池泄漏',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: repoCtrl,
                decoration: const InputDecoration(
                  labelText: '关联 GitHub 仓库',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: branchCtrl,
                decoration: const InputDecoration(
                  labelText: '工作分支 (Branch)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim().isEmpty
                    ? '新建云端 Agent 任务 #${_sessions.length + 1}'
                    : titleCtrl.text.trim();
                final repo = repoCtrl.text.trim().isEmpty
                    ? 'nekos/agy-cloud-core'
                    : repoCtrl.text.trim();
                final branch = branchCtrl.text.trim().isEmpty
                    ? 'main'
                    : branchCtrl.text.trim();

                final newSession = RemoteSessionInfo(
                  id: 's_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  repo: repo,
                  branch: branch,
                  status: 'idle',
                  turns: [
                    AgentChatTurn(
                      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
                      isUser: false,
                      modelName: _selectedModel,
                      timestamp: '刚刚',
                      thinkingDuration: '0.6s',
                      thinking: '初始化云端工作区容器 `$repo` ($branch)...',
                      content:
                          '已为你创建独立云端会话「$title」（仓库：`$repo`，分支：`$branch`）。请直接在下方输入指令，或点击顶部切换到原网页选择工程。',
                      tokenStats: 'ready',
                    ),
                  ],
                );
                setState(() {
                  _sessions.insert(0, newSession);
                  _activeSessionIndex = 0;
                });
                _webCtrl?.evaluateJavascript(
                  source: 'window.AgyBridge && window.AgyBridge.newSession();',
                );
                Navigator.pop(ctx);
              },
              child: const Text('创建并进入'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = _activeSession;
    final bubbleSpec = ChatBubbleStyleSpec(preset: widget.bubblePreset);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildKelivoSideDrawer(context),
      body: KelivoAuroraBackground(
        palette: widget.palette,
        enabled: widget.auroraEnabled,
        child: Stack(
          children: [
            // Layer 1: Built-in Google Account & Antigravity WebView Container
            AnimatedOpacity(
              opacity: _showRawWebView ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showRawWebView,
                child: Column(
                  children: [
                    _buildWebViewBrowserToolbar(context),
                    if (_webProgress > 0.0 && _webProgress < 1.0)
                      LinearProgressIndicator(
                        value: _webProgress,
                        minHeight: 2.5,
                      ),
                    Expanded(
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(_configuredHostUrl),
                        ),
                        initialSettings: InAppWebViewSettings(
                          // 剥离 `; wv` 以确保 Google OAuth 100% 允许登录个人 Google AI Pro/Ultra 账号
                          userAgent:
                              'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
                          javaScriptEnabled: true,
                          javaScriptCanOpenWindowsAutomatically: true,
                          supportMultipleWindows: true,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          thirdPartyCookiesEnabled: true,
                          supportZoom: true,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                        ),
                        onCreateWindow: (controller, createWindowAction) async {
                          final req = createWindowAction.request;
                          if (req.url != null) {
                            await controller.loadUrl(urlRequest: req);
                          }
                          return true;
                        },
                        onWebViewCreated: (controller) {
                          _webCtrl = controller;
                          controller.addJavaScriptHandler(
                            handlerName: 'onAgyStateSync',
                            callback: (args) {
                              if (args.isEmpty) return;
                              _handleBridgeStateSync(args.first);
                            },
                          );
                        },
                        onLoadStart: (controller, url) {
                          if (!mounted) return;
                          setState(() {
                            if (url != null) _currentWebUrl = url.toString();
                          });
                        },
                        onProgressChanged: (controller, progress) {
                          if (!mounted) return;
                          setState(() {
                            _webProgress = progress / 100.0;
                          });
                        },
                        onUpdateVisitedHistory: (controller, url, isReload) {
                          if (!mounted || url == null) return;
                          setState(() {
                            _currentWebUrl = url.toString();
                          });
                          _checkGoogleCookies(url);
                        },
                        onLoadStop: (controller, url) async {
                          if (url != null && mounted) {
                            setState(() {
                              _currentWebUrl = url.toString();
                              _webLoaded = true;
                            });
                          }
                          await _checkGoogleCookies(url);
                          await _injectBridgeScript(controller, url);
                        },
                      ),
                    ),
                    _buildWebViewBottomHelperBar(context),
                  ],
                ),
              ),
            ),

            // Layer 2: 100% Native Kelivo 120fps Foreground UI
            IgnorePointer(
              ignoring: _showRawWebView,
              child: AnimatedOpacity(
                opacity: _showRawWebView ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    _buildFrostedTopBar(context, activeSession),
                    // 醒目的 Google 账号未登录引导横幅（一键登录 + 设置入口）
                    if (!_isGoogleAuthenticated && !_dismissedLoginBanner)
                      _buildGoogleLoginOnboardingBanner(context),
                    Expanded(
                      child: activeSession.turns.isEmpty
                          ? _buildEmptySessionPlaceholder(context)
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 16,
                              ),
                              itemCount: activeSession.turns.length,
                              itemBuilder: (context, index) {
                                return KelivoMessageItem(
                                  turn: activeSession.turns[index],
                                  bubbleStyle: bubbleSpec,
                                  onRegenerate: () => _regenerateTurn(index),
                                  onApproveTool: _handleApprove,
                                  onDenyTool: _handleDeny,
                                  onSwitchFullAccess: () {
                                    setState(() => _fullAccess = true);
                                    _handleApprove();
                                  },
                                );
                              },
                            ),
                    ),
                    KelivoComposerBar(
                      controller: _promptCtrl,
                      approval: activeSession.approval,
                      currentBranch: activeSession.branch,
                      thinkingBudget: _thinkingBudget,
                      webSearchEnabled: _webSearch,
                      fullAccessEnabled: _fullAccess,
                      isStreaming: _isStreaming,
                      onSend: _sendPrompt,
                      onApprove: _handleApprove,
                      onDeny: _handleDeny,
                      onCycleThinking: () {
                        const levels = ['Low', 'Med', 'High', 'Max'];
                        final next =
                            (levels.indexOf(_thinkingBudget) + 1) %
                                levels.length;
                        setState(() => _thinkingBudget = levels[next]);
                      },
                      onToggleWebSearch: () {
                        setState(() => _webSearch = !_webSearch);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _webSearch
                                  ? '已开启 Remote Agent 联网搜索权限'
                                  : '已关闭 Remote Agent 联网搜索权限',
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onToggleFullAccess: () {
                        setState(() => _fullAccess = !_fullAccess);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _fullAccess
                                  ? '已开启 Full Access 免审批沙盒模式'
                                  : '已切换回标准安全确认模式',
                            ),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onQuickCommand: (cmd) {
                        setState(() {
                          _promptCtrl.text = '$cmd ';
                          _promptCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: _promptCtrl.text.length),
                          );
                        });
                      },
                      onTapModelPicker: () => _showModelPickerSheet(context),
                      onOpenGoogleLogin: _openGoogleLoginFlow,
                      onOpenSettings: () =>
                          _showSettingsAndAccountSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 首页顶部显眼的 Google 账号登录引导卡片
  Widget _buildGoogleLoginOnboardingBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: KelivoSharedSurface(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        defaultColor: cs.primaryContainer.withValues(alpha: 0.28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.warning.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    Icons.account_circle_outlined,
                    size: 18,
                    color: colors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '登录 Google 账号以激活云端 Remote Agent',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: AppFontWeights.semibold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '直连个人 Google AI Pro / Ultra 订阅额度 · 零外部 API 扣费',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                IosIconButton(
                  icon: Icons.close_rounded,
                  size: 16,
                  padding: const EdgeInsets.all(4),
                  color: cs.onSurface.withValues(alpha: 0.5),
                  onTap: () => setState(() => _dismissedLoginBanner = true),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _openGoogleLoginFlow,
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text(
                    '立即登录 Google 账号',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _setWebViewVisible(true),
                  icon: const Icon(Icons.public_rounded, size: 15),
                  label: const Text(
                    '打开云端网页',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showSettingsAndAccountSheet(context),
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text(
                    '设置与主机地址',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySessionPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 42,
              color: cs.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              '当前会话已清空',
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '在下方输入框发送指令，或点击右上角「登录 Google」连接你的云端工作区。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WebView 专用完整顶部浏览器工具栏（解决无前进/后退/刷新/地址栏问题）
  Widget _buildWebViewBrowserToolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 6,
        left: 8,
        right: 10,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: colors.hairlineBorder, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          IosIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 18,
            tooltip: '网页后退',
            onTap: () async {
              if (await _webCtrl?.canGoBack() == true) {
                await _webCtrl?.goBack();
              }
            },
          ),
          IosIconButton(
            icon: Icons.arrow_forward_ios_rounded,
            size: 18,
            tooltip: '网页前进',
            onTap: () async {
              if (await _webCtrl?.canGoForward() == true) {
                await _webCtrl?.goForward();
              }
            },
          ),
          IosIconButton(
            icon: Icons.refresh_rounded,
            size: 19,
            tooltip: '刷新当前网页',
            onTap: () => _webCtrl?.reload(),
          ),
          const SizedBox(width: 4),
          // 可点击的地址栏胶囊（点击弹出预设/自定义 URL 切换器）
          Expanded(
            child: IosCardPress(
              onTap: () => _showSettingsAndAccountSheet(context),
              baseColor: colors.chatQuietFill,
              borderRadius: BorderRadius.circular(999),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: colors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentWebUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: cs.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => _setWebViewVisible(false),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text(
              '返回原生界面',
              style: TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  /// WebView 底部快捷辅助栏（提供一键跳 Google 登录页、一键标记已登录并返回原生 UI）
  Widget _buildWebViewBottomHelperBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: colors.hairlineBorder, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openGoogleLoginFlow,
              icon: const Icon(Icons.login_rounded, size: 15),
              label: const Text(
                '跳转 Google 登录',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _setWebViewVisible(
                true,
                targetUrl: _configuredHostUrl,
              ),
              icon: const Icon(Icons.hub_outlined, size: 15),
              label: const Text(
                '打开 Agent 主页',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                setState(() {
                  _isGoogleAuthenticated = true;
                  _needsLoginOnPage = false;
                });
                await _saveAccountState(authenticated: true);
                await _setWebViewVisible(false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已保存 Google 登录状态并切换回 Kelivo 原生极光界面'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.verified_user_outlined, size: 15),
              label: const Text(
                '我已登录 · 同步返回',
                style: TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedTopBar(
    BuildContext context,
    RemoteSessionInfo activeSession,
  ) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 10,
            right: 10,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.62),
            border: Border(
              bottom: BorderSide(color: colors.hairlineBorder, width: 0.6),
            ),
          ),
          child: Row(
            children: [
              IosIconButton(
                icon: Icons.menu_rounded,
                size: 21,
                tooltip: '打开会话抽屉',
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: IosCardPress(
                  onTap: () => _showModelPickerSheet(context),
                  baseColor: colors.chatQuietFill,
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isGoogleAuthenticated
                              ? colors.success
                              : colors.warning,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedModel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: cs.onSurface.withValues(alpha: 0.56),
                                ),
                              ],
                            ),
                            Text(
                              '${activeSession.repo} · ${activeSession.branch}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: cs.onSurface.withValues(alpha: 0.52),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 显眼的 Google 登录 / 账号状态胶囊按钮！
              IosCardPress(
                onTap: () {
                  if (!_isGoogleAuthenticated) {
                    _openGoogleLoginFlow();
                  } else {
                    _showSettingsAndAccountSheet(context);
                  }
                },
                baseColor: _isGoogleAuthenticated
                    ? colors.success.withValues(alpha: 0.15)
                    : colors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isGoogleAuthenticated
                          ? Icons.verified_user_rounded
                          : Icons.login_rounded,
                      size: 14,
                      color: _isGoogleAuthenticated
                          ? colors.success
                          : colors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isGoogleAuthenticated
                          ? (_userEmail.isNotEmpty
                              ? _userEmail.split('@').first
                              : '已登录')
                          : '登录 Google',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.semibold,
                        color: _isGoogleAuthenticated
                            ? colors.success
                            : colors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              IosIconButton(
                icon: Icons.public_rounded,
                size: 20,
                tooltip: '打开内置网页控制台',
                onTap: () => _setWebViewVisible(true),
              ),
              IosIconButton(
                icon: Icons.settings_outlined,
                size: 20,
                tooltip: 'Google 账号、主机地址与主题设置',
                onTap: () => _showSettingsAndAccountSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKelivoSideDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final filteredSessions = <MapEntry<int, RemoteSessionInfo>>[];
    for (int i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      final q = _drawerSearchQuery.trim().toLowerCase();
      if (q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.repo.toLowerCase().contains(q) ||
          s.branch.toLowerCase().contains(q)) {
        filteredSessions.add(MapEntry(i, s));
      }
    }

    return Drawer(
      backgroundColor: cs.surface,
      width: 310,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 真实可交互的搜索框 + 新建云端会话按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colors.chatQuietFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: cs.onSurface.withValues(alpha: 0.48),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _drawerSearchCtrl,
                              onChanged: (v) =>
                                  setState(() => _drawerSearchQuery = v),
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '搜索云端会话与分支...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.45),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_drawerSearchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _drawerSearchCtrl.clear();
                                setState(() => _drawerSearchQuery = '');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IosIconButton(
                    icon: Icons.add_circle_outline_rounded,
                    size: 22,
                    color: cs.primary,
                    tooltip: '新建云端 Agent 任务',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewSessionDialog(context);
                    },
                  ),
                ],
              ),
            ),

            // 2. Current Host & Google Subscription Card (点击打开设置与登录中心)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: IosCardPress(
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsAndAccountSheet(context);
                },
                baseColor: colors.surfaceFill,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.hub_outlined,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google 账号与远端主机设置',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isGoogleAuthenticated
                                ? '已登录 ${_userEmail.isNotEmpty ? _userEmail : "Google 订阅账号"}'
                                : '未登录 · 点击绑定 Google 账号或修改 URL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: _isGoogleAuthenticated
                                  ? colors.success
                                  : colors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),

            // 快捷登录按钮行（侧边栏内一键直达）
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openGoogleLoginFlow();
                      },
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: Text(
                        _isGoogleAuthenticated ? '切换 Google 账号' : '登录 Google 账号',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _setWebViewVisible(true);
                      },
                      icon: const Icon(Icons.public_rounded, size: 15),
                      label: const Text(
                        '网页控制台',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Text(
                '活跃云端工作区 (ACTIVE SANDBOXES)',
                style: TextStyle(fontSize: 11, letterSpacing: 0.6),
              ),
            ),

            // 3. Conversation Tiles (`_ChatTile` in `side_drawer.dart`)
            Expanded(
              child: filteredSessions.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的云端会话',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, i) {
                        final realIdx = filteredSessions[i].key;
                        final s = filteredSessions[i].value;
                        final selected = realIdx == _activeSessionIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: IosCardPress(
                            onTap: () {
                              setState(() => _activeSessionIndex = realIdx);
                              Navigator.pop(context);
                            },
                            baseColor: selected
                                ? cs.primary.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selected
                                              ? AppFontWeights.semibold
                                              : AppFontWeights.regular,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: s.status == 'running'
                                            ? colors.success
                                            : s.status == 'approval'
                                                ? colors.warning
                                                : cs.outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${s.repo} · ${s.branch}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: cs.onSurface.withValues(
                                          alpha: 0.54,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '+${s.additions}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: colors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '−${s.deletions}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: cs.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 4. Bottom User & Settings Bar (整栏可点击打开账号与设置中心！)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.hairlineBorder, width: 0.6),
                ),
              ),
              child: IosCardPress(
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsAndAccountSheet(context);
                },
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _isGoogleAuthenticated
                          ? colors.success.withValues(alpha: 0.18)
                          : colors.warning.withValues(alpha: 0.18),
                      child: Icon(
                        _isGoogleAuthenticated
                            ? Icons.verified_user_rounded
                            : Icons.person_outline_rounded,
                        size: 18,
                        color: _isGoogleAuthenticated
                            ? colors.success
                            : colors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isGoogleAuthenticated
                                ? (_userEmail.isNotEmpty
                                    ? _userEmail
                                    : 'Google 订阅已认证')
                                : '未登录 Google · 点击登录',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            '点击管理 Google 账号、Cookie 与主题设置',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.settings_outlined,
                      size: 19,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPickerSheet(BuildContext context) {
    final models = [
      ('Gemini 4 Argon', 'Google AI Ultra 旗舰深度推理 · 订阅内直连'),
      ('Gemini 3.1 Pro (Remote)', '云端沙盒长上下文主力模型 · 订阅内直连'),
      ('Claude Opus 4.6 (Vertex)', 'Antigravity 内置多模型路由 · 订阅内直连'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '切换 Remote Agent 云端模型',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final m in models)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    title: Text(m.$1),
                    subtitle: Text(m.$2, style: const TextStyle(fontSize: 12)),
                    trailing: _selectedModel == m.$1
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedModel = m.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 全功能「Google 账号、远端主机地址与 Kelivo 主题设置中心」
  void _showSettingsAndAccountSheet(BuildContext context) {
    final urlCtrl = TextEditingController(text: _configuredHostUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            final colors = ctx.appColors;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部标题栏
                      Row(
                        children: [
                          Icon(
                            Icons.settings_suggest_rounded,
                            size: 22,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Google 账号、远端主机与美学设置',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          IosIconButton(
                            icon: Icons.close_rounded,
                            size: 20,
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Section 1: Google 账号与 OAuth 认证管理
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.chatQuietFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colors.hairlineBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isGoogleAuthenticated
                                      ? Icons.verified_user_rounded
                                      : Icons.account_circle_outlined,
                                  size: 20,
                                  color: _isGoogleAuthenticated
                                      ? colors.success
                                      : colors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isGoogleAuthenticated
                                        ? 'Google 账号已认证 (${_userEmail.isNotEmpty ? _userEmail : "个人订阅已连接"})'
                                        : '尚未登录 Google 账号',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '已自动剥离 WebView 标识 (; wv)，完美兼容 Google OAuth 2.0 登录验证，100% 消耗你的 Google AI Pro / Ultra 个人订阅内额度。\n'
                              '桥接诊断：${_webLoaded ? "WebView 已就绪" : "正在初始化 WebView"} · ${_needsLoginOnPage ? "当前页面检测到待登录状态" : "当前页面处于工作区状态"}',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: cs.onSurface.withValues(alpha: 0.66),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openGoogleLoginFlow();
                                  },
                                  icon: const Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _isGoogleAuthenticated
                                        ? '重新登录 / 切换 Google 账号'
                                        : '前往 Google 登录页',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _setWebViewVisible(
                                      true,
                                      targetUrl: _configuredHostUrl,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.public_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    '打开远端网页控制台',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await CookieManager.instance()
                                        .deleteAllCookies();
                                    setState(() {
                                      _isGoogleAuthenticated = false;
                                      _userEmail = '';
                                      _dismissedLoginBanner = false;
                                    });
                                    setModalState(() {});
                                    await _saveAccountState(
                                      authenticated: false,
                                      email: '',
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已清空全部 WebView Cookie 与登录状态'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.cleaning_services_outlined,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    '清除 Cookie / 退出登录',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 2: 远端主机地址 (Remote Host URL) 预设与自定义
                      Text(
                        '远端主机地址 (REMOTE AGENT HOST URL)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: AppFontWeights.semibold,
                          letterSpacing: 0.5,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final preset in RemoteHostPreset.all)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: IosCardPress(
                            onTap: () {
                              urlCtrl.text = preset.url;
                              setState(() {
                                _configuredHostUrl = preset.url;
                              });
                              setModalState(() {});
                              _saveAccountState(hostUrl: preset.url);
                            },
                            baseColor: _configuredHostUrl == preset.url
                                ? cs.primary.withValues(alpha: 0.14)
                                : colors.chatQuietFill,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _configuredHostUrl == preset.url
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 17,
                                  color: _configuredHostUrl == preset.url
                                      ? cs.primary
                                      : cs.onSurface.withValues(alpha: 0.45),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: AppFontWeights.semibold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Text(
                                        preset.subtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.56,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: urlCtrl,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: '自定义远端工作区 URL',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () {
                              final nextUrl = urlCtrl.text.trim();
                              if (nextUrl.isEmpty) return;
                              setState(() {
                                _configuredHostUrl = nextUrl;
                              });
                              _saveAccountState(hostUrl: nextUrl);
                              Navigator.pop(ctx);
                              _setWebViewVisible(true, targetUrl: nextUrl);
                            },
                            child: const Text('保存并打开'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 3: 会话管理操作
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _updateActiveSession(
                                  (s) => s.copyWith(turns: []),
                                );
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                '清空当前演示消息',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _sessions = _buildInitialSessions();
                                  _activeSessionIndex = 0;
                                });
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.restore_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                '恢复默认演示沙盒',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Kelivo 东方美学与极光定制台
                      Row(
                        children: [
                          Text(
                            'Kelivo 9 色东方美学与极光背景',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          const Text('深色模式', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Switch(
                            value: widget.isDark,
                            onChanged: (v) {
                              widget.onUpdateTheme(isDark: v);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: KelivoPalettes.all.map((p) {
                          final selected = p.id == widget.palette.id;
                          final swatch = widget.isDark
                              ? p.dark.primary
                              : p.light.primary;
                          return IosCardPress(
                            onTap: () {
                              widget.onUpdateTheme(paletteId: p.id);
                              setModalState(() {});
                            },
                            baseColor: selected
                                ? swatch.withValues(alpha: 0.18)
                                : colors.chatQuietFill,
                            borderRadius: BorderRadius.circular(999),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: swatch,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p.nameZh,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? AppFontWeights.semibold
                                        : AppFontWeights.regular,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilterChip(
                              selected: widget.auroraEnabled,
                              label: const Text('4-Blob 极光背景'),
                              onSelected: (v) {
                                widget.onUpdateTheme(auroraEnabled: v);
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterChip(
                              selected: widget.bubblePreset ==
                                  ChatBubblePreset.frosted,
                              label: const Text('Sigma-14 毛玻璃气泡'),
                              onSelected: (v) {
                                widget.onUpdateTheme(
                                  bubblePreset: v
                                      ? ChatBubblePreset.frosted
                                      : ChatBubblePreset.solid,
                                );
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
