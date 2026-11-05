import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/agent_models.dart';
import '../theme/app_themes.dart';
import 'kelivo_aurora_background.dart';

class KelivoComposerBar extends StatefulWidget {
  final TextEditingController controller;
  final PendingApprovalRequest approval;
  final String currentBranch;
  final String sessionMode; // 'remote_agent' | 'remote_control'
  final String? remoteInstanceId;
  final String thinkingBudget;
  final bool webSearchEnabled;
  final bool fullAccessEnabled;
  final double contextUsage; // 0.0 - 1.0 (Five Hour / Weekly Quota indicator)
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onCycleThinking;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleFullAccess;
  final ValueChanged<String> onQuickCommand;
  final VoidCallback? onTapModelPicker;
  final VoidCallback? onOpenGoogleLogin;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenRemoteControlLink;
  final VoidCallback? onOpenProjectResources;
  final VoidCallback? onAttachGoogleDrive;
  final VoidCallback? onUploadLocalFile;
  final VoidCallback? onOpenPlugins;

  const KelivoComposerBar({
    super.key,
    required this.controller,
    required this.approval,
    this.currentBranch = 'main',
    this.sessionMode = 'remote_agent',
    this.remoteInstanceId,
    required this.thinkingBudget,
    required this.webSearchEnabled,
    this.fullAccessEnabled = true,
    this.contextUsage = 1.0,
    this.isStreaming = false,
    required this.onSend,
    this.onStop,
    required this.onApprove,
    required this.onDeny,
    required this.onCycleThinking,
    required this.onToggleWebSearch,
    required this.onToggleFullAccess,
    required this.onQuickCommand,
    this.onTapModelPicker,
    this.onOpenGoogleLogin,
    this.onOpenSettings,
    this.onOpenRemoteControlLink,
    this.onOpenProjectResources,
    this.onAttachGoogleDrive,
    this.onUploadLocalFile,
    this.onOpenPlugins,
  });

  @override
  State<KelivoComposerBar> createState() => _KelivoComposerBarState();
}

