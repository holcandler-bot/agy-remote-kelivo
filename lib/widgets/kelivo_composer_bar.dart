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
  final String thinkingBudget;
  final bool webSearchEnabled;
  final bool fullAccessEnabled;
  final double contextUsage; // 0.0 - 1.0
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

  const KelivoComposerBar({
    super.key,
    required this.controller,
    required this.approval,
    this.currentBranch = 'feat/token-lock',
    required this.thinkingBudget,
    required this.webSearchEnabled,
    this.fullAccessEnabled = false,
    this.contextUsage = 0.24,
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

  static const _slashItems = [
    ('/plan', '生成架构重构与分步执行计划'),
    ('/diff', '审查当前远端分支 Unified Diff'),
    ('/test', '在云端沙盒运行单元测试套件'),
    ('/compact', '压缩当前长对话上下文以释放额度'),
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
              ? '请检查当前云端仓库的构建状态并运行测试套件'
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
          content: Text('剪贴板为空，请先复制代码或报错日志'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Kelivo `EnvironmentStatusChip` + Pending Approval Chip Row
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  IosCardPress(
                    onTap: widget.onToggleFullAccess,
                    borderRadius: BorderRadius.circular(999),
                    baseColor: cs.onSurface.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          size: 13,
                          color: widget.fullAccessEnabled
                              ? colors.warning
                              : colors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.fullAccessEnabled
                              ? 'Full Access · ${widget.currentBranch}'
                              : 'Cloud Sandbox · ${widget.currentBranch}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.approval.pending) ...[
                    IosCardPress(
                      onTap: widget.onApprove,
                      borderRadius: BorderRadius.circular(999),
                      baseColor: colors.warning.withValues(alpha: 0.16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gpp_maybe_outlined,
                            size: 13,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '点击批准: ${widget.approval.commandOrFile}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: AppFontWeights.semibold,
                              color: colors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IosCardPress(
                      onTap: widget.onDeny,
                      borderRadius: BorderRadius.circular(999),
                      baseColor: cs.error.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text(
                        '拒绝',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: AppFontWeights.semibold,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 2. Slash Quick Prompt Drawer (`/`)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _showSlashDrawer
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.surfaceLadder.l2Card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.hairlineBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        children: _slashItems.map((item) {
                          return IosCardPress(
                            onTap: () {
                              setState(() => _showSlashDrawer = false);
                              widget.onQuickCommand(item.$1);
                            },
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
                                    item.$1,
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
                                  child: Text(
                                    item.$2,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: cs.onSurface.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // 3. Kelivo 20px Frosted Glass `ChatInputBar` (`chat_input_bar.dart`)
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
                                final shouldShow = val.startsWith('/');
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
                                hintText: '向云端 Remote Agent 发送指令... (输入 / 唤醒技能)',
                                hintStyle: TextStyle(
                                  fontSize: 14.5,
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

                      // Bottom `_buildResponsiveLeftActions` or `_VoiceWaveform`
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

            // 4. Kelivo `BottomToolsSheet` (`bottom_tools_sheet.dart`)
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
        // 1. Model Avatar Button (opens Model Picker Sheet)
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

        // 2. Reasoning Lightbulb + Compact Badge (`High`)
        IosCardPress(
          onTap: widget.onCycleThinking,
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 19,
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

        // 3. Web Search Toggle (`Lucide.Globe`)
        IosIconButton(
          icon: Icons.travel_explore_rounded,
          size: 19,
          padding: const EdgeInsets.all(6),
          tooltip: widget.webSearchEnabled ? '已开启联网检索' : '已关闭联网检索',
          color: widget.webSearchEnabled
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.54),
          onTap: widget.onToggleWebSearch,
        ),

        // 4. Workspace Tool & Permission Dot (`Lucide.FolderCode` + `ToolPermissionDot`)
        Stack(
          clipBehavior: Clip.none,
          children: [
            IosIconButton(
              icon: Icons.folder_copy_outlined,
              size: 19,
              padding: const EdgeInsets.all(6),
              tooltip: widget.fullAccessEnabled
                  ? 'Full Access 免确认模式'
                  : '标准安全审批模式',
              color: widget.fullAccessEnabled ? colors.warning : cs.primary,
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
                      ? colors.warning
                      : colors.success,
                ),
              ),
            ),
          ],
        ),

        // 5. Quick Prompt Slash Toggle (`Lucide.Zap`)
        IosIconButton(
          icon: Icons.bolt_rounded,
          size: 19,
          padding: const EdgeInsets.all(6),
          tooltip: '快捷指令面板 (/)',
          color: _showSlashDrawer
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.54),
          onTap: () => setState(() => _showSlashDrawer = !_showSlashDrawer),
        ),

        const Spacer(),

        // Right Cluster:
        // 6. `ContextUsageRing` (18x18 circular progress gauge)
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '当前云端会话上下文占用 ${(widget.contextUsage * 100).round()}% · 输入 /compact 可释放上下文',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
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
                valueColor: cs.primary,
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
              color: (hasText || widget.isStreaming)
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.12),
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
      required VoidCallback onTap,
      Color? accentColor,
    }) {
      return Expanded(
        child: IosCardPress(
          onTap: onTap,
          baseColor: colors.chatQuietFill,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 21,
                color: accentColor ?? cs.onSurface.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          buildActionTile(
            icon: Icons.login_rounded,
            label: '登录 Google',
            accentColor: cs.primary,
            onTap: () {
              setState(() => _showToolsSheet = false);
              widget.onOpenGoogleLogin?.call();
            },
          ),
          const SizedBox(width: 8),
          buildActionTile(
            icon: Icons.content_paste_go_rounded,
            label: '粘贴剪贴板代码',
            onTap: _pasteClipboardCode,
          ),
          const SizedBox(width: 8),
          buildActionTile(
            icon: Icons.difference_outlined,
            label: '审查分支 Diff',
            onTap: () {
              setState(() => _showToolsSheet = false);
              widget.onQuickCommand('/diff 请审查当前分支修改并指出潜在风险');
            },
          ),
          const SizedBox(width: 8),
          buildActionTile(
            icon: Icons.tune_rounded,
            label: '账号与设置',
            onTap: () {
              setState(() => _showToolsSheet = false);
              widget.onOpenSettings?.call();
            },
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
