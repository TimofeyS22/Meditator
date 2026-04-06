import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:meditator/shared/theme/cosmic.dart';

// ─── Presence State Machine ──────────────────────────────────────────────────

enum PresenceState {
  observing,
  responding,
  supporting,
  guiding,
  calming,
  silent,
}

class _PresenceConfig {
  final double breathPeriodMs;
  final double scaleMin;
  final double scaleRange;
  final double glowAlphaBase;
  final double glowAlphaRange;
  final double glowBlurBase;
  final double glowBlurRange;
  final double floatAmplitude;
  final double floatPeriodMs;
  final double shimmerSpeed;
  final double outerHaloAlpha;

  const _PresenceConfig({
    required this.breathPeriodMs,
    this.scaleMin = 0.92,
    this.scaleRange = 0.08,
    this.glowAlphaBase = 0.25,
    this.glowAlphaRange = 0.15,
    this.glowBlurBase = 36,
    this.glowBlurRange = 20,
    this.floatAmplitude = 0,
    this.floatPeriodMs = 4000,
    this.shimmerSpeed = 1.0,
    this.outerHaloAlpha = 0,
  });

  static _PresenceConfig lerp(_PresenceConfig a, _PresenceConfig b, double t) {
    return _PresenceConfig(
      breathPeriodMs: lerpDouble(a.breathPeriodMs, b.breathPeriodMs, t)!,
      scaleMin: lerpDouble(a.scaleMin, b.scaleMin, t)!,
      scaleRange: lerpDouble(a.scaleRange, b.scaleRange, t)!,
      glowAlphaBase: lerpDouble(a.glowAlphaBase, b.glowAlphaBase, t)!,
      glowAlphaRange: lerpDouble(a.glowAlphaRange, b.glowAlphaRange, t)!,
      glowBlurBase: lerpDouble(a.glowBlurBase, b.glowBlurBase, t)!,
      glowBlurRange: lerpDouble(a.glowBlurRange, b.glowBlurRange, t)!,
      floatAmplitude: lerpDouble(a.floatAmplitude, b.floatAmplitude, t)!,
      floatPeriodMs: lerpDouble(a.floatPeriodMs, b.floatPeriodMs, t)!,
      shimmerSpeed: lerpDouble(a.shimmerSpeed, b.shimmerSpeed, t)!,
      outerHaloAlpha: lerpDouble(a.outerHaloAlpha, b.outerHaloAlpha, t)!,
    );
  }

  static const configs = <PresenceState, _PresenceConfig>{
    PresenceState.observing: _PresenceConfig(
      breathPeriodMs: 3500,
      glowAlphaBase: 0.15,
      glowAlphaRange: 0.1,
      glowBlurBase: 30,
      glowBlurRange: 15,
      floatAmplitude: 2,
      floatPeriodMs: 5000,
      shimmerSpeed: 0.7,
    ),
    PresenceState.responding: _PresenceConfig(
      breathPeriodMs: 2000,
      scaleMin: 0.90,
      scaleRange: 0.12,
      glowAlphaBase: 0.35,
      glowAlphaRange: 0.2,
      glowBlurBase: 45,
      glowBlurRange: 25,
      floatAmplitude: 1,
      floatPeriodMs: 2000,
      shimmerSpeed: 2.0,
    ),
    PresenceState.supporting: _PresenceConfig(
      breathPeriodMs: 3000,
      glowAlphaBase: 0.28,
      glowAlphaRange: 0.12,
      glowBlurBase: 38,
      glowBlurRange: 18,
      floatAmplitude: 3,
      floatPeriodMs: 4000,
      shimmerSpeed: 1.0,
    ),
    PresenceState.guiding: _PresenceConfig(
      breathPeriodMs: 2500,
      scaleMin: 0.93,
      scaleRange: 0.09,
      glowAlphaBase: 0.35,
      glowAlphaRange: 0.18,
      glowBlurBase: 42,
      glowBlurRange: 22,
      floatAmplitude: 4,
      floatPeriodMs: 3500,
      shimmerSpeed: 1.4,
    ),
    PresenceState.calming: _PresenceConfig(
      breathPeriodMs: 5000,
      scaleMin: 0.94,
      scaleRange: 0.06,
      glowAlphaBase: 0.3,
      glowAlphaRange: 0.1,
      glowBlurBase: 50,
      glowBlurRange: 15,
      floatAmplitude: 1.5,
      floatPeriodMs: 6000,
      shimmerSpeed: 0.5,
      outerHaloAlpha: 0.08,
    ),
    PresenceState.silent: _PresenceConfig(
      breathPeriodMs: 6000,
      scaleMin: 0.95,
      scaleRange: 0.04,
      glowAlphaBase: 0.4,
      glowAlphaRange: 0.08,
      glowBlurBase: 55,
      glowBlurRange: 10,
      floatAmplitude: 0.5,
      floatPeriodMs: 8000,
      shimmerSpeed: 0.3,
      outerHaloAlpha: 0.12,
    ),
  };
}

// ─── AuraPresence Widget ─────────────────────────────────────────────────────

class AuraPresence extends StatefulWidget {
  final double size;
  final Color color;
  final Color glowColor;
  final PresenceState state;
  final VoidCallback? onTap;

  const AuraPresence({
    super.key,
    this.size = 160,
    this.color = Cosmic.primary,
    this.glowColor = Cosmic.glowPrimary,
    this.state = PresenceState.observing,
    this.onTap,
  });

  @override
  State<AuraPresence> createState() => _AuraPresenceState();
}

