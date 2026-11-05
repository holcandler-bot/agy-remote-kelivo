import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/agent_models.dart';
import '../theme/app_themes.dart';
import 'kelivo_aurora_background.dart';

const double _kTimelineIconColumnWidth = 24.0;
const double _kTimelineIconSize = 18.0;
const double _kTimelineGap = 8.0;
const double _kTimelineLineGap = 3.0;
const double _kTimelineLineX = 11.5;

class KelivoMessageItem extends StatefulWidget {
  final AgentChatTurn turn;
  final ChatBubbleStyleSpec bubbleStyle;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final VoidCallback? onApproveTool;
  final VoidCallback? onDenyTool;
  final VoidCallback? onSwitchFullAccess;

  const KelivoMessageItem({
    super.key,
    required this.turn,
    this.bubbleStyle = const ChatBubbleStyleSpec(),
    this.onCopy,
    this.onRegenerate,
    this.onApproveTool,
    this.onDenyTool,
    this.onSwitchFullAccess,
  });

  @override
  State<KelivoMessageItem> createState() => _KelivoMessageItemState();
}

class _KelivoMessageItemState extends State<KelivoMessageItem> {
  bool _thinkingExpanded = false;
  bool _showTranslatedSummary = false;
  late int _branchIdx;
  final Set<String> _expandedToolIds = {};

  @override
  void initState() {
    super.initState();
    _branchIdx = widget.turn.branchIndex;
  }

