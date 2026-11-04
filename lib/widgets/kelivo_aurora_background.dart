import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_themes.dart';

/// Kelivo `_GradientArtwork` Aurora Mesh Background (`chat_gradient_background.dart`).
/// Renders a 5-stop vertical base gradient overlaid with 4 drifting radial blobs.
class KelivoAuroraBackground extends StatefulWidget {
  const KelivoAuroraBackground({
    super.key,
    required this.palette,
    required this.enabled,
    required this.child,
  });

  final KelivoPalette palette;
  final bool enabled;
  final Widget child;

  @override
  State<KelivoAuroraBackground> createState() => _KelivoAuroraBackgroundState();
}

class _KelivoAuroraBackgroundState extends State<KelivoAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: widget.child,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blobs = isDark
        ? widget.palette.darkAuroraBlobs
        : widget.palette.lightAuroraBlobs;

    final baseStops = isDark
        ? const [
            Color(0xFF1B2A45),
            Color(0xFF15223A),
            Color(0xFF0D1626),
            Color(0xFF0A0F18),
            Color(0xFF080B12),
          ]
        : const [
            Color(0xFFAFD0F2),
            Color(0xFFCBE0F6),
            Color(0xFFF1F7FD),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
          ];

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              return CustomPaint(
                painter: _AuroraMeshPainter(
                  phase: t,
                  isDark: isDark,
                  baseStops: baseStops,
                  blobs: blobs,
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraMeshPainter extends CustomPainter {
  const _AuroraMeshPainter({
    required this.phase,
    required this.isDark,
    required this.baseStops,
    required this.blobs,
  });

  final double phase;
  final bool isDark;
  final List<Color> baseStops;
  final List<Color> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: baseStops,
        stops: const [0.0, 0.22, 0.45, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final centers = <Offset>[
      Offset(
        size.width * (0.18 + 0.08 * math.sin(phase)),
        size.height * (0.16 + 0.06 * math.cos(phase * 0.8)),
      ),
      Offset(
        size.width * (0.82 + 0.07 * math.cos(phase * 0.9)),
        size.height * (0.24 + 0.07 * math.sin(phase * 1.1)),
      ),
      Offset(
        size.width * (0.26 + 0.09 * math.cos(phase * 0.7)),
        size.height * (0.64 + 0.06 * math.sin(phase * 0.9)),
      ),
      Offset(
        size.width * (0.76 + 0.08 * math.sin(phase * 0.85)),
        size.height * (0.78 + 0.05 * math.cos(phase)),
      ),
    ];

    final radii = <double>[
      size.shortestSide * 0.68,
      size.shortestSide * 0.62,
      size.shortestSide * 0.72,
      size.shortestSide * 0.64,
    ];

    final alphas = isDark
        ? const [0.52, 0.42, 0.44, 0.32]
        : const [0.46, 0.38, 0.40, 0.30];

    for (var i = 0; i < 4 && i < blobs.length; i++) {
      final c = centers[i];
      final r = radii[i];
      final color = blobs[i];
      final blobPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alphas[i]),
            color.withValues(alpha: alphas[i] * 0.35),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, blobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraMeshPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isDark != isDark ||
        oldDelegate.blobs != blobs;
  }
}

/// Kelivo `FrostedSurface` (`chat_surface.dart` & `chat_bubble_style.dart`).
/// Implements sigma-14 backdrop blur with 0.66 surface opacity and 0.8px hairline border.
class KelivoSharedSurface extends StatelessWidget {
  const KelivoSharedSurface({
    super.key,
    required this.child,
    this.style = const ChatBubbleStyleSpec(),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding,
    this.defaultColor,
  });

  final Widget child;
  final ChatBubbleStyleSpec style;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? defaultColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (style.preset == ChatBubblePreset.frosted) {
      final baseTint = defaultColor ??
          (isDark
              ? Color.alphaBlend(
                  cs.primary.withValues(alpha: 0.10),
                  cs.surfaceContainerHigh,
                )
              : Colors.white);
      final fillColor = baseTint.withValues(alpha: style.frostedOpacity);
      final borderColor = (isDark ? Colors.white : cs.outlineVariant)
          .withValues(alpha: style.borderOpacity);

      Widget content = Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: borderRadius,
          border: Border.all(
            color: borderColor,
            width: style.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.08],
          ),
        ),
        child: child,
      );

      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: style.blurSigma,
            sigmaY: style.blurSigma,
          ),
          child: content,
        ),
      );
    }

    final solidColor = defaultColor ??
        cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.30);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: solidColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: context.appColors.hairlineBorder,
          width: 0.6,
        ),
      ),
      child: child,
    );
  }
}

