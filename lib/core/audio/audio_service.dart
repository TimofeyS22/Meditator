import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentTrack;

  static const _sessionAudio = <String, List<String>>{
    'anxiety_relief': [
      'assets/audio/anxiety-01-med.mp3',
      'assets/audio/anxiety-02-med.mp3',
      'assets/audio/anxiety-03-med.mp3',
    ],
    'energy_reset': [
      'assets/audio/focus-01-med.mp3',
      'assets/audio/focus-02-med.mp3',
      'assets/audio/focus-03-med.mp3',
    ],
    'overload_relief': [
      'assets/audio/breathing-01-med.mp3',
      'assets/audio/breathing-02-med.mp3',
      'assets/audio/breathing-04-med.mp3',
    ],
    'grounding': [
      'assets/audio/visualization-01-med.mp3',
      'assets/audio/visualization-02-med.mp3',
      'assets/audio/visualization-03-med.mp3',
    ],
    'sleep_reset': [
      'assets/audio/sleep-01-med.mp3',
      'assets/audio/sleep-02-med.mp3',
      'assets/audio/sleep-03-med.mp3',
    ],
    'deepen': [
      'assets/audio/bodyScan-01-med.mp3',
      'assets/audio/bodyScan-02-med.mp3',
      'assets/audio/bodyScan-03-med.mp3',
    ],
    'emergency': [
      'assets/audio/emergency-01-med.mp3',
      'assets/audio/emergency-02-med.mp3',
      'assets/audio/emergency-03-med.mp3',
    ],
  };

  static final _rng = Random();

  Future<void> playSession(String sessionType) async {
    final tracks = _sessionAudio[sessionType] ?? _sessionAudio['deepen']!;
    final track = tracks[_rng.nextInt(tracks.length)];
    _currentTrack = track;
    await _player.setAsset(track);
    await _player.setVolume(1.0);
    await _player.play();
  }

  Future<void> playEmergency() async => playSession('emergency');

  String? get currentTrack => _currentTrack;
  bool get isPlaying => _player.playing;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();

  Future<void> setVolume(double v) async => _player.setVolume(v);

  Future<void> fadeOut({
    Duration duration = const Duration(milliseconds: 2000),
  }) async {
    const steps = 20;
    final step = Duration(milliseconds: duration.inMilliseconds ~/ steps);

    for (var i = steps; i > 0; i--) {
      if (!_player.playing) break;
      await _player.setVolume(i / steps);
      await Future.delayed(step);
    }
    await _player.stop();
    await _player.setVolume(1.0);
    _currentTrack = null;
  }

  void dispose() => _player.dispose();
}

final audioServiceProvider = Provider<AudioService>((_) => AudioService());