class _KelivoComposerBarState extends State<KelivoComposerBar>
    with SingleTickerProviderStateMixin {
  bool _showSlashDrawer = false;
  bool _showToolsSheet = false;
  bool _expandedEditor = false;
  bool _voiceRecording = false;
  late final AnimationController _waveCtrl;

  static const List<(String, String)> _quickTopPills = [
    ('/plan', '制定计划'),
    ('/goal', '长时目标'),
    ('/boost', '深度思考'),
    ('/teamwork', '多代理协作'),
    ('/grill-me', '需求对齐'),
    ('/usage', '查配额'),
    ('/plugin', '云端插件'),
  ];

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  List<AgySlashCommand> _getFilteredSlashCommands() {
    final text = widget.controller.text.trimLeft();
    if (!text.startsWith('/')) {
      return AgySlashCommandCatalog.all;
    }
    final firstToken = text.split(RegExp(r'\s+')).first.toLowerCase();
    if (firstToken == '/') {
      return AgySlashCommandCatalog.all;
    }
    final filtered = AgySlashCommandCatalog.all
        .where((c) => c.command.toLowerCase().startsWith(firstToken))
        .toList();
    return filtered.isEmpty ? AgySlashCommandCatalog.all : filtered;
  }

  void _selectSlashCommand(AgySlashCommand cmd) {
    HapticFeedback.selectionClick();
    setState(() => _showSlashDrawer = false);
    if (cmd.autoSend) {
      widget.controller.text = cmd.command;
      widget.onSend();
      return;
    }
    final filled = cmd.templateSuffix.isNotEmpty
        ? '${cmd.command} ${cmd.templateSuffix}'
        : '${cmd.command} ';
    widget.onQuickCommand(filled);
  }

  void _toggleVoice({bool commit = false}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _voiceRecording = !_voiceRecording;
      if (_voiceRecording) {
        _waveCtrl.repeat(reverse: true);
      } else {
        _waveCtrl.stop();
        if (commit) {
          final current = widget.controller.text.trim();
          final addition = current.isEmpty
              ? '/plan 请检查当前云端仓库的构建状态并制定优化方案'
              : '$current ';
          widget.controller.text = addition;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: widget.controller.text.length),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('语音指令已转写填入输入框'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<void> _pasteClipboardCode() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData('text/plain');
    final clip = (data?.text ?? '').trim();
    if (!mounted) return;
    setState(() => _showToolsSheet = false);
    if (clip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('剪贴板为空，请先复制代码、日志或 Remote Control 链接'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 如果剪贴板里恰好是 Remote Control 接管链接，优先提示一键接管
    final rcLink = RemoteSessionInfo.tryParseRemoteControlUrl(clip);
    if (rcLink != null && widget.onOpenRemoteControlLink != null) {
      widget.onOpenRemoteControlLink!();
      return;
    }

    final formatted = widget.controller.text.trim().isEmpty
        ? '请帮我分析以下剪贴板代码/日志：\n```\n$clip\n```\n'
        : '${widget.controller.text}\n```\n$clip\n```\n';
    setState(() {
      widget.controller.text = formatted;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRemoteControl = widget.sessionMode == 'remote_control';
    final filteredSlash = _getFilteredSlashCommands();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 待审批 Implementation Plan (Proceed) 或敏感工具审批横幅
            if (widget.approval.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: widget.approval.isPlanReview
                        ? cs.primary.withValues(alpha: 0.14)
                        : colors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.approval.isPlanReview
                          ? cs.primary.withValues(alpha: 0.35)
                          : colors.warning.withValues(alpha: 0.4),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.approval.isPlanReview
                            ? Icons.assignment_turned_in_outlined
                            : Icons.gpp_maybe_outlined,
                        size: 16,
                        color: widget.approval.isPlanReview
                            ? cs.primary
                            : colors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.approval.isPlanReview
                                  ? 'Implementation Plan 待您审阅'
                                  : '待确认执行: ${widget.approval.commandOrFile}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFontWeights.semibold,
                                color: cs.onSurface,
                              ),
                            ),
                            if (widget.approval.summary.isNotEmpty)
                              Text(
                                widget.approval.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.68),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IosCardPress(
                        onTap: widget.onApprove,
                        borderRadius: BorderRadius.circular(999),
                        baseColor: widget.approval.isPlanReview
                            ? cs.primary
                            : colors.warning,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        child: Text(
                          widget.approval.approveLabel.isNotEmpty
                              ? widget.approval.approveLabel
                              : 'Proceed · 批准',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFontWeights.semibold,
                            color: widget.approval.isPlanReview
                                ? cs.onPrimary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IosCardPress(
                        onTap: widget.onDeny,
                        borderRadius: BorderRadius.circular(999),
                        baseColor: cs.error.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: Text(
                          widget.approval.denyLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 2. 横向可滚动状态与高频 Slash 快捷胶囊栏（单手拇指一触即发）
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 当前模式胶囊 (Remote Agent vs Remote Control)
                    IosCardPress(
                      onTap: widget.onOpenRemoteControlLink ??
                          widget.onToggleFullAccess,
                      borderRadius: BorderRadius.circular(999),
                      baseColor: isRemoteControl
                          ? cs.tertiary.withValues(alpha: 0.16)
                          : cs.onSurface.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRemoteControl
                                ? Icons.desktop_windows_rounded
                                : Icons.cloud_done_outlined,
                            size: 13,
                            color: isRemoteControl
                                ? cs.tertiary
                                : (widget.fullAccessEnabled
                                    ? colors.success
                                    : colors.warning),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isRemoteControl
                                ? 'Remote Control · ${widget.remoteInstanceId ?? widget.currentBranch}'
                                : (widget.fullAccessEnabled
                                    ? 'Remote Agent (Turbo) · ${widget.currentBranch}'
                                    : 'Remote Agent (Review) · ${widget.currentBranch}'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: AppFontWeights.semibold,
                              color: cs.onSurface.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (final pill in _quickTopPills) ...[
                      IosCardPress(
                        onTap: () {
                          final spec = AgySlashCommandCatalog.all.firstWhere(
                            (e) => e.command == pill.$1,
                            orElse: () => AgySlashCommand(
                              command: pill.$1,
                              title: pill.$2,
                              description: '',
                            ),
                          );
                          _selectSlashCommand(spec);
                        },
                        borderRadius: BorderRadius.circular(999),
                        baseColor: cs.onSurface.withValues(alpha: 0.06),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pill.$1,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: AppFontWeights.semibold,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pill.$2,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),

            // 3. 官方 11 个真实 Slash 命令自动补全抽屉 (`/`)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _showSlashDrawer
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: const BoxConstraints(maxHeight: 230),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.surfaceLadder.l2Card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.hairlineBorder,
                          width: 0.8,
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredSlash.length,
                        itemBuilder: (context, idx) {
                          final item = filteredSlash[idx];
                          return IosCardPress(
                            onTap: () => _selectSlashCommand(item),
                            borderRadius: BorderRadius.circular(10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.command,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontFamily: 'monospace',
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 12.2,
                                          fontWeight: AppFontWeights.semibold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Text(
                                        item.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.64,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // 4. Kelivo 20px Frosted Glass `ChatInputBar`
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? Color.alphaBlend(
                                cs.primary.withValues(alpha: 0.08),
                                cs.surfaceContainerHigh,
                              )
                            : Colors.white)
                        .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? cs.onSurface.withValues(alpha: 0.10)
                          : cs.outline.withValues(alpha: 0.20),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Input TextField + Top-Right `Maximize2` Expand Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              minLines: _expandedEditor ? 5 : 1,
                              maxLines: _expandedEditor ? 10 : 5,
                              onChanged: (val) {
                                final shouldShow =
                                    val.trimLeft().startsWith('/');
                                if (shouldShow != _showSlashDrawer) {
                                  setState(() => _showSlashDrawer = shouldShow);
                                } else {
                                  setState(() {});
                                }
                              },
                              onSubmitted: (_) => widget.onSend(),
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.42,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: isRemoteControl
                                    ? '向远程受控主机发送指令... (输入 / 唤醒官方技能)'
                                    : '向云端 Remote Agent 发送指令... (输入 / 唤醒技能)',
                                hintStyle: TextStyle(
                                  fontSize: 14.2,
                                  color: cs.onSurface.withValues(alpha: 0.42),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 8,
                                ),
                              ),
                            ),
                          ),
                          IosIconButton(
                            icon: _expandedEditor
                                ? Icons.close_fullscreen_rounded
                                : Icons.open_in_full_rounded,
                            size: 15,
                            padding: const EdgeInsets.all(5),
                            color: cs.onSurface.withValues(alpha: 0.45),
                            onTap: () => setState(
                              () => _expandedEditor = !_expandedEditor,
                            ),
                          ),
                        ],
                      ),

                      // Bottom `_buildCompactActionRow` or `_buildVoiceRecordingRow`
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _voiceRecording
                            ? _buildVoiceRecordingRow(context)
                            : _buildCompactActionRow(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Kelivo `BottomToolsSheet` (6 大核心云端与挂载入口)
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: _showToolsSheet
                  ? _buildBottomToolsSheet(context)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Row(
      children: [
        // 1. Model Avatar Button (opens Model & Thinking Picker Sheet)
        IosCardPress(
          onTap: widget.onTapModelPicker,
          borderRadius: BorderRadius.circular(999),
          baseColor: cs.primary.withValues(alpha: 0.14),
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 15,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 4),

        // 2. Thinking Level Badge (`Fast` / `Low` / `Medium` / `High`)
        IosCardPress(
          onTap: widget.onCycleThinking,
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 3),
              Text(
                widget.thinkingBudget,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),

        // 3. Remote Project / GitHub Resource Quick Button
        IosIconButton(
          icon: Icons.folder_special_outlined,
          size: 19,
          padding: const EdgeInsets.all(6),
          tooltip: '选择云端 Project / 挂载 GitHub 与 Google Drive 资源',
          color: cs.onSurface.withValues(alpha: 0.68),
          onTap: () => widget.onOpenProjectResources?.call(),
        ),

        // 4. Permission Preset Toggle (`always-proceed (turbo)` vs `request review`)
        Stack(
          clipBehavior: Clip.none,
          children: [
            IosIconButton(
              icon: Icons.shield_outlined,
              size: 18,
              padding: const EdgeInsets.all(6),
              tooltip: widget.fullAccessEnabled
                  ? '当前权限: always-proceed (turbo)'
                  : '当前权限: request review (敏感操作询问)',
              color: widget.fullAccessEnabled ? colors.success : colors.warning,
              onTap: widget.onToggleFullAccess,
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.fullAccessEnabled
                      ? colors.success
                      : colors.warning,
                ),
              ),
            ),
          ],
        ),

        // 5. Official Slash Command Drawer Toggle (`/`)
        IosIconButton(
          icon: Icons.terminal_rounded,
          size: 18,
          padding: const EdgeInsets.all(6),
          tooltip: 'Antigravity 官方 Slash 技能面板 (/)',
          color: _showSlashDrawer
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.54),
          onTap: () => setState(() => _showSlashDrawer = !_showSlashDrawer),
        ),

        const Spacer(),

        // Right Cluster:
        // 6. Quota & Usage Ring (Five Hour Limit & Weekly Limit)
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Google AI Pro / Ultra 订阅配额正常 · 点击查看 Five Hour / Weekly 实时余量',
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: '发送 /usage',
                  onPressed: () {
                    widget.controller.text = '/usage';
                    widget.onSend();
                  },
                ),
              ),
            );
          },
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ContextUsageRingPainter(
                progress: widget.contextUsage,
                trackColor: cs.onSurface.withValues(alpha: 0.14),
                valueColor: colors.success,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // 7. `Plus` rotating to `X` (`BottomToolsSheet` toggle)
        AnimatedRotation(
          turns: _showToolsSheet ? 0.125 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IosIconButton(
            icon: Icons.add_rounded,
            size: 21,
            padding: const EdgeInsets.all(5),
            color: _showToolsSheet
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.68),
            onTap: () => setState(() => _showToolsSheet = !_showToolsSheet),
          ),
        ),

        // 8. `Mic` Voice Input
        IosIconButton(
          icon: Icons.mic_none_rounded,
          size: 19,
          padding: const EdgeInsets.all(5),
          color: cs.onSurface.withValues(alpha: 0.68),
          onTap: () => _toggleVoice(commit: false),
        ),
        const SizedBox(width: 4),

        // 9. Circular `_CompactSendButton` (`Lucide.ArrowUp` / Stop square)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.isStreaming && widget.onStop != null) {
              widget.onStop!();
            } else {
              widget.onSend();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isStreaming
                  ? cs.error
                  : (hasText
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.12)),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.isStreaming
                  ? Icons.stop_rounded
                  : Icons.arrow_upward_rounded,
              size: 18,
              color: (hasText || widget.isStreaming)
                  ? cs.onPrimary
                  : cs.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceRecordingRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('voice-wave-row'),
      children: [
        IosIconButton(
          icon: Icons.close_rounded,
          size: 18,
          color: cs.error,
          onTap: () => _toggleVoice(commit: false),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 24,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _VoiceWaveformPainter(
                    phase: _waveCtrl.value,
                    color: cs.primary,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IosIconButton(
          icon: Icons.check_circle_rounded,
          size: 22,
          color: cs.primary,
          onTap: () => _toggleVoice(commit: true),
        ),
      ],
    );
  }

  Widget _buildBottomToolsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;

    Widget buildActionTile({
      required IconData icon,
      required String label,
      required String subtitle,
      required VoidCallback onTap,
      Color? accentColor,
    }) {
      return Expanded(
        child: IosCardPress(
          onTap: onTap,
          baseColor: colors.chatQuietFill,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: accentColor ?? cs.onSurface.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.8,
                  color: cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              buildActionTile(
                icon: Icons.folder_special_outlined,
                label: '云端项目 / GitHub',
                subtitle: '选择 Project 挂载仓库',
                accentColor: cs.primary,
                onTap: () {
                  setState(() => _showToolsSheet = false);
                  widget.onOpenProjectResources?.call();
                },
              ),
              const SizedBox(width: 8),
              buildActionTile(
                icon: Icons.add_to_drive_rounded,
                label: '挂载 Google Drive',
                subtitle: '关联 Docs/Sheets/PDF',
                accentColor: colors.success,
                onTap: () {
                  setState(() => _showToolsSheet = false);
                  widget.onAttachGoogleDrive?.call();
                },
              ),
              const SizedBox(width: 8),
              buildActionTile(
                icon: Icons.upload_file_rounded,
                label: '上传手机文件',
                subtitle: '挂载至 /home/antigravity',
                onTap: () {
                  setState(() => _showToolsSheet = false);
                  widget.onUploadLocalFile?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              buildActionTile(
                icon: Icons.desktop_windows_rounded,
                label: '接管电脑 (Remote)',
                subtitle: '粘贴 /r/<instance> 链接',
                accentColor: cs.tertiary,
                onTap: () {
                  setState(() => _showToolsSheet = false);
                  widget.onOpenRemoteControlLink?.call();
                },
              ),
              const SizedBox(width: 8),
              buildActionTile(
                icon: Icons.extension_outlined,
                label: '云端插件 (/plugin)',
                subtitle: 'GitHub · Drive · Docs',
                onTap: () {
                  setState(() => _showToolsSheet = false);
                  widget.onOpenPlugins?.call();
                },
              ),
              const SizedBox(width: 8),
              buildActionTile(
                icon: Icons.content_paste_go_rounded,
                label: '粘贴剪贴板代码',
                subtitle: '自动包裹 Markdown',
                onTap: _pasteClipboardCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextUsageRingPainter extends CustomPainter {
  const _ContextUsageRingPainter({
    required this.progress,
    required this.trackColor,
    required this.valueColor,
  });

  final double progress;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 4) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final valuePaint = Paint()
      ..color = valueColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ContextUsageRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.valueColor != valueColor;
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter({
    required this.phase,
    required this.color,
  });

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    const count = 28;
    const barWidth = 3.0;
    const gap = 3.5;
    final step = barWidth + gap;
    final totalWidth = math.min(size.width, count * step - gap);
    final startX = (size.width - totalWidth) / 2.0;
    final radius = totalWidth / 2.0;

    for (var i = 0; i < count; i++) {
      final barCenter = startX + i * step + barWidth / 2.0;
      final distFromEdge = math
          .min(barCenter - startX, startX + totalWidth - barCenter)
          .clamp(0.0, radius);
      final d = radius - distFromEdge;
      final envelope = radius > 0
          ? math.sqrt(math.max(0.0, radius * radius - d * d)) / radius
          : 1.0;
      final wave =
          0.32 + 0.68 * math.sin((i * 0.55) + phase * math.pi * 2).abs();
      final h = math.max(3.5, size.height * 0.86 * envelope * wave);
      canvas.drawLine(
        Offset(barCenter, (size.height - h) / 2),
        Offset(barCenter, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