/// Kelivo `ThinkingSheen` (`thinking_sheen.dart`).
/// Sliding 7-stop metallic gradient `ShaderMask` over active reasoning headers.
class ThinkingSheen extends StatefulWidget {
  const ThinkingSheen({
    super.key,
    required this.active,
    required this.baseColor,
    required this.child,
  });

  final bool active;
  final Color baseColor;
  final Widget child;

  @override
  State<ThinkingSheen> createState() => _ThinkingSheenState();
}

class _ThinkingSheenState extends State<ThinkingSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant ThinkingSheen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    // Kelivo `thinking_sheen.dart` L34-L40:
    // Dark mode lifts toward white; Light mode inverts toward deep primary/ink so it never washes out.
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : cs.primary;
    final peak = isDark
        ? Colors.white
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.85), Colors.black);
    final dim = widget.baseColor.withValues(alpha: isDark ? 0.45 : 0.35);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final slide = -1.0 + (_ctrl.value * 3.0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(slide - 0.6, -0.2),
              end: Alignment(slide + 0.6, 0.2),
              colors: [
                widget.baseColor,
                dim,
                highlight,
                peak,
                highlight,
                dim,
                widget.baseColor,
              ],
              stops: const [0.0, 0.28, 0.44, 0.50, 0.56, 0.72, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Kelivo 3-dot phase-shifted sine-wave `LoadingIndicator` (`chat_message_widget.dart` L4482-L4556).
class KelivoLoadingIndicator extends StatefulWidget {
  const KelivoLoadingIndicator({
    super.key,
    this.size = 18,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  State<KelivoLoadingIndicator> createState() => _KelivoLoadingIndicatorState();
}

class _KelivoLoadingIndicatorState extends State<KelivoLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _DotsWavePainter(
              progress: _ctrl.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _DotsWavePainter extends CustomPainter {
  const _DotsWavePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = size.width * 0.11;
    final cy = size.height / 2;
    final spacing = size.width * 0.28;
    final startX = (size.width - spacing * 2) / 2;

    for (var i = 0; i < 3; i++) {
      final phase = (progress - i * 0.20) * 2 * math.pi;
      final wave = 0.5 + 0.5 * math.sin(phase);
      final alpha = (0.20 + 0.80 * wave).clamp(0.0, 1.0);
      final r = baseRadius * (0.85 + 0.30 * wave);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(startX + i * spacing, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Kelivo `IosCardPress` (`ios_tactile.dart`).
/// Provides smooth 200ms `easeOutCubic` color wash and subtle scale physics without Material ripple.
class IosCardPress extends StatefulWidget {
  const IosCardPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.baseColor = Colors.transparent,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding,
    this.pressedScale = 0.985,
    this.haptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color baseColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double pressedScale;
  final bool haptics;

  @override
  State<IosCardPress> createState() => _IosCardPressState();
}

class _IosCardPressState extends State<IosCardPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wash = cs.onSurface.withValues(alpha: isDark ? 0.09 : 0.06);
    final targetColor = _pressed
        ? Color.alphaBlend(wash, widget.baseColor)
        : widget.baseColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null || widget.onLongPress != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null || widget.onLongPress != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null || widget.onLongPress != null
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: targetColor,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Kelivo `IosIconButton` (`ios_tactile.dart`).
class IosIconButton extends StatefulWidget {
  const IosIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 20,
    this.color,
    this.padding = const EdgeInsets.all(6),
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  @override
  State<IosIconButton> createState() => _IosIconButtonState();
}

class _IosIconButtonState extends State<IosIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.color ?? cs.onSurface.withValues(alpha: 0.72);
    final btn = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _pressed
              ? cs.onSurface.withValues(alpha: 0.10)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: _pressed ? cs.primary : fg,
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}
