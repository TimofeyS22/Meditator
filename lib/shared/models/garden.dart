import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

enum PlantType {
  calmTree,
  focusFlower,
  gratitudeBush,
  sleepLotus,
  energyBamboo,
  lovingRose,
}

extension PlantTypeX on PlantType {
  String get nameRu => switch (this) {
        PlantType.calmTree => 'Дерево спокойствия',
        PlantType.focusFlower => 'Цветок фокуса',
        PlantType.gratitudeBush => 'Куст благодарности',
        PlantType.sleepLotus => 'Лотус сна',
        PlantType.energyBamboo => 'Бамбук энергии',
        PlantType.lovingRose => 'Роза любви',
      };

  String get description => switch (this) {
        PlantType.calmTree => 'Растёт, когда ты отпускаешь тревогу и дышишь глубже.',
        PlantType.focusFlower => 'Распускается за честные минуты концентрации и ясности.',
        PlantType.gratitudeBush => 'Каждый полив — маленькое «спасибо» себе и миру.',
        PlantType.sleepLotus => 'Цветёт из мягких ритуалов перед сном и тишины.',
        PlantType.energyBamboo => 'Тянется вверх вместе с твоим настроем и движением.',
        PlantType.lovingRose => 'Напоминает беречь себя: нежность — не слабость.',
      };

  Color get color => switch (this) {
        PlantType.calmTree => C.calm,
        PlantType.focusFlower => C.primary,
        PlantType.gratitudeBush => C.grateful,
        PlantType.sleepLotus => C.accent,
        PlantType.energyBamboo => C.energy,
        PlantType.lovingRose => C.rose,
      };

  bool get isPremium => switch (this) {
        PlantType.calmTree => false,
        PlantType.focusFlower => false,
        PlantType.gratitudeBush => false,
        PlantType.sleepLotus => true,
        PlantType.energyBamboo => false,
        PlantType.lovingRose => true,
      };
}

enum GrowthStage { seed, sprout, young, mature, blooming }

extension GrowthStageX on GrowthStage {
  String get label => switch (this) {
        GrowthStage.seed => 'Семечко',
        GrowthStage.sprout => 'Росток',
        GrowthStage.young => 'Подросток',
        GrowthStage.mature => 'Взрослое',
        GrowthStage.blooming => 'Цветение',
      };

  double get scale => switch (this) {
        GrowthStage.seed => 0.2,
        GrowthStage.sprout => 0.4,
        GrowthStage.young => 0.6,
        GrowthStage.mature => 0.8,
        GrowthStage.blooming => 1.0,
      };

  int get requiredWaterings => switch (this) {
        GrowthStage.seed => 0,
        GrowthStage.sprout => 2,
        GrowthStage.young => 5,
        GrowthStage.mature => 9,
        GrowthStage.blooming => 15,
      };
}

PlantType? _plantTypeFromJson(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  for (final p in PlantType.values) {
    if (p.name == v) return p;
  }
  return null;
}

GrowthStage? _growthStageFromJson(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  for (final s in GrowthStage.values) {
    if (s.name == v) return s;
  }
  return null;
}

class GardenPlant extends Equatable {
  const GardenPlant({
    required this.id,
    required this.userId,
    required this.type,
    this.stage = GrowthStage.seed,
    this.waterCount = 0,
    this.healthLevel = 1.0,
    this.posX = 0.0,
    this.posY = 0.0,
    required this.plantedAt,
    this.lastWateredAt,
  });

  final String id;
  final String userId;
  final PlantType type;
  final GrowthStage stage;
  final int waterCount;
  final double healthLevel;
  final double posX;
  final double posY;
  final DateTime plantedAt;
  final DateTime? lastWateredAt;

  GrowthStage get calculatedStage {
    final stages = GrowthStage.values;
    GrowthStage result = GrowthStage.seed;
    for (final s in stages) {
      if (waterCount >= s.requiredWaterings) {
        result = s;
      }
    }
    return result;
  }

  bool get isWilting {
    final ref = lastWateredAt ?? plantedAt;
    final diff = DateTime.now().difference(ref);
    return diff.inDays > 2;
  }

  factory GardenPlant.fromJson(Map<String, dynamic> json) {
    final hlRaw = json['healthLevel'] ?? json['health_level'];
    var health = hlRaw is num ? hlRaw.toDouble() : 1.0;
    if (health < 0) health = 0;
    if (health > 1) health = 1;

    final pxRaw = json['posX'] ?? json['pos_x'];
    final pyRaw = json['posY'] ?? json['pos_y'];

    return GardenPlant(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      type: _plantTypeFromJson(json['type']) ?? PlantType.calmTree,
      stage: _growthStageFromJson(json['stage']) ?? GrowthStage.seed,
      waterCount: (json['waterCount'] ?? json['water_count']) as int? ?? 0,
      healthLevel: health,
      posX: pxRaw is num ? pxRaw.toDouble() : 0,
      posY: pyRaw is num ? pyRaw.toDouble() : 0,
      plantedAt: _parseDate(json['plantedAt'] ?? json['planted_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastWateredAt: _parseDate(json['lastWateredAt'] ?? json['last_watered_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'stage': stage.name,
        'waterCount': waterCount,
        'healthLevel': healthLevel,
        'posX': posX,
        'posY': posY,
        'plantedAt': plantedAt.toIso8601String(),
        'lastWateredAt': lastWateredAt?.toIso8601String(),
      };

  GardenPlant copyWith({
    String? id,
    String? userId,
    PlantType? type,
    GrowthStage? stage,
    int? waterCount,
    double? healthLevel,
    double? posX,
    double? posY,
    DateTime? plantedAt,
    DateTime? lastWateredAt,
  }) {
    return GardenPlant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      stage: stage ?? this.stage,
      waterCount: waterCount ?? this.waterCount,
      healthLevel: healthLevel ?? this.healthLevel,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      plantedAt: plantedAt ?? this.plantedAt,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, type, stage, waterCount, healthLevel, posX, posY, plantedAt, lastWateredAt];
}
