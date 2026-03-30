import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Dark-themed voice recorder: round start control, mm:ss timer, pulsing red dot, stop.
class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  final void Function(String filePath) onRecordingComplete;
  final VoidCallback? onCancel;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _tick;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulseController.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Нужен доступ к микрофону')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(
      dir.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
    );

    await _recorder.start(config, path: filePath);
    if (!mounted) return;
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _pulseController.repeat(reverse: true);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stop() async {
    _tick?.cancel();
    _tick = null;
    _pulseController
      ..stop()
      ..reset();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path != null && path.isNotEmpty) {
      widget.onRecordingComplete(path);
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить запись')),
      );
    }
  }

  Future<void> _onCancelPressed() async {
    _tick?.cancel();
    _tick = null;
    _pulseController
      ..stop()
      ..reset();
    if (_recording) {
      await _recorder.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _elapsed = Duration.zero;
      });
    }
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _onCancelPressed,
                child: Text(
                  'Отмена',
                  style: TextStyle(color: C.accent),
                ),
              ),
            ),
          if (!_recording) ...[
            Text(
              'Нажми, чтобы записать',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: S.l),
            Semantics(
              button: true,
              label: 'Начать запись голоса',
              child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _start,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.cSurface,
                    border: Border.all(
                      color: C.accent.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: C.accent.withValues(alpha: 0.22),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded, size: 40, color: C.accent),
                ),
              ),
            ),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              label: 'Запись: ${_formatDuration(_elapsed)}',
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.35 + 0.65 * _pulseController.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: C.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: S.m),
                Text(
                  _formatDuration(_elapsed),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
            ),
            const SizedBox(height: S.l),
            FilledButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Стоп'),
              style: FilledButton.styleFrom(
                foregroundColor: context.cText,
                backgroundColor: context.cSurfaceLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: S.l,
                  vertical: S.m,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
