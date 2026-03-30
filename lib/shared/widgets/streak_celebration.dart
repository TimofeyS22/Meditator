import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/glow_button.dart';

class StreakCelebration extends StatefulWidget {
  const StreakCelebration({
    super.key,
    required this.streakDays,
    required this.onDismiss,
    this.message,
  });

  final int streakDays;
  final VoidCallback onDismiss;
  final String? message;

  @override
  State<StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakTierSpec {
  const _StreakTierSpec({
    required this.accentColor,
    required this.glowColor,
    required this.defaultMessage,
    this.numberGradient,
    this.extraSparkles = false,
  });

  final Color accentColor;
  final Color glowColor;
  final String defaultMessage;
  final Gradient? numberGradient;
  final bool extraSparkles;
}

_StreakTierSpec _tierFor(int days) {
  if (days >= 30) {
    return const _StreakTierSpec(
      accentColor: C.gold,
      glowColor: Color(0x66FBBF24),
      numberGradient: C.gradientGold,
      defaultMessage: 'Месяц практики!',
      extraSparkles: true,
    );
  }
  if (days >= 14) {
    return const _StreakTierSpec(
      accentColor: C.primary,
      glowColor: C.glowPrimary,
      numberGradient: C.gradientAurora,
      defaultMessage: 'Две недели силы!',
    );
  }
  if (days >= 7) {
    return const _StreakTierSpec(
      accentColor: C.gold,
      glowColor: Color(0x50FBBF24),
      defaultMessage: 'Неделя! Ты молодец!',
    );
  }
  if (days >= 3) {
    return const _StreakTierSpec(
      accentColor: C.accent,
      glowColor: C.glowAccent,
      defaultMessage: 'Отличное начало!',
    );
  }
  return const _StreakTierSpec(
    accentColor: C.accent,
    glowColor: C.glowAccent,
    defaultMessage: 'Отличное начало!',
  );
}

class _StreakCelebrationState extends State<StreakCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _blurCtrl;
  late final AnimationController _fireCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _sparkleCtrl;
  bool _motionDepsReady = false;
  bool _reduceMotion = false;

  static const double _badgeSize = 88;

