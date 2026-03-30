import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final AudioPlayer _main = AudioPlayer();
  final AudioPlayer _ambient = AudioPlayer();
  File? _tempAudioFile;

  Stream<PlayerState> get playerStateStream => _main.playerStateStream;

  Stream<Duration> get positionStream => _main.positionStream;

  Stream<Duration> get bufferedPositionStream => _main.bufferedPositionStream;

  Stream<Duration?> get durationStream => _main.durationStream;

  Duration? get totalDuration => _main.duration;
  Duration get position => _main.position;

  double get speed => _main.speed;

  Future<void> playUrl(String url) async {
    await _main.setUrl(url);
    await _main.play();
  }

  Future<void> playFile(String path) async {
    await _main.setFilePath(path);
    await _main.play();
  }

  Future<void> playBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/meditator_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await file.writeAsBytes(bytes, flush: true);
    _tempAudioFile?.delete().catchError((_) {});
    _tempAudioFile = file;
    await _main.setFilePath(file.path);
    await _main.play();
  }

  Future<void> pause() => _main.pause();

  Future<void> resume() => _main.play();

  Future<void> stop() => _main.stop();

  Future<void> seek(Duration position) => _main.seek(position);

  Future<void> setVolume(double volume) => _main.setVolume(volume.clamp(0, 1));

  Future<void> setSpeed(double speed) => _main.setSpeed(speed.clamp(0.5, 2.0));

  Future<void> playAmbient(String url) async {
    await _ambient.setUrl(url);
    await _ambient.setLoopMode(LoopMode.one);
    await _ambient.play();
  }

  Future<void> stopAmbient() => _ambient.stop();

  Future<void> setAmbientVolume(double volume) =>
      _ambient.setVolume(volume.clamp(0, 1));

  Future<void> dispose() async {
    await _main.dispose();
    await _ambient.dispose();
    _tempAudioFile?.delete().catchError((_) {});
  }
}
