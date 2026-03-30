import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class BinauralPreset {
  const BinauralPreset({
    required this.name,
    required this.description,
    required this.baseFrequency,
    required this.beatFrequency,
    required this.category,
  });

  final String name;
  final String description;
  final double baseFrequency;
  final double beatFrequency;
  final String category;
}

const binauralPresets = [
  BinauralPreset(
    name: 'Глубокий сон',
    description: 'Delta 2 Hz — глубокая фаза сна',
    baseFrequency: 200,
    beatFrequency: 2,
    category: 'sleep',
  ),
  BinauralPreset(
    name: 'Засыпание',
    description: 'Delta 3.5 Hz — переход ко сну',
    baseFrequency: 180,
    beatFrequency: 3.5,
    category: 'sleep',
  ),
  BinauralPreset(
    name: 'Глубокая медитация',
    description: 'Theta 5 Hz — медитативный транс',
    baseFrequency: 200,
    beatFrequency: 5,
    category: 'meditation',
  ),
  BinauralPreset(
    name: 'Осознанность',
    description: 'Theta 7 Hz — повышенная осознанность',
    baseFrequency: 220,
    beatFrequency: 7,
    category: 'meditation',
  ),
  BinauralPreset(
    name: 'Расслабление',
    description: 'Alpha 10 Hz — лёгкое расслабление',
    baseFrequency: 200,
    beatFrequency: 10,
    category: 'focus',
  ),
  BinauralPreset(
    name: 'Фокус',
    description: 'Alpha 12 Hz — концентрация и ясность',
    baseFrequency: 220,
    beatFrequency: 12,
    category: 'focus',
  ),
  BinauralPreset(
    name: 'Поток',
    description: 'Beta 15 Hz — состояние потока',
    baseFrequency: 200,
    beatFrequency: 15,
    category: 'focus',
  ),
];

class BinauralEngine {
  static const _sampleRate = 44100;
  static const _durationSec = 30;

  static Uint8List generateWav({
    required double baseFrequency,
    required double beatFrequency,
    double volume = 0.3,
  }) {
    final leftFreq = baseFrequency;
    final rightFreq = baseFrequency + beatFrequency;
    final numSamples = _sampleRate * _durationSec;

    final samples = Int16List(numSamples * 2);
    final amplitude = (32767 * volume).toInt();

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final leftSample = (amplitude * math.sin(2 * math.pi * leftFreq * t)).toInt();
      final rightSample = (amplitude * math.sin(2 * math.pi * rightFreq * t)).toInt();
      samples[i * 2] = leftSample.clamp(-32768, 32767);
      samples[i * 2 + 1] = rightSample.clamp(-32768, 32767);
    }

    return _encodeWav(samples, 2, _sampleRate);
  }

  static Uint8List _encodeWav(Int16List samples, int channels, int sampleRate) {
    final dataSize = samples.length * 2;
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);
    int offset = 0;

    void writeString(String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    void writeUint32(int v) {
      buffer.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeUint16(int v) {
      buffer.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    writeString('RIFF');
    writeUint32(fileSize - 8);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(sampleRate * channels * 2);
    writeUint16(channels * 2);
    writeUint16(16);
    writeString('data');
    writeUint32(dataSize);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(offset, samples[i], Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}

class BinauralAudioSource extends StreamAudioSource {
  BinauralAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
