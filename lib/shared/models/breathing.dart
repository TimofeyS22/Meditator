import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

class BreathPhase extends Equatable {
  const BreathPhase({
    required this.label,
    required this.seconds,
    required this.targetScale,
  });

  final String label;
  final int seconds;
  final double targetScale;

  Map<String, dynamic> toJson() => {
        'label': label,
        'seconds': seconds,
        'targetScale': targetScale,
      };

  factory BreathPhase.fromJson(Map<String, dynamic> json) {
    final secRaw = json['seconds'];
    final scaleRaw = json['targetScale'] ?? json['target_scale'];
    return BreathPhase(
      label: json['label'] as String? ?? '',
      seconds: secRaw is int ? secRaw : (secRaw is num ? secRaw.toInt() : 0),
      targetScale: scaleRaw is num ? scaleRaw.toDouble() : 1.0,
    );
  }

  @override
  List<Object?> get props => [label, seconds, targetScale];
}

class BreathingExercise extends Equatable {
  const BreathingExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.benefit,
    required this.phases,
    this.cycles = 4,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final String benefit;
  final List<BreathPhase> phases;
  final int cycles;
  final Color color;

  static List<BreathingExercise> get presets => [
        BreathingExercise(
          id: 'box',
          name: 'Квадратное дыхание',
          description:
              'Четыре равные фазы: вдох, задержка, выдох, задержка. Быстро возвращает ясность и контроль.',
          benefit: 'Снижает панику, стабилизирует нервную систему и помогает «собраться» перед важным моментом.',
          phases: const [
            BreathPhase(label: 'Вдох', seconds: 4, targetScale: 1.15),
            BreathPhase(label: 'Задержка', seconds: 4, targetScale: 1.15),
            BreathPhase(label: 'Выдох', seconds: 4, targetScale: 0.85),
            BreathPhase(label: 'Задержка', seconds: 4, targetScale: 0.85),
          ],
          cycles: 6,
          color: C.calm,
        ),
        BreathingExercise(
          id: 'relax478',
          name: '4-7-8 для расслабления',
          description:
              'Удлинённый выдох успокаивает тело. Идеально перед сном или после стресса.',
          benefit: 'Помогает быстрее заснуть, смягчает тревогу и отпускает зажимы.',
          phases: const [
            BreathPhase(label: 'Вдох', seconds: 4, targetScale: 1.1),
            BreathPhase(label: 'Задержка', seconds: 7, targetScale: 1.1),
            BreathPhase(label: 'Выдох', seconds: 8, targetScale: 0.8),
          ],
          cycles: 4,
          color: C.accent,
        ),
        BreathingExercise(
          id: 'energizing',
          name: 'Бодрящее 2-2',
          description: 'Короткие вдохи и выдохи — как встроенный эспрессо без кофеина.',
          benefit: 'Добавляет бодрости, прогоняет сонливость и заряжает на движение.',
          phases: const [
            BreathPhase(label: 'Вдох', seconds: 2, targetScale: 1.12),
            BreathPhase(label: 'Выдох', seconds: 2, targetScale: 0.88),
          ],
          cycles: 10,
          color: C.energy,
        ),
        BreathingExercise(
          id: 'deepCalm',
          name: 'Глубокое спокойствие 5-2-8',
          description: 'Медленный вдох, короткая пауза и длинный выдох — мягкий якорь в шумный день.',
          benefit: 'Углубляет дыхание, снижает фоновую тревогу и возвращает ощущение опоры.',
          phases: const [
            BreathPhase(label: 'Вдох', seconds: 5, targetScale: 1.18),
            BreathPhase(label: 'Пауза', seconds: 2, targetScale: 1.18),
            BreathPhase(label: 'Выдох', seconds: 8, targetScale: 0.78),
          ],
          cycles: 5,
          color: C.primary,
        ),
        BreathingExercise(
          id: 'sos',
          name: 'SOS 3-6',
          description: 'Короткий вдох и длинный выдох — когда всё «зашкаливает» и нужна передышка.',
          benefit: 'Быстро снижает остроту переживаний; можно сделать прямо сейчас, где бы ты ни был.',
          phases: const [
            BreathPhase(label: 'Вдох', seconds: 3, targetScale: 1.08),
            BreathPhase(label: 'Выдох', seconds: 6, targetScale: 0.75),
          ],
          cycles: 8,
          color: C.rose,
        ),
      ];

  factory BreathingExercise.fromJson(Map<String, dynamic> json) {
    final phasesRaw = json['phases'];
    final phases = <BreathPhase>[];
    if (phasesRaw is List) {
      for (final e in phasesRaw) {
        if (e is Map) {
          phases.add(BreathPhase.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    final cyclesRaw = json['cycles'];
    final cycles = cyclesRaw is int ? cyclesRaw : (cyclesRaw is num ? cyclesRaw.toInt() : 4);

    return BreathingExercise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      benefit: json['benefit'] as String? ?? '',
      phases: phases,
      cycles: cycles,
      color: _colorFromJson(json['color']) ?? C.calm,
    );
  }

  static Color? _colorFromJson(dynamic v) {
    if (v is int) return Color(v);
    if (v is String) {
      final hex = v.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return null;
  }

  static int _colorToArgb32(Color c) {
    int ch(double x) => (x * 255.0).round() & 0xff;
    return (ch(c.a) << 24) | (ch(c.r) << 16) | (ch(c.g) << 8) | ch(c.b);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'benefit': benefit,
        'phases': phases.map((p) => p.toJson()).toList(),
        'cycles': cycles,
        'color': _colorToArgb32(color),
      };

  @override
  List<Object?> get props => [id, name, description, benefit, phases, cycles, color];
}