  void _copyWithToast(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    widget.onCopy?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制$label到剪贴板'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTurnSourceInspector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '原始响应与工具调用载荷 (${widget.turn.modelName})',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: AppFontWeights.semibold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IosIconButton(
                      icon: Icons.content_copy_rounded,
                      size: 16,
                      onTap: () {
                        Navigator.pop(ctx);
                        _copyWithToast(context, widget.turn.content, '完整响应源码');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.chatQuietFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.hairlineBorder,
                          width: 0.6,
                        ),
                      ),
                      child: SelectableText(
                        [
                          if (widget.turn.thinking.isNotEmpty)
                            '/* --- THINKING (${widget.turn.thinkingDuration}) --- */\n${widget.turn.thinking}\n',
                          '/* --- CONTENT --- */\n${widget.turn.content}',
                          if (widget.turn.codeBlocks.isNotEmpty)
                            '\n/* --- DIFF / CODE BLOCKS --- */\n${widget.turn.codeBlocks.join("\n\n")}',
                        ].join('\n'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          fontFamily: 'monospace',
                          color: cs.onSurface.withValues(alpha: 0.84),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _inferDiffFilePath(String code) {
    for (final tool in widget.turn.toolCalls) {
      if ((tool.filePath ?? '').isNotEmpty) {
        return tool.filePath!;
      }
    }
    for (final line in code.split('\n')) {
      if (line.startsWith('+++ b/')) {
        return line.substring(6).trim();
      }
      if (line.startsWith('// File:') || line.startsWith('# File:')) {
        return line.split(':').last.trim();
      }
    }
    return 'src/auth/token_manager.ts';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.turn.isUser) {
      return _buildUserMessage(context);
    }
    return _buildAssistantMessage(context);
  }

  Widget _buildUserMessage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(4),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          KelivoSharedSurface(
            style: widget.bubbleStyle,
            borderRadius: radius,
            defaultColor: cs.primary.withValues(alpha: isDark ? 0.16 : 0.09),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SelectableText(
              widget.turn.content,
              style: TextStyle(
                fontSize: 15.2,
                height: 1.48,
                fontWeight: AppFontWeights.regular,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.turn.timestamp,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.44),
                ),
              ),
              const SizedBox(width: 6),
              IosIconButton(
                icon: Icons.content_copy_rounded,
                size: 13,
                padding: const EdgeInsets.all(4),
                color: cs.onSurface.withValues(alpha: 0.46),
                onTap: () => _copyWithToast(context, widget.turn.content, '提问内容'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final hasChainOfThought =
        widget.turn.thinking.isNotEmpty || widget.turn.toolCalls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kelivo Assistant Header
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.secondary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.hairlineBorder,
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 15,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.turn.modelName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.chatQuietFill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Remote Sandbox',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: AppFontWeights.medium,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.turn.timestamp,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Kelivo `_ChainOfThoughtCard` (Unified Reasoning + Workspace Tools Timeline)
          if (hasChainOfThought) ...[
            _buildChainOfThoughtCard(context),
            const SizedBox(height: 12),
          ],

          // 3. Markdown Body Text (`15.5px`, `height: 1.52`)
          if (widget.turn.content.isNotEmpty)
            SelectableText(
              widget.turn.content,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.52,
                fontWeight: AppFontWeights.regular,
                color: cs.onSurface,
              ),
            ),

          if (_showTranslatedSummary) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.24),
                  width: 0.8,
                ),
              ),
              child: Text(
                widget.turn.translatedContent ??
                    '【双语结构化摘要】\n• 已同步远端容器执行结果与 AST 代码差异；\n• 共涉及 ${widget.turn.toolCalls.length} 项工具调用与 ${widget.turn.codeBlocks.length} 处代码补丁。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.48,
                  color: cs.onSurface.withValues(alpha: 0.86),
                ),
              ),
            ),
          ],

          // 4. Kelivo `UnifiedDiffView` Blocks
          for (final block in widget.turn.codeBlocks) ...[
            const SizedBox(height: 10),
            _UnifiedDiffCard(
              code: block,
              filePath: _inferDiffFilePath(block),
              bubbleStyle: widget.bubbleStyle,
              onCopied: () => _copyWithToast(context, block, '代码补丁'),
            ),
          ],

          // 5. Kelivo `ProducedFilesRow` Summary Chips
          if (widget.turn.toolCalls.any((t) => (t.filePath ?? '').isNotEmpty)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in widget.turn.toolCalls.where(
                  (t) => (t.filePath ?? '').isNotEmpty,
                ))
                  _WorkspaceFileChip(
                    filePath: tool.filePath!,
                    added: tool.addedLines,
                    removed: tool.removedLines,
                  ),
              ],
            ),
          ],

          // 6. Kelivo Bottom Message Action Bar + Branch Selector + TokenDisplayWidget
          const SizedBox(height: 8),
          Row(
            children: [
              IosIconButton(
                icon: Icons.content_copy_rounded,
                size: 15,
                padding: const EdgeInsets.all(6),
                tooltip: '复制回复内容',
                onTap: () => _copyWithToast(context, widget.turn.content, '回复内容'),
              ),
              IosIconButton(
                icon: Icons.refresh_rounded,
                size: 16,
                padding: const EdgeInsets.all(6),
                tooltip: '重新生成此回复',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onRegenerate != null) {
                    widget.onRegenerate!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已向云端 Remote Agent 请求重新生成该轮响应'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              IosIconButton(
                icon: Icons.code_rounded,
                size: 16,
                padding: const EdgeInsets.all(6),
                tooltip: '查看原始 Markdown 与载荷',
                onTap: () => _showTurnSourceInspector(context),
              ),
              IosIconButton(
                icon: Icons.translate_rounded,
                size: 15,
                padding: const EdgeInsets.all(6),
                tooltip: '切换结构化摘要视图',
                color: _showTranslatedSummary
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.72),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(
                    () => _showTranslatedSummary = !_showTranslatedSummary,
                  );
                },
              ),
              const SizedBox(width: 4),
              // Interactive `_BranchSelector` (`< 2/2 >`)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.chatQuietFill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final total = math.max(2, widget.turn.branchTotal);
                          _branchIdx = _branchIdx > 1 ? _branchIdx - 1 : total;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 15,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    Text(
                      '$_branchIdx/${math.max(2, widget.turn.branchTotal)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: AppFontWeights.medium,
                        color: cs.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final total = math.max(2, widget.turn.branchTotal);
                          _branchIdx = _branchIdx < total ? _branchIdx + 1 : 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // `TokenDisplayWidget`
              Text(
                widget.turn.tokenStats,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: cs.onSurface.withValues(alpha: 0.44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChainOfThoughtCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasReasoning = widget.turn.thinking.isNotEmpty;
    final tools = widget.turn.toolCalls;
    final totalSteps = (hasReasoning ? 1 : 0) + tools.length;

    final stepWidgets = <Widget>[];
    var currentIndex = 0;

    if (hasReasoning) {
      final isFirst = currentIndex == 0;
      final isLast = currentIndex == totalSteps - 1;
      currentIndex++;
      stepWidgets.add(
        _TimelineStepShell(
          isFirst: isFirst,
          isLast: isLast,
          onTap: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
          icon: Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: cs.primary,
          ),
          label: ThinkingSheen(
            active: widget.turn.thinkingActive,
            baseColor: cs.onSurface.withValues(alpha: 0.86),
            child: Row(
              children: [
                Text(
                  widget.turn.thinkingActive ? '正在深度思考...' : '已深度思考',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${widget.turn.thinkingDuration})',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: cs.onSurface.withValues(alpha: 0.52),
                  ),
                ),
                if (widget.turn.thinkingActive) ...[
                  const SizedBox(width: 6),
                  const KelivoLoadingIndicator(size: 16),
                ],
              ],
            ),
          ),
          indicator: AnimatedRotation(
            turns: _thinkingExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 240),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.54),
            ),
          ),
          contentVisible: _thinkingExpanded,
          content: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x26000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x1A000000),
                ],
                stops: [0.0, 0.12, 0.82, 1.0],
              ).createShader(bounds);
            },
            child: Container(
              padding: const EdgeInsets.only(left: 10, top: 4, bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: cs.primary.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                widget.turn.thinking,
                style: TextStyle(
                  fontSize: 12.8,
                  height: 1.56,
                  color: cs.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < tools.length; i++) {
      final tool = tools[i];
      final isFirst = currentIndex == 0;
      final isLast = currentIndex == totalSteps - 1;
      currentIndex++;
      final isPending = tool.status == 'pending';
      final isExpanded = _expandedToolIds.contains(tool.id) ||
          isPending ||
          tool.shellTail.isNotEmpty ||
          (tool.filePath ?? '').isNotEmpty;

      stepWidgets.add(
        _TimelineStepShell(
          isFirst: isFirst,
          isLast: isLast,
          onTap: () {
            setState(() {
              if (_expandedToolIds.contains(tool.id)) {
                _expandedToolIds.remove(tool.id);
              } else {
                _expandedToolIds.add(tool.id);
              }
            });
          },
          icon: Icon(
            _iconForTool(tool.type),
            size: 15,
            color: isPending ? context.appColors.warning : cs.primary,
          ),
          label: Text(
            tool.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.88),
            ),
          ),
          extra: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IosIconButton(
                      icon: Icons.close_rounded,
                      size: 14,
                      padding: const EdgeInsets.all(5),
                      color: cs.error,
                      onTap: widget.onDenyTool,
                    ),
                    const SizedBox(width: 4),
                    IosIconButton(
                      icon: Icons.check_rounded,
                      size: 14,
                      padding: const EdgeInsets.all(5),
                      color: context.appColors.success,
                      onTap: widget.onApproveTool,
                    ),
                  ],
                )
              : tool.statusText.isNotEmpty
                  ? Text(
                      tool.statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: cs.onSurface.withValues(alpha: 0.50),
                      ),
                    )
                  : null,
          indicator: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 240),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.46),
            ),
          ),
          contentVisible: isExpanded,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tool.detail.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    tool.detail,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ),
              if ((tool.filePath ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _WorkspaceFileChip(
                    filePath: tool.filePath!,
                    added: tool.addedLines,
                    removed: tool.removedLines,
                  ),
                ),
              if (tool.shellTail.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.chatQuietFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tool.shellTail.take(4).join('\n'),
                    style: TextStyle(
                      fontSize: 11.2,
                      height: 1.42,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              if (isPending)
                IosCardPress(
                  onTap: widget.onSwitchFullAccess,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gpp_maybe_outlined,
                        size: 14,
                        color: context.appColors.warning,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '切换为当前会话完全访问权限 (Full Access)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFontWeights.medium,
                          color: context.appColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return KelivoSharedSurface(
      style: widget.bubbleStyle,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      defaultColor: cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stepWidgets,
      ),
    );
  }

  IconData _iconForTool(String type) {
    switch (type) {
      case 'bash':
        return Icons.terminal_rounded;
      case 'edit':
        return Icons.edit_note_rounded;
      case 'search':
        return Icons.manage_search_rounded;
      case 'read':
      default:
        return Icons.description_outlined;
    }
  }
}

/// Kelivo `_TimelineStepShell` with 24px `_TimelineIconColumn` and 1px vertical connector line.
class _TimelineStepShell extends StatelessWidget {
  const _TimelineStepShell({
    required this.icon,
    required this.label,
    required this.isFirst,
    required this.isLast,
    this.onTap,
    this.extra,
    this.indicator,
    this.content,
    this.contentVisible = false,
  });

  final Widget icon;
  final Widget label;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? extra;
  final Widget? indicator;
  final Widget? content;
  final bool contentVisible;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16);

    final header = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const SizedBox(
                width: _kTimelineIconColumnWidth,
                height: _kTimelineIconSize,
              ),
              const SizedBox(width: _kTimelineGap),
              Expanded(child: label),
              if (extra != null) ...[const SizedBox(width: 8), extra!],
              if (indicator != null) ...[const SizedBox(width: 4), indicator!],
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _kTimelineIconColumnWidth,
          child: CustomPaint(
            painter: _TimelineLinePainter(
              isFirst: isFirst,
              isLast: isLast && !contentVisible,
              lineColor: lineColor,
            ),
            child: Center(child: icon),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IosCardPress(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          pressedScale: 1.0,
          padding: EdgeInsets.zero,
          child: header,
        ),
        Stack(
          children: [
            if (!isLast && contentVisible)
              Positioned(
                left: _kTimelineLineX,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 1,
                  child: ColoredBox(color: lineColor),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              alignment: Alignment.topLeft,
              child: (content != null && contentVisible)
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: _kTimelineIconColumnWidth + _kTimelineGap,
                        top: 2,
                        bottom: 8,
                      ),
                      child: content,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineLinePainter extends CustomPainter {
  const _TimelineLinePainter({
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
  });

  final bool isFirst;
  final bool isLast;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    final iconTop = (size.height - _kTimelineIconSize) / 2;
    final iconBottom = iconTop + _kTimelineIconSize;
    if (!isFirst) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, math.max(0, iconTop - _kTimelineLineGap)),
        paint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(x, math.min(size.height, iconBottom + _kTimelineLineGap)),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineLinePainter oldDelegate) {
    return oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Kelivo `WorkspaceFileChip` (`workspace_tool_ui.dart` L809 `showWorkspaceToolDetail`).
class _WorkspaceFileChip extends StatelessWidget {
  const _WorkspaceFileChip({
    required this.filePath,
    required this.added,
    required this.removed,
  });

  final String filePath;
  final int added;
  final int removed;

  void _showToolDetailInspector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.code_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filePath,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontFamily: 'monospace',
                          fontWeight: AppFontWeights.semibold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IosIconButton(
                      icon: Icons.content_copy_rounded,
                      size: 16,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: filePath));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已复制文件路径: $filePath'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.chatQuietFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.hairlineBorder, width: 0.6),
                  ),
                  child: Text(
                    'Sandbox Path: /workspace/agy-cloud-core/$filePath\n'
                    'AST Hunks: +$added lines added, −$removed lines removed\n'
                    'Execution Latency: 180ms (Remote Container Verified)',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final fileName = filePath.split('/').last;

    return IosCardPress(
      onTap: () => _showToolDetailInspector(context),
      baseColor: colors.chatQuietFill,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.code_rounded,
            size: 13,
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 5),
          Text(
            fileName,
            style: TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          if (added > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+$added',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: AppFontWeights.semibold,
                color: colors.success,
              ),
            ),
          ],
          if (removed > 0) ...[
            const SizedBox(width: 4),
            Text(
              '−$removed',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: AppFontWeights.semibold,
                color: cs.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kelivo `UnifiedDiffView` (`unified_diff_view.dart`).
class _UnifiedDiffCard extends StatelessWidget {
  const _UnifiedDiffCard({
    required this.code,
    required this.filePath,
    required this.bubbleStyle,
    this.onCopied,
  });

  final String code;
  final String filePath;
  final ChatBubbleStyleSpec bubbleStyle;
  final VoidCallback? onCopied;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final lines = code.split('\n');
    int added = 0;
    int removed = 0;
    for (final l in lines) {
      if (l.startsWith('+') && !l.startsWith('+++')) added++;
      if (l.startsWith('-') && !l.startsWith('---')) removed++;
    }

    return KelivoSharedSurface(
      style: bubbleStyle,
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `_DiffHeader`
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colors.chatQuietFill,
              border: Border(
                bottom: BorderSide(color: colors.hairlineBorder, width: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.difference_outlined,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    filePath,
                    style: TextStyle(
                      fontSize: 11.8,
                      fontFamily: 'monospace',
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (added > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+$added',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: AppFontWeights.semibold,
                        color: colors.success,
                      ),
                    ),
                  ),
                if (removed > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '−$removed',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: AppFontWeights.semibold,
                        color: cs.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                IosIconButton(
                  icon: Icons.content_copy_rounded,
                  size: 13,
                  padding: const EdgeInsets.all(4),
                  onTap: () {
                    if (onCopied != null) {
                      onCopied!();
                    } else {
                      Clipboard.setData(ClipboardData(text: code));
                    }
                  },
                ),
              ],
            ),
          ),
          // Diff lines
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) _buildDiffLine(context, line),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(BuildContext context, String line) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final isAdd = line.startsWith('+') && !line.startsWith('+++');
    final isDel = line.startsWith('-') && !line.startsWith('---');
    final isHunk = line.startsWith('@@');

    Color bg = Colors.transparent;
    Color fg = cs.onSurface.withValues(alpha: 0.84);
    if (isAdd) {
      bg = colors.success.withValues(alpha: 0.14);
      fg = colors.success;
    } else if (isDel) {
      bg = cs.error.withValues(alpha: 0.14);
      fg = cs.error;
    } else if (isHunk) {
      fg = cs.primary.withValues(alpha: 0.72);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
      color: bg,
      child: Text(
        line,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          fontFamily: 'monospace',
          color: fg,
        ),
      ),
    );
  }
}