class _AuraPresenceState extends State<AuraPresence>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _colorCtrl;
  late final AnimationController _stateCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;

  Color _fromColor = Cosmic.primary;
  Color _toColor = Cosmic.primary;
  Color _fromGlow = Cosmic.glowPrimary;
  Color _toGlow = Cosmic.glowPrimary;

  _PresenceConfig _fromConfig = _PresenceConfig.configs[PresenceState.observing]!;
  _PresenceConfig _toConfig = _PresenceConfig.configs[PresenceState.observing]!;

  @override
  void initState() {
    super.initState();
    _fromColor = widget.color;
    _toColor = widget.color;
    _fromGlow = widget.glowColor;
    _toGlow = widget.glowColor;

    final cfg = _PresenceConfig.configs[widget.state]!;
    _fromConfig = cfg;
    _toConfig = cfg;

    _breathCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: cfg.breathPeriodMs.round()),
    )..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );

    _stateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: cfg.floatPeriodMs.round()),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(AuraPresence old) {
    super.didUpdateWidget(old);

    if (old.color != widget.color || old.glowColor != widget.glowColor) {
      _fromColor = Color.lerp(_fromColor, _toColor, _colorCtrl.value) ?? _toColor;
      _fromGlow = Color.lerp(_fromGlow, _toGlow, _colorCtrl.value) ?? _toGlow;
      _toColor = widget.color;
      _toGlow = widget.glowColor;
      _colorCtrl.forward(from: 0);
    }

    if (old.state != widget.state) {
      final currentConfig = _PresenceConfig.lerp(_fromConfig, _toConfig, _stateCtrl.value);
      _fromConfig = currentConfig;
      _toConfig = _PresenceConfig.configs[widget.state]!;
      _stateCtrl.forward(from: 0);

      // Update breath duration when state changes (not in build)
      _breathCtrl.duration = Duration(
        milliseconds: _toConfig.breathPeriodMs.round(),
      );

      if (widget.state == PresenceState.responding) {
        _pulseCtrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _shimmerCtrl.dispose();
    _colorCtrl.dispose();
    _stateCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void pulse() {
    _pulseCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathCtrl, _shimmerCtrl, _colorCtrl,
          _stateCtrl, _floatCtrl, _pulseCtrl,
        ]),
        builder: (_, __) {
          final stateT = Curves.easeOutCubic.transform(_stateCtrl.value);
          final cfg = _PresenceConfig.lerp(_fromConfig, _toConfig, stateT);

          final breathVal = Curves.easeInOut.transform(_breathCtrl.value);
          final floatPhase = _floatCtrl.value * 2 * pi;
          final shimmerAngle = _shimmerCtrl.value * 2 * pi * cfg.shimmerSpeed;

          final ct = Curves.easeOutCubic.transform(_colorCtrl.value);
          final color = Color.lerp(_fromColor, _toColor, ct)!;
          final glow = Color.lerp(_fromGlow, _toGlow, ct)!;

          // Pulse (responding state entry)
          final pulseT = _pulseCtrl.value;
          final pulseScale = pulseT > 0
              ? 1.0 + 0.2 * Curves.easeOutCubic.transform(
                  pulseT < 0.4 ? pulseT / 0.4 : 1.0 - (pulseT - 0.4) / 0.6)
              : 1.0;

          // State-driven parameters
          final scale = (cfg.scaleMin + cfg.scaleRange * breathVal) * pulseScale;
          final glowAlpha = cfg.glowAlphaBase + cfg.glowAlphaRange * breathVal;
          final glowBlur = cfg.glowBlurBase + cfg.glowBlurRange * breathVal;
          final floatY = sin(floatPhase) * cfg.floatAmplitude;
          final floatX = cos(floatPhase * 0.7) * cfg.floatAmplitude * 0.3;

          return GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: widget.size * 1.5,
              height: widget.size * 1.5,
              child: Center(
                child: Transform.translate(
                  offset: Offset(floatX, floatY),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer halo (calming/silent states)
                          if (cfg.outerHaloAlpha > 0.01)
                            Container(
                              width: widget.size * 1.3,
                              height: widget.size * 1.3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: glow.withValues(
                                      alpha: cfg.outerHaloAlpha * breathVal,
                                    ),
                                    blurRadius: 80,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),

                          // Main orb
                          Container(
                            width: widget.size,
                            height: widget.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: glow.withValues(alpha: glowAlpha),
                                  blurRadius: glowBlur,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: color.withValues(alpha: glowAlpha * 0.25),
                                  blurRadius: glowBlur * 1.6,
                                ),
                              ],
                              gradient: SweepGradient(
                                startAngle: shimmerAngle,
                                endAngle: shimmerAngle + 2 * pi,
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.7),
                                  color.withValues(alpha: 0.4),
                                  color.withValues(alpha: 0.7),
                                  color,
                                ],
                                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    color.withValues(alpha: 0.55),
                                    color.withValues(alpha: 0.25),
                                    color.withValues(alpha: 0.08),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Pulse flash overlay
                          if (pulseT > 0 && pulseT < 1)
                            Container(
                              width: widget.size * (1.0 + 0.4 * pulseT),
                              height: widget.size * (1.0 + 0.4 * pulseT),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: 0.4 * (1 - pulseT),
                                    ),
                                    color.withValues(
                                      alpha: 0.15 * (1 - pulseT),
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Helper: map response_mode to PresenceState ──────────────────────────────

PresenceState presenceStateFromResponse({
  required String responseMode,
  required bool hasCheckedIn,
  double urgency = 0,
}) {
  if (!hasCheckedIn) return PresenceState.observing;

  if (urgency > 0.8) return PresenceState.responding;

  return switch (responseMode) {
    'silent' => PresenceState.silent,
    'minimal' => PresenceState.supporting,
    'suggestion' => PresenceState.guiding,
    'reflective' => PresenceState.calming,
    _ => PresenceState.supporting,
  };
}