  @override
  void initState() {
    super.initState();
    _blurCtrl = AnimationController(vsync: this, duration: Anim.dramatic);
    _fireCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AccessibilityUtils.reduceMotion(context);
    if (!_motionDepsReady) {
      _motionDepsReady = true;
      _reduceMotion = reduce;
      if (reduce) {
        _blurCtrl.value = 1.0;
      } else {
        _blurCtrl.forward();
      }
      _syncLoopingAnimations();
      return;
    }
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _syncLoopingAnimations();
    }
  }

  void _syncLoopingAnimations() {
    if (_reduceMotion) {
      _fireCtrl.stop();
      _fireCtrl.value = 0.5;
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.0;
      _sparkleCtrl.stop();
      _sparkleCtrl.value = 0.35;
      return;
    }
    if (widget.streakDays >= 7) {
      if (!_fireCtrl.isAnimating) {
        _fireCtrl.repeat();
      }
    } else {
      _fireCtrl.stop();
      _fireCtrl.value = 0.0;
    }
    if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
    if (_tierFor(widget.streakDays).extraSparkles) {
      if (!_sparkleCtrl.isAnimating) {
        _sparkleCtrl.repeat();
      }
    } else {
      _sparkleCtrl.stop();
      _sparkleCtrl.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(StreakCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakDays != widget.streakDays) {
      _syncLoopingAnimations();
    }
  }

  @override
  void dispose() {
    _blurCtrl.dispose();
    _fireCtrl.dispose();
    _pulseCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(widget.streakDays);
    final displayMessage = widget.message ?? tier.defaultMessage;
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    final staggerMs = reduceMotion ? 0 : 100;
    final enterDur = reduceMotion ? Duration.zero : Anim.normal;
    final enterCurve = Anim.curve;
    final springCurve = Anim.curveGentle;

    final numberStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 96,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: tier.numberGradient == null ? tier.accentColor : Colors.white,
        );

    final blurSigma = 14.0 * _blurCtrl.value;

    final semanticLabel =
        'Серия медитаций: ${widget.streakDays} дней подряд. $displayMessage';

    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _blurCtrl,
                builder: (context, _) {
                  return ClipRect(
                    child: BackdropFilter(
                      enabled: blurSigma > 0.01,
                      filter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                      ),
                      child: Builder(
                        builder: (ctx) {
                          return Container(
                            color: ctx.cBgDeep.withValues(alpha: 0.8),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: CelebrationOverlay(
                particleCount: tier.extraSparkles ? 120 : 80,
                duration: AccessibilityUtils.adjustedDuration(
                  context,
                  const Duration(milliseconds: 2800),
                ),
              ),
            ),
            if (tier.extraSparkles)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _sparkleCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: _SparklePainter(
                          progress: _sparkleCtrl.value,
                          color: C.gold,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: S.l),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadge(tier, reduceMotion)
                        .animate()
                        .fadeIn(
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 0),
                        )
                        .slideY(
                          begin: 0.12,
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 0),
                        )
                        .scale(
                          begin: const Offset(0.82, 0.82),
                          end: const Offset(1, 1),
                          duration: enterDur,
                          curve: springCurve,
                          delay: Duration(milliseconds: staggerMs * 0),
                        ),
                    const SizedBox(height: S.xl),
                    _buildNumberSection(tier, numberStyle, reduceMotion)
                        .animate()
                        .fadeIn(
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 1),
                        )
                        .slideY(
                          begin: 0.1,
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 1),
                        )
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                          duration: enterDur,
                          curve: springCurve,
                          delay: Duration(milliseconds: staggerMs * 1),
                        ),
                    const SizedBox(height: S.m),
                    Text(
                      'дней подряд',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: context.cTextSec,
                            fontWeight: FontWeight.w500,
                          ),
                    )
                        .animate()
                        .fadeIn(
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 2),
                        )
                        .slideY(
                          begin: 0.08,
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 2),
                        ),
                    SizedBox(height: S.xl + S.s),
                    Text(
                      displayMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                    )
                        .animate()
                        .fadeIn(
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 3),
                        )
                        .slideY(
                          begin: 0.06,
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 3),
                        ),
                    const SizedBox(height: S.xxl),
                    GlowButton(
                      onPressed: widget.onDismiss,
                      showGlow: true,
                      glowColor: tier.glowColor,
                      semanticLabel: 'Продолжить',
                      width: double.infinity,
                      child: const Text('Продолжить'),
                    )
                        .animate()
                        .fadeIn(
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 4),
                        )
                        .slideY(
                          begin: 0.12,
                          duration: enterDur,
                          curve: enterCurve,
                          delay: Duration(milliseconds: staggerMs * 4),
                        )
                        .scale(
                          begin: const Offset(0.92, 0.92),
                          end: const Offset(1, 1),
                          duration: enterDur,
                          curve: springCurve,
                          delay: Duration(milliseconds: staggerMs * 4),
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

  Widget _buildBadge(_StreakTierSpec tier, bool reduceMotion) {
    final pulseT = reduceMotion ? 0.0 : _pulseCtrl.value;
    final scale = 1.0 + 0.06 * math.sin(pulseT * math.pi);
    final glowSpread = 4 + 10 * pulseT;
    final glowBlur = 18 + 14 * pulseT;

    return ListenableBuilder(
      listenable: _pulseCtrl,
      builder: (context, _) {
        return Transform.scale(
          scale: reduceMotion ? 1.0 : scale,
          child: Container(
            width: _badgeSize + 24,
            height: _badgeSize + 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tier.accentColor.withValues(alpha: 0.35 + 0.25 * pulseT),
                  blurRadius: glowBlur,
                  spreadRadius: -2 + glowSpread * 0.15,
                ),
                BoxShadow(
                  color: tier.glowColor.withValues(alpha: 0.4 + 0.2 * pulseT),
                  blurRadius: glowBlur * 0.65,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: widget.streakDays >= 7
                ? RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _fireCtrl,
                      builder: (context, _) => CustomPaint(
                        size: const Size(_badgeSize, _badgeSize),
                        painter: _FirePainter(
                          color: tier.accentColor,
                          size: _badgeSize,
                          flicker: reduceMotion ? 0.5 : _fireCtrl.value,
                        ),
                      ),
                    ),
                  )
                : CustomPaint(
                    size: const Size(_badgeSize, _badgeSize),
                    painter: _BoltPainter(
                      color: tier.accentColor,
                      size: _badgeSize,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildNumberSection(
    _StreakTierSpec tier,
    TextStyle? numberStyle,
    bool reduceMotion,
  ) {
    final dur = AccessibilityUtils.adjustedDuration(
      context,
      const Duration(milliseconds: 900),
    );
    final child = AnimatedNumber(
      value: widget.streakDays,
      duration: dur,
      style: numberStyle,
    );

    if (tier.numberGradient == null) {
      return child;
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => tier.numberGradient!.createShader(bounds),
      child: AnimatedNumber(
        value: widget.streakDays,
        duration: dur,
        style: numberStyle?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _FirePainter extends CustomPainter {
  _FirePainter({
    required this.color,
    required this.size,
    required this.flicker,
  });

  final Color color;
  final double size;
  final double flicker;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final w = size;
    final h = size;
    final cx = w * 0.5;
    final baseY = h * 0.78;
    final flick = 0.92 + 0.08 * math.sin(flicker * math.pi * 2);
    final flick2 = 0.96 + 0.04 * math.sin(flicker * math.pi * 2 * 1.7 + 0.8);

    final main = Path()
      ..moveTo(cx, h * 0.08 * flick)
      ..quadraticBezierTo(w * 0.92, h * 0.35 * flick2, w * 0.78, baseY)
      ..quadraticBezierTo(w * 0.55, h * 0.95, cx, baseY)
      ..quadraticBezierTo(w * 0.45, h * 0.95, w * 0.22, baseY)
      ..quadraticBezierTo(w * 0.08, h * 0.35 * flick2, cx, h * 0.08 * flick)
      ..close();

    final inner = Path()
      ..moveTo(cx, h * 0.22 * flick)
      ..quadraticBezierTo(w * 0.72, h * 0.42 * flick2, w * 0.62, h * 0.68)
      ..quadraticBezierTo(cx, h * 0.82, w * 0.38, h * 0.68)
      ..quadraticBezierTo(w * 0.28, h * 0.42 * flick2, cx, h * 0.22 * flick)
      ..close();

    final tip = Path()
      ..moveTo(cx, h * 0.18 * flick)
      ..quadraticBezierTo(w * 0.62, h * 0.32 * flick2, w * 0.52, h * 0.48)
      ..quadraticBezierTo(cx, h * 0.38, w * 0.48, h * 0.48)
      ..quadraticBezierTo(w * 0.38, h * 0.32 * flick2, cx, h * 0.18 * flick)
      ..close();

    final fill = Paint()..style = PaintingStyle.fill;
    canvas.drawPath(
      main,
      fill..color = color.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      inner,
      fill..color = color.withValues(alpha: 0.55),
    );
    canvas.drawPath(
      tip,
      fill..color = Colors.white.withValues(alpha: 0.35 + 0.15 * flicker),
    );
  }

  @override
  bool shouldRepaint(_FirePainter old) =>
      old.flicker != flicker || old.color != color || old.size != size;
}

class _BoltPainter extends CustomPainter {
  _BoltPainter({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  Path _boltPath() {
    final w = size;
    final h = size;
    final p = Path();
    p.moveTo(w * 0.62, h * 0.08);
    p.lineTo(w * 0.28, h * 0.46);
    p.lineTo(w * 0.48, h * 0.48);
    p.lineTo(w * 0.22, h * 0.94);
    p.lineTo(w * 0.72, h * 0.42);
    p.lineTo(w * 0.52, h * 0.4);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final path = _boltPath();
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.save();
    canvas.translate(size * 0.5, size * 0.5);
    canvas.scale(1.08);
    canvas.translate(-size * 0.5, -size * 0.5);
    canvas.drawPath(path, glowPaint);
    canvas.restore();

    final soft = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, soft);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.025
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.color != color || old.size != size;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.progress,
    required this.color,
    required this.reduceMotion,
  });

  final double progress;
  final Color color;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final seed = i * 7919;
      final sx = (math.sin(seed * 0.01) * 0.5 + 0.5) * size.width;
      final sy = (math.cos(seed * 0.013) * 0.5 + 0.5) * size.height;
      final phase = (seed % 628) / 100.0;
      final tw = reduceMotion
          ? 0.75
          : (math.sin(progress * math.pi * 2 + phase) * 0.5 + 0.5);
      final r = 1.8 + (i % 4) * 0.9;
      paint.color = color.withValues(alpha: 0.15 + 0.55 * tw);
      _drawDiamond(canvas, Offset(sx, sy), r, paint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.55, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.55, c.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.reduceMotion != reduceMotion;
}
