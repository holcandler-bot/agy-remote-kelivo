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
  static const String _kSessionsPrefKey = 'saved_sessions_v4';
  static const String _kActiveSessionIdxKey = 'active_session_idx_v4';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _drawerSearchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  InAppWebViewController? _webCtrl;
  bool _showRawWebView = false;
  bool _webLoaded = false;
  bool _isGoogleAuthenticated = false;
  bool _needsLoginOnPage = true;
  double _webProgress = 0.0;
  String? _webErrorDescription;
  String _currentWebUrl = RemoteHostPreset.officialWebUrl;
  String _configuredHostUrl = RemoteHostPreset.officialWebUrl;
  String _userEmail = '';
  String _drawerSearchQuery = '';
  DateTime? _lastBackPressTime;

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
    // 默认 100% 干净零假对话！不塞任何硬编码假会话
    _sessions = _buildCleanDefaultSessions();
    _loadAccountAndSessionsPrefs();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _drawerSearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<RemoteSessionInfo> _buildCleanDefaultSessions() {
    return const [
      RemoteSessionInfo(
        id: 's_default',
        title: '默认云端工作区',
        repo: 'antigravity.google.com',
        branch: 'main',
        status: 'idle',
        turns: [],
        approval: PendingApprovalRequest(pending: false),
      ),
    ];
  }

  /// 仅当用户在设置面板主动点击「加载 UI 演示样本」时才使用的预览样本
  List<RemoteSessionInfo> _buildDemoSampleSessions() {
    return [
      RemoteSessionInfo(
        id: 'demo_s1',
        title: '[演示样本] OAuth2 Token 互斥锁重构',
        repo: 'demo/agy-cloud-core',
        branch: 'feat/token-lock',
        status: 'approval',
        additions: 14,
        deletions: 3,
        approval: const PendingApprovalRequest(
          pending: true,
          commandOrFile: 'npm run test:auth -- --watch=false',
          summary: '在远端沙盒执行 OAuth2 Token 互斥锁并发回归测试',
        ),
        turns: const [
          AgentChatTurn(
            id: 'demo_t1',
            isUser: true,
            timestamp: '演示样本',
            content:
                '帮我排查 src/auth/token_manager.ts 在高并发请求下偶发 401 退出的问题，补齐单测并给我看 Diff。',
          ),
          AgentChatTurn(
            id: 'demo_t2',
            isUser: false,
            modelName: 'Gemini 4 Argon',
            timestamp: '演示样本',
            thinkingDuration: '2.8s',
            thinkingActive: false,
            thinking:
                '1. 检索 `src/auth/token_manager.ts` 里的 `refreshAccessToken()` 调用链。\n'
                '2. 发现当 3 个以上 Worker 并发收到 401 时，没有共享 `refreshPromise` 互斥锁。\n'
                '3. 引入单例 Promise 锁并在 `finally` 中安全释放。',
            content:
                '我已经定位到并发 401 退出的根因：`refreshAccessToken()` 缺少并发互斥锁（Mutex Promise）。以下是云端沙盒补丁预览：',
            toolCalls: [
              ToolCallItem(
                id: 'demo_tc1',
                type: 'search',
                title: 'grep "refreshAccessToken" src/auth/',
                detail: '匹配到 4 处调用点 (src/auth/token_manager.ts:42)',
                statusText: '4 matches · 65ms',
                status: 'done',
              ),
              ToolCallItem(
                id: 'demo_tc2',
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
                id: 'demo_tc3',
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
    ];
  }

  Future<void> _loadAccountAndSessionsPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    var savedUrl =
        prefs.getString('configuredHostUrl') ?? RemoteHostPreset.officialWebUrl;
    if (savedUrl.contains('antigravity.google/remote-agents') ||
        savedUrl.contains('continue=https://antigravity.google/')) {
      savedUrl = RemoteHostPreset.officialWebUrl;
      await prefs.setString('configuredHostUrl', savedUrl);
    }

    // 恢复本地持久化的用户会话与聊天记录
    List<RemoteSessionInfo>? loadedSessions;
    final rawSessionsJson = prefs.getString(_kSessionsPrefKey);
    if (rawSessionsJson != null && rawSessionsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSessionsJson);
        if (decoded is List && decoded.isNotEmpty) {
          loadedSessions = decoded
              .whereType<Map>()
              .map(
                (e) => RemoteSessionInfo.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
        }
      } catch (_) {}
    }

    final savedIdx = prefs.getInt(_kActiveSessionIdxKey) ?? 0;

    setState(() {
      _configuredHostUrl = savedUrl;
      _currentWebUrl = savedUrl;
      _isGoogleAuthenticated = prefs.getBool('isGoogleAuthenticated') ?? false;
      _userEmail = prefs.getString('userEmail') ?? '';
      if (loadedSessions != null && loadedSessions.isNotEmpty) {
        _sessions = loadedSessions;
        _activeSessionIndex =
            savedIdx.clamp(0, loadedSessions.length - 1);
      }
    });

    await _webCtrl?.loadUrl(
      urlRequest: URLRequest(url: WebUri(savedUrl)),
    );
  }

  Future<void> _persistSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_kSessionsPrefKey, encoded);
      await prefs.setInt(_kActiveSessionIdxKey, _activeSessionIndex);
    } catch (_) {}
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

  RemoteSessionInfo get _activeSession =>
      _sessions[_activeSessionIndex.clamp(0, _sessions.length - 1)];

  void _updateActiveSession(
    RemoteSessionInfo Function(RemoteSessionInfo current) updater,
  ) {
    setState(() {
      final idx = _activeSessionIndex.clamp(0, _sessions.length - 1);
      _sessions[idx] = updater(_sessions[idx]);
    });
    _persistSessions();
  }

  Future<void> _setWebViewVisible(
    bool visible, {
    String? targetUrl,
  }) async {
    HapticFeedback.selectionClick();
    setState(() {
      _showRawWebView = visible;
      if (visible) _webErrorDescription = null;
    });
    try {
      if (targetUrl != null && targetUrl.isNotEmpty) {
        await _webCtrl?.loadUrl(
          urlRequest: URLRequest(url: WebUri(targetUrl)),
        );
      } else if (!visible) {
        await _webCtrl?.evaluateJavascript(
          source: 'window.AgyBridge && window.AgyBridge.syncNow();',
        );
      }
    } catch (_) {}
  }

  Future<void> _syncModelAndThinkingToWeb(
    String modelName,
    String thinkingLevel,
  ) async {
    final normalizedModel = AgyModelCatalog.normalizeModelName(modelName);
    final normalizedThinking =
        AgyModelCatalog.normalizeThinkingLevel(normalizedModel, thinkingLevel);
    setState(() {
      _selectedModel = normalizedModel;
      _thinkingBudget = normalizedThinking;
    });
    try {
      final mJson = jsonEncode(normalizedModel);
      final tJson = jsonEncode(normalizedThinking);
      await _webCtrl?.evaluateJavascript(
        source:
            'window.AgyBridge && window.AgyBridge.setModelAndThinking($mJson, $tJson);',
      );
    } catch (_) {}
  }

  Future<void> _openCloudProjectResources() async {
    HapticFeedback.selectionClick();
    await _setWebViewVisible(true, targetUrl: _configuredHostUrl);
    try {
      await _webCtrl?.evaluateJavascript(
        source: 'window.AgyBridge && window.AgyBridge.openProjectSelector();',
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '已切入云端工作台 · 可直接选择或新建 Remote Project 并挂载 GitHub 仓库',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _attachGoogleDriveResource() async {
    HapticFeedback.selectionClick();
    await _setWebViewVisible(true);
    try {
      await _webCtrl?.evaluateJavascript(
        source:
            'window.AgyBridge && window.AgyBridge.triggerAttachment("drive");',
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '已打开云端工作台 · 请在 Project Resources 或输入栏中选择 Google Drive 文档',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _uploadLocalFileResource() async {
    HapticFeedback.selectionClick();
    await _setWebViewVisible(true);
    try {
      await _webCtrl?.evaluateJavascript(
        source:
            'window.AgyBridge && window.AgyBridge.triggerAttachment("upload");',
      );
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '已触发云端附件上传 (单文件最大 8 MiB，自动挂载至 /home/antigravity/upload)',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openMarketplacePlugins() async {
    HapticFeedback.selectionClick();
    try {
      await _webCtrl?.evaluateJavascript(
        source: 'window.AgyBridge && window.AgyBridge.openPluginManager();',
      );
    } catch (_) {}
    await _setWebViewVisible(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '已打开 Customizations / Plugins · 可一键授权 GitHub、Google Drive、Docs 等插件',
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
            content: Text('已检测到 Google 登录凭证，云端 Remote Agent 已就绪！'),
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
    final isGenerating = map['isGenerating'] == true;
    final email = (map['userEmail'] ?? '').toString().trim();
    final syncedModel = (map['activeModel'] ?? '').toString().trim();
    final syncedThinking = (map['thinkingLevel'] ?? '').toString().trim();

    final rawTurns = (map['turns'] as List?) ?? const [];
    final parsedTurns = rawTurns
        .whereType<Map>()
        .map((e) => AgentChatTurn.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawApproval = map['approval'];
    final parsedApproval = rawApproval is Map
        ? PendingApprovalRequest.fromJson(Map<String, dynamic>.from(rawApproval))
        : null;

    final rcLink = RemoteSessionInfo.tryParseRemoteControlUrl(url);

    if (!mounted) return;
    bool turnsChanged = false;
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
      if (syncedModel.isNotEmpty) {
        _selectedModel = AgyModelCatalog.normalizeModelName(syncedModel);
      }
      if (syncedThinking.isNotEmpty) {
        _thinkingBudget = AgyModelCatalog.normalizeThinkingLevel(
          _selectedModel,
          syncedThinking,
        );
      }
      if (rcLink != null && _activeSession.instanceId != rcLink.instanceId) {
        _sessions[_activeSessionIndex] = _activeSession.copyWith(
          mode: 'remote_control',
          instanceId: rcLink.instanceId,
          remoteUrl: rcLink.normalizedUrl,
          branch: rcLink.instanceId,
        );
        turnsChanged = true;
      }
      if (parsedTurns.isNotEmpty) {
        _isStreaming = isGenerating;
        _sessions[_activeSessionIndex] = _activeSession.copyWith(
          status: isGenerating ? 'running' : 'idle',
          turns: parsedTurns,
          approval: parsedApproval ?? _activeSession.approval,
        );
        turnsChanged = true;
      } else if (parsedApproval != null) {
        _sessions[_activeSessionIndex] = _activeSession.copyWith(
          approval: parsedApproval,
        );
        turnsChanged = true;
      }
    });

    if (turnsChanged) {
      _persistSessions();
    }
    if (isAuth || email.isNotEmpty) {
      _saveAccountState(authenticated: true, email: email);
    }
  }

  Future<void> _stopStreaming() async {
    HapticFeedback.mediumImpact();
    setState(() => _isStreaming = false);
    try {
      await _webCtrl?.evaluateJavascript(
        source: 'window.AgyBridge && window.AgyBridge.stopGeneration();',
      );
    } catch (_) {}
    _updateActiveSession((s) {
      final updated = s.turns.map((t) {
        if (t.thinkingActive) {
          return t.copyWith(
            thinkingActive: false,
            content: '${t.content}\n[已由用户手动中断]',
            tokenStats: 'stopped',
          );
        }
        return t;
      }).toList();
      return s.copyWith(status: 'idle', turns: updated);
    });
  }

  Future<void> _sendPrompt() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;

    // 1. 若尚未登录 Google 账号，绝不伪造假 AI 回复，而是保留输入并引导一键登录
    if (!_isGoogleAuthenticated) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先登录 Google 账号以连接云端 Remote Agent'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '立即登录',
            onPressed: _openGoogleLoginFlow,
          ),
        ),
      );
      return;
    }

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
      thinkingDuration: '实时连接',
      thinkingActive: true,
      thinking: '正在向 antigravity.google.com 透传指令 (${_activeSession.branch})...',
      content: '正在等待云端 Remote Agent 响应...',
      tokenStats: 'connecting...',
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

    if (dispatchedToWeb) {
      // 成功注入网页端聊天框，交由 onAgyStateSync 实时同步真实 DOM 消息流与 isGenerating 状态；
      // 若 4.5s 后网页 DOM 尚未被解析为独立 turn，则更新占位说明但保留用户随时点【网页】查看实景的入口
      await Future.delayed(const Duration(milliseconds: 4500));
      if (!mounted) return;
      final stillPlaceholder =
          _activeSession.turns.any((t) => t.id == thinkingTurnId);
      if (!stillPlaceholder) return;
      setState(() => _isStreaming = false);
      _updateActiveSession((s) {
        final updated = s.turns.map((t) {
          if (t.id != thinkingTurnId) return t;
          return t.copyWith(
            thinkingActive: false,
            content:
                '指令已送达云端工作台并开始执行！若当前长任务包含复杂沙盒终端输出或 Implementation Plan，可点击顶栏右侧【网页】切入实景控制台。',
            tokenStats: 'running on cloud',
          );
        }).toList();
        return s.copyWith(status: 'idle', turns: updated);
      });
    } else {
      // 当前云端网页正处于项目列表/欢迎页（尚无聊天输入框），自动帮用户复制指令并诚实引导进入网页选择项目
      await Clipboard.setData(ClipboardData(text: text));
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _isStreaming = false);
      _updateActiveSession((s) {
        final updated = s.turns.map((t) {
          if (t.id != thinkingTurnId) return t;
          return t.copyWith(
            thinkingActive: false,
            content:
                '当前云端网页（`antigravity.google.com`）正停留在项目选择页或欢迎页，尚未进入具体会话的输入框。\n\n'
                '已为您将刚才输入的指令自动复制到剪贴板，请点击右上角【网页】按钮进入云端控制台选择或新建一个 Remote Project，随后直接粘贴发送即可。',
            tokenStats: 'copied to clipboard',
          );
        }).toList();
        return s.copyWith(status: 'idle', turns: updated);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('指令已复制！请先在云端网页中选择或创建一个项目'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '打开云端网页',
            onPressed: () => _setWebViewVisible(true),
          ),
        ),
      );
    }
    _scrollToBottom();
  }

  void _regenerateTurn(int turnIndex) {
    final turns = _activeSession.turns;
    if (turnIndex < 0 || turnIndex >= turns.length) return;
    HapticFeedback.mediumImpact();

    String lastUserPrompt = '';
    for (int i = turnIndex - 1; i >= 0; i--) {
      if (turns[i].isUser) {
        lastUserPrompt = turns[i].content;
        break;
      }
    }
    if (lastUserPrompt.isEmpty) return;
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
                '✓ Permission granted by user.',
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
        content: Text('已向云端容器发送允许执行指令'),
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

  Future<void> _openRemoteControlLinkDialog(BuildContext context) async {
    final clipData = await Clipboard.getData('text/plain');
    final clipText = (clipData?.text ?? '').trim();
    final detected = RemoteSessionInfo.tryParseRemoteControlUrl(clipText);
    final linkCtrl = TextEditingController(
      text: detected?.normalizedUrl ?? '',
    );
    final titleCtrl = TextEditingController(
      text: detected != null ? '远程主机 · ${detected.instanceId}' : '',
    );
    if (!context.mounted) return;
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.desktop_windows_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Remote Control · 接管本机电脑',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '在电脑终端运行 `agy --remote-control`、`/remote-control` 或守护进程 `agy remote-control start`，即可在此粘贴链接或切换受控主机：',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (detected != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✓ 已自动识别剪贴板中的受控主机: ${detected.instanceId}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  autofocus: detected == null,
                  decoration: const InputDecoration(
                    labelText: '接管链接或实例 ID (选填)',
                    hintText:
                        'https://antigravity.google.com/r/host-swift-falcon?p=c%2F...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '会话备注名称',
                    hintText: '例如：家里主力开发机 / 公司工作站',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _setWebViewVisible(
                  true,
                  targetUrl: RemoteHostPreset.officialRemoteControlUrl,
                );
              },
              child: const Text('打开网页实例切换器'),
            ),
            FilledButton.icon(
              onPressed: () {
                final rawLink = linkCtrl.text.trim();
                final parsed =
                    RemoteSessionInfo.tryParseRemoteControlUrl(rawLink);
                final instanceId = parsed?.instanceId ??
                    (rawLink.isEmpty ? 'workstation' : rawLink);
                final targetUrl = parsed?.normalizedUrl ??
                    (rawLink.startsWith('http')
                        ? rawLink
                        : 'https://antigravity.google.com/r/$instanceId');
                final title = titleCtrl.text.trim().isEmpty
                    ? '远程接管 · $instanceId'
                    : titleCtrl.text.trim();

                final newSession = RemoteSessionInfo(
                  id: 'rc_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  repo: 'Remote Control',
                  branch: instanceId,
                  mode: 'remote_control',
                  instanceId: instanceId,
                  remoteUrl: targetUrl,
                  status: 'idle',
                  turns: const [],
                );

                setState(() {
                  _sessions.insert(0, newSession);
                  _activeSessionIndex = 0;
                  _configuredHostUrl = targetUrl;
                });
                _persistSessions();
                Navigator.pop(ctx);
                _setWebViewVisible(true, targetUrl: targetUrl);
              },
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('立即连接接管'),
            ),
          ],
        );
      },
    );
  }

  void _createNewSessionDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final repoCtrl = TextEditingController(text: 'antigravity.google.com');
    final branchCtrl = TextEditingController(text: 'main');
    String selectedMode = 'remote_agent';
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isRc = selectedMode == 'remote_control';
            return AlertDialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                '新建 Antigravity 远程会话',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Remote Agent (云端)'),
                            selected: !isRc,
                            onSelected: (_) => setDialogState(
                              () => selectedMode = 'remote_agent',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Remote Control (控电脑)'),
                            selected: isRc,
                            onSelected: (_) => setDialogState(
                              () => selectedMode = 'remote_control',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isRc ? '受控电脑备注名称' : '云端项目 / 任务名称',
                        hintText:
                            isRc ? '例如：家里台式机 CLI 会话' : '例如：重构后端鉴权中间件',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: repoCtrl,
                      decoration: InputDecoration(
                        labelText: isRc
                            ? '接管链接 (/r/<instance-id>) 或主机名'
                            : '关联 GitHub 仓库或云端 Project',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: branchCtrl,
                      decoration: InputDecoration(
                        labelText: isRc ? '实例标识 (Instance ID)' : '工作分支 (Branch)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedRc = RemoteSessionInfo.tryParseRemoteControlUrl(
                      repoCtrl.text.trim(),
                    );
                    final title = titleCtrl.text.trim().isEmpty
                        ? (isRc
                            ? '远程主机 #${_sessions.length + 1}'
                            : '云端项目 #${_sessions.length + 1}')
                        : titleCtrl.text.trim();
                    final repo = repoCtrl.text.trim().isEmpty
                        ? 'antigravity.google.com'
                        : repoCtrl.text.trim();
                    final branch = parsedRc?.instanceId ??
                        (branchCtrl.text.trim().isEmpty
                            ? 'main'
                            : branchCtrl.text.trim());

                    final newSession = RemoteSessionInfo(
                      id: 's_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      repo: isRc ? 'Remote Control' : repo,
                      branch: branch,
                      mode: selectedMode,
                      instanceId: isRc ? branch : null,
                      remoteUrl: parsedRc?.normalizedUrl,
                      status: 'idle',
                      turns: const [],
                    );
                    setState(() {
                      _sessions.insert(0, newSession);
                      _activeSessionIndex = 0;
                    });
                    _persistSessions();
                    if (parsedRc != null) {
                      _setWebViewVisible(
                        true,
                        targetUrl: parsedRc.normalizedUrl,
                      );
                    } else {
                      _webCtrl?.evaluateJavascript(
                        source:
                            'window.AgyBridge && window.AgyBridge.newSession();',
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('创建会话'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 会话管理菜单（支持重命名、清空消息、删除会话）
  void _showSessionManageSheet(BuildContext context, int sessionIdx) {
    if (sessionIdx < 0 || sessionIdx >= _sessions.length) return;
    final target = _sessions[sessionIdx];
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline_rounded),
                  title: const Text('重命名会话与分支'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameSessionDialog(context, sessionIdx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('清空此会话的聊天记录'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _sessions[sessionIdx] = _sessions[sessionIdx].copyWith(
                        turns: const [],
                        approval: const PendingApprovalRequest(pending: false),
                      );
                    });
                    _persistSessions();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                  title: Text('删除此会话', style: TextStyle(color: cs.error)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _sessions.removeAt(sessionIdx);
                      if (_sessions.isEmpty) {
                        _sessions = _buildCleanDefaultSessions();
                      }
                      _activeSessionIndex = _activeSessionIndex.clamp(
                        0,
                        _sessions.length - 1,
                      );
                    });
                    _persistSessions();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameSessionDialog(BuildContext context, int sessionIdx) {
    final s = _sessions[sessionIdx];
    final titleCtrl = TextEditingController(text: s.title);
    final repoCtrl = TextEditingController(text: s.repo);
    final branchCtrl = TextEditingController(text: s.branch);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('编辑会话信息', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '会话标题'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: repoCtrl,
                decoration: const InputDecoration(labelText: '关联仓库 / 项目'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: branchCtrl,
                decoration: const InputDecoration(labelText: '分支名称'),
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
                setState(() {
                  _sessions[sessionIdx] = s.copyWith(
                    title: titleCtrl.text.trim().isEmpty
                        ? s.title
                        : titleCtrl.text.trim(),
                    repo: repoCtrl.text.trim().isEmpty
                        ? s.repo
                        : repoCtrl.text.trim(),
                    branch: branchCtrl.text.trim().isEmpty
                        ? s.branch
                        : branchCtrl.text.trim(),
                  );
                });
                _persistSessions();
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 拦截 Android 返回键与侧滑返回手势，防止误退桌面
  Future<void> _handleSystemBack() async {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return;
    }
    if (_showRawWebView) {
      if (await _webCtrl?.canGoBack() == true) {
        await _webCtrl?.goBack();
      } else {
        await _setWebViewVisible(false);
      }
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('再按一次返回键退出应用'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = _activeSession;
    final bubbleSpec = ChatBubbleStyleSpec(preset: widget.bubblePreset);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
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
                        child: Stack(
                          children: [
                            InAppWebView(
                              initialUrlRequest: URLRequest(
                                url: WebUri(_configuredHostUrl),
                              ),
                              initialSettings: InAppWebViewSettings(
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
                              onCreateWindow:
                                  (controller, createWindowAction) async {
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
                                  _webErrorDescription = null;
                                  if (url != null) {
                                    _currentWebUrl = url.toString();
                                  }
                                });
                              },
                              onProgressChanged: (controller, progress) {
                                if (!mounted) return;
                                setState(() {
                                  _webProgress = progress / 100.0;
                                });
                              },
                              onUpdateVisitedHistory:
                                  (controller, url, isReload) {
                                if (!mounted || url == null) return;
                                setState(() {
                                  _currentWebUrl = url.toString();
                                });
                                _checkGoogleCookies(url);
                              },
                              onReceivedError: (controller, request, error) {
                                if (request.isForMainFrame == true && mounted) {
                                  setState(() {
                                    _webErrorDescription = error.description;
                                  });
                                }
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
                            if (_webErrorDescription != null)
                              _buildWebViewErrorOverlay(context),
                          ],
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
                      Expanded(
                        child: activeSession.turns.isEmpty
                            ? _buildWelcomeDashboard(context)
                            : ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 16,
                                ),
                                itemCount: activeSession.turns.length,
                                itemBuilder: (context, index) {
                                  final isLastTurn =
                                      index == activeSession.turns.length - 1;
                                  return KelivoMessageItem(
                                    turn: activeSession.turns[index],
                                    bubbleStyle: bubbleSpec,
                                    sessionMode: activeSession.mode,
                                    pendingApproval: isLastTurn &&
                                            activeSession.approval.pending
                                        ? activeSession.approval
                                        : null,
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
                        sessionMode: activeSession.mode,
                        remoteInstanceId: activeSession.instanceId,
                        thinkingBudget: _thinkingBudget,
                        webSearchEnabled: _webSearch,
                        fullAccessEnabled: _fullAccess,
                        isStreaming: _isStreaming,
                        onSend: _sendPrompt,
                        onStop: _stopStreaming,
                        onApprove: _handleApprove,
                        onDeny: _handleDeny,
                        onCycleThinking: () {
                          final spec = AgyModelCatalog.byName(_selectedModel);
                          final levels = spec.thinkingLevels;
                          final curIdx = levels.indexOf(_thinkingBudget);
                          final nextLevel =
                              levels[(curIdx + 1) % levels.length];
                          _syncModelAndThinkingToWeb(_selectedModel, nextLevel);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已切换 $_selectedModel 思考深度为 $nextLevel',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onToggleWebSearch: () {
                          setState(() => _webSearch = !_webSearch);
                        },
                        onToggleFullAccess: () {
                          setState(() => _fullAccess = !_fullAccess);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _fullAccess
                                    ? '权限预设: always-proceed (turbo) · 自动执行命令'
                                    : '权限预设: request review · 敏感操作需确认',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onQuickCommand: (cmd) {
                          setState(() {
                            _promptCtrl.text = cmd;
                            _promptCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: _promptCtrl.text.length),
                            );
                          });
                        },
                        onTapModelPicker: () => _showModelPickerSheet(context),
                        onOpenGoogleLogin: _openGoogleLoginFlow,
                        onOpenSettings: () =>
                            _showSettingsAndAccountSheet(context),
                        onOpenRemoteControlLink: () =>
                            _openRemoteControlLinkDialog(context),
                        onOpenProjectResources: _openCloudProjectResources,
                        onAttachGoogleDrive: _attachGoogleDriveResource,
                        onUploadLocalFile: _uploadLocalFileResource,
                        onOpenPlugins: _openMarketplacePlugins,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 产品级空状态欢迎与引导屏（彻底取代开局硬编码假对话！）
  Widget _buildWelcomeDashboard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final quickStarters = [
      (
        Icons.folder_special_outlined,
        '云端 Project · 挂载 GitHub 仓库与 Drive 文档',
        '打开 antigravity.google.com 绑定 GitHub Repo、Google Drive 或上传文件',
        _openCloudProjectResources,
      ),
      (
        Icons.desktop_windows_rounded,
        'Remote Control · 远程接管本机电脑会话',
        '粘贴电脑端 agy --remote-control 生成的 /r/<instance> 链接或切换主机',
        () => _openRemoteControlLinkDialog(context),
      ),
      (
        Icons.architecture_rounded,
        '制定实现计划 Artifact (/plan)',
        '让云端 Agent 先梳理模块依赖并输出可审阅的 Implementation Plan',
        () {
          _promptCtrl.text = '/plan 请帮我梳理当前项目的核心架构并制定分步实现计划';
          _sendPrompt();
        },
      ),
      (
        Icons.groups_2_outlined,
        '多子代理协同 (/teamwork) 与需求对齐 (/grill-me)',
        '启动多个自治 Subagent 并行开发，或通过交互式提问对齐设计细节',
        () {
          _promptCtrl.text = '/teamwork 请组建多子代理团队并行完成核心模块开发与测试验证';
          _sendPrompt();
        },
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 顶部主欢迎卡片（根据是否已登录 Google 动态展示）
          KelivoSharedSurface(
            style: ChatBubbleStyleSpec(preset: widget.bubblePreset),
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(18),
            defaultColor: cs.primaryContainer.withValues(alpha: 0.24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isGoogleAuthenticated
                                ? colors.success
                                : colors.warning)
                            .withValues(alpha: 0.16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _isGoogleAuthenticated
                            ? Icons.verified_user_rounded
                            : Icons.account_circle_outlined,
                        size: 22,
                        color: _isGoogleAuthenticated
                            ? colors.success
                            : colors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isGoogleAuthenticated
                                ? 'Google 订阅账号已连接'
                                : '欢迎使用 Antigravity Remote',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isGoogleAuthenticated
                                ? (_userEmail.isNotEmpty
                                    ? '当前账号: $_userEmail · 零外部 API 消耗'
                                    : '已连接 antigravity.google.com 云端工作区')
                                : '请先登录你的 Google AI Pro / Ultra 个人账号以激活云端容器',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _isGoogleAuthenticated
                      ? '你现在可以在下方直接输入指令，或点击「打开云端网页」在 antigravity.google.com 中选择 GitHub 仓库与远端项目。'
                      : '1. 点击下方「立即登录 Google 账号」完成官方 OAuth 验证；\n'
                          '2. 登录成功后会自动跳转至 antigravity.google.com 控制台；\n'
                          '3. 点击顶栏「原生 / 网页」胶囊即可在 Kelivo 极光界面与云端网页间随时切换。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.52,
                    color: cs.onSurface.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!_isGoogleAuthenticated)
                      FilledButton.icon(
                        onPressed: _openGoogleLoginFlow,
                        icon: const Icon(Icons.login_rounded, size: 17),
                        label: const Text('立即登录 Google 账号'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _setWebViewVisible(
                          true,
                          targetUrl: _configuredHostUrl,
                        ),
                        icon: const Icon(Icons.public_rounded, size: 17),
                        label: const Text('进入云端网页选择项目'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _showSettingsAndAccountSheet(context),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('账号与主机设置'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '快捷操作与常用工作流 (QUICK ACTIONS)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: AppFontWeights.semibold,
                letterSpacing: 0.5,
                color: cs.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ),

          // 2. 4 个可点击的快捷操作卡片
          for (final item in quickStarters)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IosCardPress(
                onTap: item.$4,
                baseColor: colors.chatQuietFill,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.$1, size: 17, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 11.8,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// WebView 网络异常/代理未连接时的友好重试浮层（取代丑陋的系统报错白屏）
  Widget _buildWebViewErrorOverlay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      color: cs.surface.withValues(alpha: 0.94),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: KelivoSharedSurface(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: colors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              '无法连接 Google 云端服务',
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '加载 $_currentWebUrl 时遇到网络异常（${_webErrorDescription ?? "连接超时"}）。\n请确认手机已开启可访问 Google 的网络环境后重试。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.48,
                color: cs.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _webErrorDescription = null);
                    _webCtrl?.reload();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('立即刷新重试'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSettingsAndAccountSheet(context),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('切换主机地址'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              } else {
                await _setWebViewVisible(false);
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
            onTap: () {
              setState(() => _webErrorDescription = null);
              _webCtrl?.reload();
            },
          ),
          const SizedBox(width: 4),
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
            icon: const Icon(Icons.auto_awesome_outlined, size: 15),
            label: const Text(
              '切回原生视图',
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
                'Google 登录页',
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
                'Agent 控制台',
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
                    content: Text('已确认 Google 登录状态并切回 Kelivo 原生界面'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.verified_user_outlined, size: 15),
              label: const Text(
                '我已登录 · 返回',
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
                              '${activeSession.title} · ${activeSession.branch}',
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
              // 1. Google 登录 / 账号状态胶囊按钮
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
                  horizontal: 9,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isGoogleAuthenticated
                          ? Icons.verified_user_rounded
                          : Icons.login_rounded,
                      size: 13.5,
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
                          : '登录',
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
              const SizedBox(width: 5),
              // 2. 直观的「网页」实景切换胶囊按钮
              IosCardPress(
                onTap: () => _setWebViewVisible(true),
                baseColor: colors.chatQuietFill,
                borderRadius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '网页',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
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
                    tooltip: '新建云端 Agent 会话',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewSessionDialog(context);
                    },
                  ),
                ],
              ),
            ),

            // 2. Current Host & Google Subscription Card
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
                                : '未登录 · 点击绑定 Google 账号',
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

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '云端工作区会话 (长按或点 ⋯ 管理)',
                      style: TextStyle(fontSize: 11, letterSpacing: 0.4),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _createNewSessionDialog(context);
                    },
                    child: Text(
                      '+ 新建',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Conversation Tiles (支持点击切换 + 右侧 ⋯ 重命名/清空/删除)
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
                          child: GestureDetector(
                            onLongPress: () =>
                                _showSessionManageSheet(context, realIdx),
                            child: IosCardPress(
                              onTap: () {
                                setState(() => _activeSessionIndex = realIdx);
                                _persistSessions();
                                Navigator.pop(context);
                              },
                              baseColor: selected
                                  ? cs.primary.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
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
                                        const SizedBox(height: 3),
                                        Text(
                                          '${s.repo} · ${s.branch} (${s.turns.length} 条消息)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontFamily: 'monospace',
                                            color: cs.onSurface.withValues(
                                              alpha: 0.54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IosIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    size: 17,
                                    padding: const EdgeInsets.all(5),
                                    color: cs.onSurface.withValues(alpha: 0.55),
                                    onTap: () => _showSessionManageSheet(
                                      context,
                                      realIdx,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 4. Bottom User & Settings Bar
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            final colors = ctx.appColors;
            final currentSpec = AgyModelCatalog.byName(_selectedModel);

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '选择推理模型与思考深度 (2026.11 官方规范)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IosIconButton(
                          icon: Icons.close_rounded,
                          size: 19,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. 4 款真实主力模型列表
                    for (final m in AgyModelCatalog.models)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: IosCardPress(
                          onTap: () {
                            final validThinking =
                                AgyModelCatalog.normalizeThinkingLevel(
                              m.name,
                              _thinkingBudget,
                            );
                            _syncModelAndThinkingToWeb(m.name, validThinking);
                            setModalState(() {});
                          },
                          baseColor: _selectedModel == m.name
                              ? cs.primary.withValues(alpha: 0.14)
                              : colors.chatQuietFill,
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            m.name,
                                            style: TextStyle(
                                              fontSize: 14.2,
                                              fontWeight:
                                                  AppFontWeights.semibold,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            m.badge,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight:
                                                  AppFontWeights.semibold,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.subtitle,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: cs.onSurface.withValues(
                                          alpha: 0.64,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedModel == m.name)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: cs.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),
                    Text(
                      '思考深度 (Thinking Level · ${currentSpec.name})',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final lvl in currentSpec.thinkingLevels)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(lvl),
                                selected: _thinkingBudget == lvl,
                                onSelected: (_) {
                                  _syncModelAndThinkingToWeb(
                                    _selectedModel,
                                    lvl,
                                  );
                                  setModalState(() {});
                                },
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    // 2. 订阅配额卡片 (Five Hour Limit & Weekly Limit)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.chatQuietFill,
                        borderRadius: BorderRadius.circular(14),
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
                                Icons.speed_rounded,
                                size: 16,
                                color: colors.success,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Google AI Pro / Ultra 订阅配额监控',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: AppFontWeights.semibold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Gemini Models: Five Hour Limit & Weekly Limit 独立核算\n'
                            '• Claude 5.5 Models: Five Hour Limit & Weekly Limit 独立核算',
                            style: TextStyle(
                              fontSize: 11.2,
                              height: 1.45,
                              color: cs.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _promptCtrl.text = '/usage';
                                  _sendPrompt();
                                },
                                icon: const Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  '查看实时配额 (/usage)',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _promptCtrl.text = '/credits';
                                  _sendPrompt();
                                },
                                icon: const Icon(
                                  Icons.bolt_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  '查询 AI Credits',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
                              '直连官方 antigravity.google.com，100% 消耗你的 Google AI Pro / Ultra 个人订阅内额度。\n'
                              '状态：${_webLoaded ? "WebView 已就绪" : "正在连接 WebView"} · ${_needsLoginOnPage ? "待登录验证" : "工作区已激活"}',
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
                                    });
                                    setModalState(() {});
                                    await _saveAccountState(
                                      authenticated: false,
                                      email: '',
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('已清空全部 WebView Cookie 与登录状态'),
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

                      // Section 2: 远端主机地址预设与自定义
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

                      // Section 3: 会话管理与可选 UI 演示样本
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _sessions = _buildCleanDefaultSessions();
                                  _activeSessionIndex = 0;
                                });
                                _persistSessions();
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                '重置为干净空工作区',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _sessions = _buildDemoSampleSessions();
                                  _activeSessionIndex = 0;
                                });
                                _persistSessions();
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                '加载 UI 演示样本',
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
