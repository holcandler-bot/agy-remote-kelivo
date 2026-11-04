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
  final ScrollController _scrollCtrl = ScrollController();

  InAppWebViewController? _webCtrl;
  bool _showRawWebView = false;
  bool _webConnected = false;
  String _selectedModel = 'Gemini 4 Argon';
  String _thinkingBudget = 'High';
  bool _webSearch = true;
  bool _fullAccess = false;
  int _activeSessionIndex = 0;

  PendingApprovalRequest _approval = const PendingApprovalRequest(
    pending: true,
    commandOrFile: 'npm run test:auth -- --watch=false',
    summary: '在远端沙盒执行 OAuth2 Token 互斥锁并发回归测试',
  );

  final List<RemoteSessionInfo> _sessions = const [
    RemoteSessionInfo(
      id: 's1',
      title: '重构 OAuth2 Token 刷新竞态锁',
      repo: 'nekos/agy-cloud-core',
      branch: 'feat/token-lock',
      status: 'running',
      additions: 48,
      deletions: 12,
    ),
    RemoteSessionInfo(
      id: 's2',
      title: '适配 Kelivo Frosted 极光渲染管线',
      repo: 'nekos/kelivo-mobile-ui',
      branch: 'ui/aurora-shader',
      status: 'approval',
      additions: 136,
      deletions: 19,
    ),
    RemoteSessionInfo(
      id: 's3',
      title: '修复 WebSocket 断线指数退避重连',
      repo: 'nekos/agy-cloud-core',
      branch: 'fix/ws-backoff',
      status: 'idle',
      additions: 24,
      deletions: 8,
    ),
  ];

  late List<AgentChatTurn> _turns;

  @override
  void initState() {
    super.initState();
    _turns = [
      const AgentChatTurn(
        id: 't1',
        isUser: true,
        timestamp: '23:41',
        content: '帮我排查 src/auth/token_manager.ts 在高并发请求下偶发 401 退出的问题，补齐单测并给我看 Diff。',
      ),
      const AgentChatTurn(
        id: 't2',
        isUser: false,
        modelName: 'Gemini 4 Argon',
        timestamp: '23:42',
        thinkingDuration: '2.8s',
        thinkingActive: true,
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
          '@@ -41,6 +41,17 @@ export class TokenManager {\n'
              '-  async refreshAccessToken(): Promise<string> {\n'
              '-    return this._ performRefresh();\n'
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
      ),
    ];
  }

  Future<void> _injectBridgeScript(InAppWebViewController controller) async {
    try {
      final jsCode = await rootBundle.loadString('assets/agy_bridge.js');
      await controller.evaluateJavascript(source: jsCode);
    } catch (_) {}
  }

  Future<void> _sendPrompt() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _promptCtrl.clear();

    setState(() {
      _turns.add(
        AgentChatTurn(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isUser: true,
          timestamp: '刚刚',
          content: text,
        ),
      );
    });

    final escaped = jsonEncode(text);
    await _webCtrl?.evaluateJavascript(
      source: 'window.AgyBridge && window.AgyBridge.sendPrompt($escaped);',
    );
  }

  Future<void> _handleApprove() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _approval = const PendingApprovalRequest(pending: false);
    });
    await _webCtrl?.evaluateJavascript(
      source: 'window.AgyBridge && window.AgyBridge.approveTool();',
    );
  }

  Future<void> _handleDeny() async {
    HapticFeedback.lightImpact();
    setState(() {
      _approval = const PendingApprovalRequest(pending: false);
    });
    await _webCtrl?.evaluateJavascript(
      source: 'window.AgyBridge && window.AgyBridge.denyTool();',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeSession = _sessions[_activeSessionIndex];
    final bubbleSpec = ChatBubbleStyleSpec(preset: widget.bubblePreset);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildKelivoSideDrawer(context),
      body: KelivoAuroraBackground(
        palette: widget.palette,
        enabled: widget.auroraEnabled,
        child: Stack(
          children: [
            // Layer 1: Offscreen / Togglable WebView logged into personal Google account
            AnimatedOpacity(
              opacity: _showRawWebView ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_showRawWebView,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri('https://antigravity.google/remote-agents'),
                      ),
                      initialSettings: InAppWebViewSettings(
                        // Strip `; wv` so Google OAuth uses personal Pro/Ultra subscription cleanly
                        userAgent:
                            'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                      ),
                      onWebViewCreated: (controller) {
                        _webCtrl = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'onAgyStateSync',
                          callback: (args) {
                            if (args.isEmpty) return;
                            setState(() => _webConnected = true);
                          },
                        );
                      },
                      onLoadStop: (controller, url) async {
                        await _injectBridgeScript(controller);
                        setState(() => _webConnected = true);
                      },
                    ),
                  ),
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
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 6, bottom: 16),
                        itemCount: _turns.length,
                        itemBuilder: (context, index) {
                          return KelivoMessageItem(
                            turn: _turns[index],
                            bubbleStyle: bubbleSpec,
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
                      approval: _approval,
                      currentBranch: activeSession.branch,
                      thinkingBudget: _thinkingBudget,
                      webSearchEnabled: _webSearch,
                      fullAccessEnabled: _fullAccess,
                      onSend: _sendPrompt,
                      onApprove: _handleApprove,
                      onDeny: _handleDeny,
                      onCycleThinking: () {
                        const levels = ['Low', 'Med', 'High', 'Max'];
                        final next =
                            (levels.indexOf(_thinkingBudget) + 1) % levels.length;
                        setState(() => _thinkingBudget = levels[next]);
                      },
                      onToggleWebSearch: () =>
                          setState(() => _webSearch = !_webSearch),
                      onToggleFullAccess: () =>
                          setState(() => _fullAccess = !_fullAccess),
                      onQuickCommand: (cmd) {
                        _promptCtrl.text = '$cmd ';
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Floating return pill when in Raw WebView login/inspection mode
            if (_showRawWebView)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 14,
                right: 14,
                child: KelivoSharedSurface(
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: context.appColors.success,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '原网页桥接层（登录 Google 账号即享个人订阅额度）',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            setState(() => _showRawWebView = false),
                        child: const Text('返回 Kelivo 原生界面'),
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
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: IosCardPress(
                  onTap: () => _showModelPickerSheet(context),
                  baseColor: colors.chatQuietFill,
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _webConnected ? colors.success : cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                                      fontSize: 13.5,
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.56),
                                ),
                              ],
                            ),
                            Text(
                              '${activeSession.repo} · ${activeSession.branch}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
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
              IosIconButton(
                icon: Icons.language_rounded,
                size: 20,
                tooltip: '切换底层 WebView 登录/验权页',
                onTap: () => setState(() => _showRawWebView = !_showRawWebView),
              ),
              IosIconButton(
                icon: Icons.palette_outlined,
                size: 20,
                tooltip: 'Kelivo 9 色东方美学定制台',
                onTap: () => _showThemeStudioSheet(context),
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

    return Drawer(
      backgroundColor: cs.surface,
      width: 304,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & New Agent Row
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
                          Text(
                            '搜索云端会话与分支...',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IosIconButton(
                    icon: Icons.add_circle_outline_rounded,
                    size: 21,
                    color: cs.primary,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Current Assistant Pill (`side_drawer.dart`)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: IosCardPress(
                onTap: () {},
                baseColor: colors.surfaceFill,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.hub_outlined,
                        size: 17,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Antigravity Remote Host',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'Google AI Ultra 个人订阅直连',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Text(
                '活跃云端工作区 (ACTIVE SANDBOXES)',
                style: TextStyle(fontSize: 11, letterSpacing: 0.6),
              ),
            ),

            // Conversation Tiles (`_ChatTile` in `side_drawer.dart`)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _sessions.length,
                itemBuilder: (context, idx) {
                  final s = _sessions[idx];
                  final selected = idx == _activeSessionIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IosCardPress(
                      onTap: () {
                        setState(() => _activeSessionIndex = idx);
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
                                    fontSize: 14.5,
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
                                s.branch,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: cs.onSurface.withValues(alpha: 0.54),
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

            // Bottom User Bar (`sidebar-user-bar` in `side_drawer.dart`)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.hairlineBorder, width: 0.6),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withValues(alpha: 0.18),
                    child: Text(
                      'N',
                      style: TextStyle(
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'nekos · Pro 订阅内额度',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          '0 外部 API 消耗 · WebView 已保活',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IosIconButton(
                    icon: Icons.palette_outlined,
                    size: 20,
                    onTap: () {
                      Navigator.pop(context);
                      _showThemeStudioSheet(context);
                    },
                  ),
                ],
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

  void _showThemeStudioSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Kelivo 东方美学与极光定制台',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: widget.isDark,
                      onChanged: (v) => widget.onUpdateTheme(isDark: v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: KelivoPalettes.all.map((p) {
                    final selected = p.id == widget.palette.id;
                    final swatch =
                        widget.isDark ? p.dark.primary : p.light.primary;
                    return IosCardPress(
                      onTap: () => widget.onUpdateTheme(paletteId: p.id),
                      baseColor: selected
                          ? swatch.withValues(alpha: 0.18)
                          : context.appColors.chatQuietFill,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        selected: widget.auroraEnabled,
                        label: const Text('4-Blob 极光背景'),
                        onSelected: (v) =>
                            widget.onUpdateTheme(auroraEnabled: v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        selected:
                            widget.bubblePreset == ChatBubblePreset.frosted,
                        label: const Text('Sigma-14 毛玻璃气泡'),
                        onSelected: (v) => widget.onUpdateTheme(
                          bubblePreset: v
                              ? ChatBubblePreset.frosted
                              : ChatBubblePreset.solid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
