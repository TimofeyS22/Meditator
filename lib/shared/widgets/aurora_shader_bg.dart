import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

class AuroraShaderBg extends StatefulWidget {
  const AuroraShaderBg({
    super.key,
    this.progress = 0.0,
    this.color1 = C.primary,
    this.color2 = C.accent,
  });

  final double progress;
  final Color color1;
  final Color color2;

  @override
  State<AuroraShaderBg> createState() => _AuroraShaderBgState();
}

class _AuroraShaderBgState extends State<AuroraShaderBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  ui.FragmentProgram? _program;
  bool _shaderFailed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset('shaders/aurora_flow.frag');
      if (mounted) setState(() => _program = prog);
    } catch (_) {
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shaderFailed || _program == null) {
      return const _FallbackBg();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _AuroraShaderPainter(
            program: _program!,
            time: _ctrl.value * 20.0,
            progress: widget.progress,
            color1: widget.color1,
            color2: widget.color2,
          ),
        ),
      ),
    );
  }
}

class _AuroraShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double time;
  final double progress;
  final Color color1;
  final Color color2;

  _AuroraShaderPainter({
    required this.program,
    required this.time,
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, progress)
      ..setFloat(4, color1.red / 255.0)
      ..setFloat(5, color1.green / 255.0)
      ..setFloat(6, color1.blue / 255.0)
      ..setFloat(7, color1.opacity)
      ..setFloat(8, color2.red / 255.0)
      ..setFloat(9, color2.green / 255.0)
      ..setFloat(10, color2.blue / 255.0)
      ..setFloat(11, color2.opacity);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_AuroraShaderPainter old) =>
      old.time != time || old.progress != progress;
}

class _FallbackBg extends StatelessWidget {
  const _FallbackBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.2,
          colors: [
            Color(0x30636CF1),
            Color(0x102DD4BF),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
