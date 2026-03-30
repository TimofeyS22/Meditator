import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/core/subscription/subscription_service.dart';
import 'package:meditator/shared/models/garden.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/celebration_overlay.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/skeleton_placeholders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kLocalGardenKey = 'meditator_local_garden';

enum _GardenWeather {
  sunny(label: 'Солнечно', icon: Icons.wb_sunny_outlined),
  clear(label: 'Ясно', icon: Icons.nights_stay_outlined),
  cloudy(label: 'Облачно', icon: Icons.cloud_outlined),
  rain(label: 'Дождь', icon: Icons.grain),
  storm(label: 'Шторм', icon: Icons.thunderstorm_outlined);

  const _GardenWeather({required this.label, required this.icon});
  final String label;
  final IconData icon;

  Color get tintColor => switch (this) {
    _GardenWeather.sunny => const Color(0xFFFFD54F),
    _GardenWeather.clear => C.accent,
    _GardenWeather.cloudy => const Color(0xFF90A4AE),
    _GardenWeather.rain => const Color(0xFF64B5F6),
    _GardenWeather.storm => const Color(0xFFEF5350),
  };
}

GardenPlant _plantFromRow(Map<String, dynamic> row) {
  return GardenPlant.fromJson({
    'id': row['id'],
    'userId': row['user_id'] ?? row['userId'],
    'type': row['type'],
    'stage': row['stage'],
    'waterCount': row['water_count'] ?? row['waterCount'],
    'healthLevel': row['health_level'] ?? row['healthLevel'],
    'posX': row['pos_x'] ?? row['posX'],
    'posY': row['pos_y'] ?? row['posY'],
    'plantedAt': row['planted_at'] ?? row['plantedAt'],
    'lastWateredAt': row['last_watered_at'] ?? row['lastWateredAt'],
  });
}

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen>
    with TickerProviderStateMixin {
  List<GardenPlant> _plants = [];
  bool _loading = true;
  bool _showPlantConfetti = false;
  late final AnimationController _starCtrl;
  late final AnimationController _weatherCtrl;
  _GardenWeather _weather = _GardenWeather.clear;
  String _moodLabel = '';

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _weatherCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _load();
    _loadMoodWeather();
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    _weatherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMoodWeather() async {
    final uid = AuthService.instance.userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final entries = await Db.instance.getMoodEntries(uid, limit: 5);
      if (entries.isEmpty || !mounted) return;
      final latest = entries.first;
      final emotion = (latest['primary_emotion'] ?? latest['primaryEmotion'] ?? '') as String;
      final intensity = ((latest['intensity'] ?? 3) as num).toInt();
      final w = _weatherFromMood(emotion.toLowerCase(), intensity);
      if (mounted) {
        setState(() {
          _weather = w;
          _moodLabel = emotion;
        });
      }
    } catch (_) {}
  }

  static _GardenWeather _weatherFromMood(String emotion, int intensity) {
    const stormEmotions = ['тревога', 'злость', 'гнев', 'страх', 'паника'];
    const rainEmotions = ['грусть', 'печаль', 'усталость', 'разочарование'];
    const cloudyEmotions = ['скука', 'безразличие', 'напряжение', 'сомнение'];
    const sunnyEmotions = ['радость', 'счастье', 'восторг', 'благодарность', 'вдохновение', 'любовь'];

    if (stormEmotions.any(emotion.contains) && intensity >= 4) return _GardenWeather.storm;
    if (stormEmotions.any(emotion.contains)) return _GardenWeather.rain;
    if (rainEmotions.any(emotion.contains)) return _GardenWeather.rain;
    if (cloudyEmotions.any(emotion.contains)) return _GardenWeather.cloudy;
    if (sunnyEmotions.any(emotion.contains)) return _GardenWeather.sunny;
    if (intensity <= 2) return _GardenWeather.cloudy;
    return _GardenWeather.clear;
  }

  // ---------------------------------------------------------------------------
  // Business logic (unchanged)
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = AuthService.instance.userId;

    if (uid != null && uid.isNotEmpty) {
      try {
        final rows = await Db.instance.getGarden(uid);
        if (!mounted) return;
        setState(() {
          _plants = rows.map(_plantFromRow).toList();
          _loading = false;
        });
        return;
      } catch (_) {}
    }

    // Fallback: local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalGardenKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          _plants = list
              .map((e) => GardenPlant.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() { _plants = []; _loading = false; });
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _plants.map((p) => p.toJson()).toList();
    await prefs.setString(_kLocalGardenKey, jsonEncode(json));
  }

  int get _blooming =>
      _plants.where((p) => p.calculatedStage == GrowthStage.blooming).length;

  double get _avgHealth {
    if (_plants.isEmpty) return 0;
    return _plants.map((p) => p.healthLevel).reduce((a, b) => a + b) /
        _plants.length;
  }

  Future<void> _plant(PlantType type) async {
    final uid = AuthService.instance.userId;
    final rnd = math.Random();
    final plantData = {
      'id': const Uuid().v4(),
      'user_id': uid ?? 'local',
      'type': type.name,
      'stage': GrowthStage.seed.name,
      'water_count': 0,
      'health_level': 1.0,
      'pos_x': 0.15 + rnd.nextDouble() * 0.65,
      'pos_y': 0.2 + rnd.nextDouble() * 0.55,
      'planted_at': DateTime.now().toIso8601String(),
    };

    try {
      if (uid != null && uid.isNotEmpty) {
        await Db.instance.insertPlant(plantData);
      } else {
        final plant = GardenPlant.fromJson({
          ...plantData,
          'userId': plantData['user_id'],
          'waterCount': plantData['water_count'],
          'healthLevel': plantData['health_level'],
          'posX': plantData['pos_x'],
          'posY': plantData['pos_y'],
          'plantedAt': plantData['planted_at'],
        });
        _plants.add(plant);
        await _saveLocal();
      }

      if (mounted) {
        setState(() => _showPlantConfetti = true);
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) setState(() => _showPlantConfetti = false);
        });
      }
      if (mounted) Navigator.of(context).pop();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось посадить растение')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Plant info bottom sheet
  // ---------------------------------------------------------------------------

  void _openPlantSheet(GardenPlant p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: GlassCard(
            showBorder: true,
            padding: const EdgeInsets.all(S.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            p.type.color,
                            p.type.color.withValues(alpha: 0.3),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: p.type.color.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: S.m),
                    Expanded(
                      child: Text(
                        p.type.nameRu,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: S.m),
                _DetailRow(label: 'Стадия', value: p.calculatedStage.label),
                const SizedBox(height: S.xs),
                _DetailRow(label: 'Поливов', value: '${p.waterCount}'),
                const SizedBox(height: S.xs),
                _DetailRow(
                  label: 'Здоровье',
                  value: '${(p.healthLevel * 100).round()}%',
                ),
                const SizedBox(height: S.m),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.s),
                  child: LinearProgressIndicator(
                    value: p.healthLevel,
                    backgroundColor: ctx.cSurfaceLight,
                    valueColor: AlwaysStoppedAnimation(
                      Color.lerp(C.rose, C.accent, p.healthLevel)!,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: S.m),
                Text(
                  'Полей через медитацию',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: C.accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Plant picker bottom sheet
  // ---------------------------------------------------------------------------

  void _openPlantPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          builder: (_, scroll) {
            return Container(
              decoration: BoxDecoration(
                color: ctx.cSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
                border: Border.all(color: ctx.cSurfaceBorder),
              ),
              padding: const EdgeInsets.only(top: S.m),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.l),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: S.m),
                      decoration: BoxDecoration(
                        color: ctx.cTextDim,
                        borderRadius: BorderRadius.circular(R.full),
                      ),
                    ),
                  ),
                  Text(
                    'Выбери растение',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: S.m),
                  for (var i = 0; i < PlantType.values.length; i++)
                    _buildPickerItem(ctx, PlantType.values[i], i),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPickerItem(BuildContext ctx, PlantType type, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.s),
      child: GlassCard(
        onTap: () {
          if (type.isPremium && !SubscriptionService.instance.isPremium.value) {
            Navigator.pop(ctx);
            context.push('/paywall');
            return;
          }
          _plant(type);
        },
        showBorder: true,
        showAnimatedBorder: type.isPremium,
        borderGradientColors: type.isPremium
            ? const [C.gold, C.warm, C.gold, C.warm]
            : null,
        showLightSweep: true,
        padding: const EdgeInsets.all(S.m),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: type.color.withValues(alpha: 0.15),
                border: Border.all(
                  color: type.color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: type.color,
                    boxShadow: [
                      BoxShadow(
                        color: type.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: S.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          type.nameRu,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleSmall,
                        ),
                      ),
                      if (type.isPremium) ...[
                        const SizedBox(width: S.s),
                        const _PremiumBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (60 * index).ms)
        .fadeIn(duration: Anim.normal)
        .slideX(begin: 0.05, end: 0, curve: Anim.curve);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        child: Stack(
          children: [
            if (_loading)
              const GardenSkeleton()
            else
              RefreshIndicator(
                color: C.accent,
                onRefresh: _load,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(S.m, S.l, S.m, S.s),
                    child: Text(
                      'Твой сад',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium,
                    ).animate().fadeIn(duration: Anim.normal),
                  ),
                  _buildStats(),
                  const SizedBox(height: S.m),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: S.m),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(R.l),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            return Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                RepaintBoundary(
                                  child: ListenableBuilder(
                                    listenable: _starCtrl,
                                    builder: (_, _) => CustomPaint(
                                      painter: _StarryPainter(
                                        seed: 42,
                                        animValue: _starCtrl.value,
                                      ),
                                    ),
                                  ),
                                ),
                                _WeatherOverlay(
                                  weather: _weather,
                                  animation: _weatherCtrl,
                                ),
                                if (_plants.isEmpty)
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              C.gradientPrimary
                                                  .createShader(b),
                                          child: const MIcon(
                                            MIconType.eco,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: S.m),
                                        Text(
                                          'Посади первое растение',
                                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: context.cTextSec),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(duration: Anim.slow)
                                else
                                  for (var i = 0; i < _plants.length; i++)
                                    _PlantDot(
                                      key: ValueKey(_plants[i].id),
                                      plant: _plants[i],
                                      width: box.maxWidth,
                                      height: box.maxHeight,
                                      onTap: () =>
                                          _openPlantSheet(_plants[i]),
                                    )
                                        .animate(delay: (50 * i).ms)
                                        .fadeIn()
                                        .scale(
                                          begin: const Offset(0.85, 0.85),
                                          end: const Offset(1, 1),
                                          curve: Anim.curveGentle,
                                        ),
                              ],
                            );
                          },
                        ),
                      ),
                    ).animate(delay: 250.ms).fadeIn(duration: Anim.normal),
                  ),
                const SizedBox(height: 120),
              ],
              ),
              ),
            if (_showPlantConfetti)
              const Positioned.fill(
                child: CelebrationOverlay(particleCount: 40),
              ),
            Positioned(
              right: S.m,
              bottom: 100,
              child: GlowButton(
                onPressed: _openPlantPicker,
                showGlow: _plants.isEmpty && !_loading,
                width: 170,
                semanticLabel: 'Посадить новое растение',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    MIcon(MIconType.eco, size: 20, color: Colors.white),
                    SizedBox(width: S.s),
                    Text('Посадить'),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.3, end: 0, curve: Anim.curveGentle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: S.m),
      child: Column(
        children: [
          if (_moodLabel.isNotEmpty)
            GlassCard(
              showBorder: true,
              padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
              child: Row(
                children: [
                  Icon(_weather.icon, color: _weather.tintColor, size: 22),
                  const SizedBox(width: S.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Погода в мире: ${_weather.label}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.cText),
                        ),
                        Text(
                          'На основе твоего настроения: $_moodLabel',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.08, curve: Anim.curve),
          if (_moodLabel.isNotEmpty) const SizedBox(height: S.s),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: MIcon(MIconType.park, size: 20, color: Colors.white),
                  label: 'Всего',
                  numValue: _plants.length,
                ).animate(delay: 100.ms).fadeIn().slideY(
                      begin: 0.15,
                      end: 0,
                      curve: Anim.curve,
                    ),
              ),
              const SizedBox(width: S.s),
              Expanded(
                child: _StatChip(
                  icon: MIcon(MIconType.florist, size: 20, color: Colors.white),
                  label: 'Цветут',
                  numValue: _blooming,
                ).animate(delay: 150.ms).fadeIn().slideY(
                      begin: 0.15,
                      end: 0,
                      curve: Anim.curve,
                    ),
              ),
              const SizedBox(width: S.s),
              Expanded(
                child: _StatChip(
                  icon: MIcon(MIconType.heart, size: 20, color: Colors.white),
                  label: 'Здоровье',
                  numValue:
                      _plants.isEmpty ? null : (_avgHealth * 100).round(),
                  suffix: '%',
                ).animate(delay: 200.ms).fadeIn().slideY(
                      begin: 0.15,
                      end: 0,
                      curve: Anim.curve,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Detail row for plant info sheet
// ==========================================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium,
        ),
        Text(
          value,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.cText),
        ),
      ],
    );
  }
}

// ==========================================================================
// Stat chip — gradient icon + AnimatedNumber
// ==========================================================================

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.numValue,
    this.suffix,
  });

  final Widget icon;
  final String label;
  final int? numValue;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return GlassCard(
      showBorder: true,
      showLightSweep: true,
      padding: const EdgeInsets.symmetric(vertical: S.s, horizontal: S.s),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) => C.gradientPrimary.createShader(b),
            child: icon,
          ),
          const SizedBox(height: S.xs),
          if (numValue != null)
            AnimatedNumber(
              value: numValue!,
              suffix: suffix,
              style: ts.titleMedium,
            )
          else
            Text('—', style: ts.titleMedium),
          Text(label, style: ts.bodySmall),
        ],
      ),
    );
  }
}

// ==========================================================================
// Plant dot — stage-based visuals, tap bounce, wilting effects
// ==========================================================================

class _PlantDot extends StatefulWidget {
  const _PlantDot({
    super.key,
    required this.plant,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final GardenPlant plant;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_PlantDot> createState() => _PlantDotState();
}

class _PlantDotState extends State<_PlantDot> with TickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final CurvedAnimation _tapCurve;
  late final AnimationController _glowCtrl;
  late final AnimationController _wiltCtrl;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 500),
    );
    _tapCurve = CurvedAnimation(
      parent: _tapCtrl,
      curve: Curves.easeIn,
      reverseCurve: Anim.curveGentle,
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _glowCtrl.value = math.Random().nextDouble();
    _glowCtrl.repeat(reverse: true);

    _wiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.plant.isWilting) _wiltCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PlantDot old) {
    super.didUpdateWidget(old);
    if (widget.plant.isWilting && !_wiltCtrl.isAnimating) {
      _wiltCtrl.repeat(reverse: true);
    } else if (!widget.plant.isWilting && _wiltCtrl.isAnimating) {
      _wiltCtrl
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_glowCtrl.isAnimating) _glowCtrl.stop();
      if (_wiltCtrl.isAnimating) _wiltCtrl.stop();
      _glowCtrl.value = 0;
      _wiltCtrl.value = 0;
    } else {
      if (!_glowCtrl.isAnimating) _glowCtrl.repeat(reverse: true);
      if (widget.plant.isWilting && !_wiltCtrl.isAnimating) {
        _wiltCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _tapCurve.dispose();
    _tapCtrl.dispose();
    _glowCtrl.dispose();
    _wiltCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_tapCtrl.isAnimating) return;
    HapticFeedback.lightImpact();
    _tapCtrl.forward().then((_) {
      if (mounted) _tapCtrl.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.plant.calculatedStage;
    final plantSize = 16.0 + 32.0 * stage.scale;
    final color = widget.plant.type.color;
    final wilting = widget.plant.isWilting;
    final outerSize = math.max(plantSize * 1.6, 40.0);

    return Positioned(
      left: widget.plant.posX * widget.width - outerSize / 2,
      top: widget.plant.posY * widget.height - outerSize / 2,
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: Listenable.merge([_tapCurve, _glowCtrl, _wiltCtrl]),
          builder: (context, _) {
            final scale = 1.0 - 0.1 * _tapCurve.value;
            final wiltAngle = wilting
                ? (_wiltCtrl.value * 2 - 1) * (2 * math.pi / 180)
                : 0.0;

            Widget visual =
                _buildVisual(stage, plantSize, color, _glowCtrl.value);

            if (wilting) {
              visual = Opacity(
                opacity: 0.55,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.5, 0.33, 0.17, 0, 0,
                    0.17, 0.5, 0.33, 0, 0,
                    0.17, 0.33, 0.5, 0, 0,
                    0, 0, 0, 0.6, 0,
                  ]),
                  child: visual,
                ),
              );
            }

            return GestureDetector(
              onTap: _handleTap,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label:
                    '${widget.plant.type.nameRu}, стадия ${widget.plant.calculatedStage.label}, здоровье ${(widget.plant.healthLevel * 100).round()}%',
                child: SizedBox(
                  width: outerSize,
                  height: outerSize,
                  child: Transform.rotate(
                    angle: wiltAngle,
                    child: Transform.scale(
                      scale: scale,
                      child: Center(child: visual),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVisual(
    GrowthStage stage,
    double size,
    Color color,
    double glowT,
  ) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlantPainter(
        stage: stage,
        color: color,
        progress: _glowCtrl.value,
        glowT: glowT,
      ),
    );
  }
}

// ==========================================================================
// Stylized plant illustration per growth stage
// ==========================================================================

class _PlantPainter extends CustomPainter {
  _PlantPainter({
    required this.stage,
    required this.color,
    required this.progress,
    required this.glowT,
  });

  final GrowthStage stage;
  final Color color;
  final double progress;
  final double glowT;

  static const _green = Color(0xFF4CAF50);
  static const _earthBrown = Color(0xFF5D4037);

  double _sway(Size size, [double factor = 1.0]) =>
      math.sin(progress * 2 * math.pi) * size.width * 0.05 * factor;

  Color _leafTint() =>
      Color.lerp(_green, color, 0.2) ?? _green;

  void _drawEarthBase(
    Canvas canvas,
    double cx,
    double baseY,
    double w,
    double h, {
    double widthFactor = 0.35,
    double heightFactor = 0.08,
    double alpha = 0.55,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + h * 0.02),
        width: w * widthFactor,
        height: h * heightFactor,
      ),
      Paint()..color = _earthBrown.withValues(alpha: alpha),
    );
  }

  Path _stemQuadraticPath(
    double cx,
    double baseY,
    double topY,
    double sway,
    double tipXOffset,
  ) {
    final midY = (baseY + topY) / 2;
    return Path()
      ..moveTo(cx, baseY)
      ..quadraticBezierTo(cx + sway, midY, cx + tipXOffset, topY);
  }

  void _drawOvalLeaf(
    Canvas canvas,
    Offset anchor,
    double angleRad,
    double lw,
    double lh,
    Color fill,
  ) {
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(angleRad);
    canvas.translate(lw * 0.15, -lh * 0.35);
    canvas.drawOval(
      Rect.fromLTWH(0, -lh, lw, lh),
      Paint()..color = fill,
    );
    canvas.restore();
  }

  void _paintSeed(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final earthRect = Rect.fromCenter(
      center: Offset(cx, h * 0.82),
      width: w * 0.42,
      height: h * 0.14,
    );
    canvas.drawOval(
      earthRect,
      Paint()..color = _earthBrown.withValues(alpha: 0.7),
    );

    final sprout = Offset(cx, earthRect.top + 1.2);
    final glowAlpha = 0.35 + 0.3 * glowT;
    canvas.drawCircle(
      sprout,
      4.0,
      Paint()
        ..color = _green.withValues(alpha: glowAlpha * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      sprout,
      2.0,
      Paint()..color = _green.withValues(alpha: 0.95),
    );
  }

  void _paintSprout(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * 0.88;
    final topY = h * 0.28;
    final sway = _sway(size);
    final tipX = cx + sway * 0.42;

    _drawEarthBase(canvas, cx, baseY, w, h);

    final stemPaint = Paint()
      ..color = _green
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      _stemQuadraticPath(cx, baseY, topY, sway, tipX - cx),
      stemPaint,
    );

    final tip = Offset(tipX, topY);
    _drawOvalLeaf(canvas, tip, -0.75, w * 0.09, h * 0.055, _green);
    _drawOvalLeaf(canvas, tip, 0.75, w * 0.09, h * 0.055, _green);
  }

  void _paintYoung(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * 0.9;
    final topY = h * 0.22;
    final sway = _sway(size, 0.85);
    final tipX = cx + sway * 0.38;

    _drawEarthBase(canvas, cx, baseY, w, h, widthFactor: 0.38);

    final stemPaint = Paint()
      ..color = _green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      _stemQuadraticPath(cx, baseY, topY, sway, tipX - cx),
      stemPaint,
    );

    final tint = _leafTint();
    const n = 4;
    for (var i = 0; i < n; i++) {
      final t = (i + 1) / (n + 1);
      final sy = baseY - (baseY - topY) * t;
      final alongSway = sway * (1.0 - t * 0.35);
      final px = cx + alongSway * 0.5 + (i.isEven ? -1 : 1) * w * 0.02;
      final py = sy;
      final side = i.isEven ? -1.0 : 1.0;
      _drawOvalLeaf(
        canvas,
        Offset(px, py),
        side * 0.85 + sway * 0.01,
        w * 0.1,
        h * 0.065,
        tint,
      );
    }

    final budCenter = Offset(tipX, topY);
    final budPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: budCenter + Offset(0, -h * 0.028),
          width: w * 0.14,
          height: h * 0.1,
        ),
      );
    canvas.drawPath(
      budPath,
      Paint()
        ..color = Color.lerp(color, _green, 0.35)!
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      budPath,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );
  }

  Path _halfOpenPetalPath(double petalLen, double spread) {
    final path = Path()..moveTo(0, 0);
    path.quadraticBezierTo(spread, -petalLen * 0.45, 0, -petalLen);
    path.quadraticBezierTo(-spread, -petalLen * 0.45, 0, 0);
    path.close();
    return path;
  }

  Path _bloomingPetalPath(double petalLen, double spread) {
    final path = Path()..moveTo(0, 0);
    path.quadraticBezierTo(spread * 1.15, -petalLen * 0.52, 0, -petalLen);
    path.quadraticBezierTo(-spread * 1.15, -petalLen * 0.52, 0, 0);
    path.close();
    return path;
  }

  void _paintMature(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * 0.92;
    final topY = h * 0.2;
    final sway = _sway(size, 0.75);
    final tipX = cx + sway * 0.35;

    _drawEarthBase(canvas, cx, baseY, w, h, widthFactor: 0.4);

    final stemPaint = Paint()
      ..color = _green
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      _stemQuadraticPath(cx, baseY, topY, sway, tipX - cx),
      stemPaint,
    );

    final tint = _leafTint();
    const n = 5;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.55) / (n + 0.4);
      final sy = baseY - (baseY - topY) * t;
      final alongSway = sway * (1.0 - t * 0.3);
      final px = cx + alongSway * 0.48 + (i.isEven ? -1 : 1) * w * 0.025;
      final side = i.isEven ? -1.0 : 1.0;
      _drawOvalLeaf(
        canvas,
        Offset(px, sy),
        side * 0.78 + sway * 0.008,
        w * 0.12,
        h * 0.078,
        tint,
      );
    }

    final flowerCx = tipX;
    final flowerCy = topY - h * 0.02;
    const petals = 5;
    final petalLen = h * 0.16;
    final spread = w * 0.07;
    final petalSway = sway * 0.012;

    for (var i = 0; i < petals; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / petals + petalSway;
      canvas.save();
      canvas.translate(flowerCx, flowerCy);
      canvas.rotate(angle);
      canvas.drawPath(
        _halfOpenPetalPath(petalLen, spread),
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        _halfOpenPetalPath(petalLen, spread),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  void _paintBlooming(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseY = h * 0.92;
    final topY = h * 0.18;
    final sway = _sway(size, 0.65);
    final tipX = cx + sway * 0.32;

    _drawEarthBase(canvas, cx, baseY, w, h, widthFactor: 0.42);

    final stemPaint = Paint()
      ..color = _green
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      _stemQuadraticPath(cx, baseY, topY, sway, tipX - cx),
      stemPaint,
    );

    final tint = _leafTint();
    const n = 6;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / (n + 0.35);
      final sy = baseY - (baseY - topY) * t;
      final alongSway = sway * (1.0 - t * 0.28);
      final px = cx + alongSway * 0.46 + (i.isEven ? -1 : 1) * w * 0.028;
      final side = i.isEven ? -1.0 : 1.0;
      _drawOvalLeaf(
        canvas,
        Offset(px, sy),
        side * 0.72 + sway * 0.006,
        w * 0.13,
        h * 0.085,
        tint,
      );
    }

    final flowerCx = tipX;
    final flowerCy = topY - h * 0.025;
    final glowR = w * 0.22;
    final glowAlpha = 0.3 + 0.2 * glowT;
    canvas.drawCircle(
      Offset(flowerCx, flowerCy),
      glowR,
      Paint()
        ..color = color.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    const petals = 6;
    final petalLen = h * 0.2;
    final spread = w * 0.085;
    final petalSway = sway * 0.01;
    final soft = color.withValues(alpha: 0.5);

    for (var i = 0; i < petals; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / petals + petalSway;
      canvas.save();
      canvas.translate(flowerCx, flowerCy);
      canvas.rotate(angle);
      final bounds = Rect.fromCenter(
        center: Offset(0, -petalLen * 0.48),
        width: spread * 2.8,
        height: petalLen * 1.15,
      );
      final petalPath = _bloomingPetalPath(petalLen, spread);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, soft],
        ).createShader(bounds);
      canvas.drawPath(petalPath, paint);
      canvas.drawPath(
        petalPath,
        Paint()
          ..color = color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    final orbit = w * 0.28;
    const sparkles = 6;
    for (var i = 0; i < sparkles; i++) {
      final base = (i / sparkles) * 2 * math.pi;
      final ang = base + glowT * 2 * math.pi;
      final ox = flowerCx + math.cos(ang) * orbit;
      final oy = flowerCy + math.sin(ang) * orbit * 0.88;
      final tw =
          (0.4 + 0.5 * math.sin(glowT * 2 * math.pi + i * 1.1)).clamp(0.2, 0.95);
      canvas.drawCircle(
        Offset(ox, oy),
        1.6,
        Paint()
          ..color = Colors.white.withValues(alpha: tw)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawCircle(
        Offset(ox, oy),
        1.1,
        Paint()..color = Colors.white.withValues(alpha: tw * 0.95),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (stage) {
      case GrowthStage.seed:
        _paintSeed(canvas, size);
        break;
      case GrowthStage.sprout:
        _paintSprout(canvas, size);
        break;
      case GrowthStage.young:
        _paintYoung(canvas, size);
        break;
      case GrowthStage.mature:
        _paintMature(canvas, size);
        break;
      case GrowthStage.blooming:
        _paintBlooming(canvas, size);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PlantPainter oldDelegate) =>
      oldDelegate.stage != stage ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.glowT != glowT;
}

// ==========================================================================
// Starry painter — twinkling stars, falling stars, nebula glow
// ==========================================================================

class _StarryPainter extends CustomPainter {
  _StarryPainter({required this.seed, required this.animValue});

  final int seed;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080B18),
    );
    _paintNebula(canvas, size);
    _paintStars(canvas, size);
    _paintFallingStars(canvas, size);
  }

  void _paintNebula(Canvas canvas, Size size) {
    final t = animValue * 2 * math.pi;

    final c1 = Offset(
      size.width * (0.3 + 0.05 * math.sin(t * 0.3)),
      size.height * (0.35 + 0.04 * math.cos(t * 0.2)),
    );
    final r1 = size.width * 0.35;
    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = RadialGradient(
          colors: [C.primary.withValues(alpha: 0.06), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c1, radius: r1)),
    );

    final c2 = Offset(
      size.width * (0.7 + 0.04 * math.cos(t * 0.25)),
      size.height * (0.65 + 0.04 * math.sin(t * 0.15)),
    );
    final r2 = size.width * 0.28;
    canvas.drawCircle(
      c2,
      r2,
      Paint()
        ..shader = RadialGradient(
          colors: [C.accent.withValues(alpha: 0.04), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c2, radius: r2)),
    );
  }

  void _paintStars(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final t = animValue * 2 * math.pi;
    final paint = Paint();

    for (var i = 0; i < 120; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.2 + 0.3;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final baseO = rnd.nextDouble() * 0.5 + 0.2;
      final twinkle =
          (baseO * (0.4 + 0.6 * ((math.sin(t + phase) + 1) * 0.5)))
              .clamp(0.05, 1.0);

      paint.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintFallingStars(Canvas canvas, Size size) {
    final rnd = math.Random(seed + 999);

    for (var i = 0; i < 3; i++) {
      final cycleLen = 12.0 + rnd.nextDouble() * 8;
      final startFrac = rnd.nextDouble();
      final angleDeg = 25.0 + rnd.nextDouble() * 20;

      final rawT =
          ((animValue * 20.0 + i * 7.3 + startFrac * cycleLen) % cycleLen) /
              cycleLen;
      if (rawT > 0.35) continue;
      final t = rawT / 0.35;

      final angle = angleDeg * math.pi / 180;
      final sx = size.width * (0.1 + i * 0.35);
      final travel = size.height * 1.1;

      final hx = sx + travel * math.sin(angle) * t;
      final hy = travel * math.cos(angle) * t;

      final tailFrac = math.max(0.0, t - 0.06);
      final tx = sx + travel * math.sin(angle) * tailFrac;
      final ty = travel * math.cos(angle) * tailFrac;

      final opacity = ((1.0 - t) * 0.6).clamp(0.0, 0.6);

      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.5)
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(hx, hy),
        1.5,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarryPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.animValue != animValue;
}

// ==========================================================================
// Premium badge with animated shimmer
// ==========================================================================

class _WeatherOverlay extends StatelessWidget {
  const _WeatherOverlay({required this.weather, required this.animation});
  final _GardenWeather weather;
  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    if (weather == _GardenWeather.clear) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(weather: weather, t: animation.value),
        );
      },
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({required this.weather, required this.t});
  final _GardenWeather weather;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    switch (weather) {
      case _GardenWeather.sunny:
        _paintSunny(canvas, size);
      case _GardenWeather.cloudy:
        _paintCloudy(canvas, size);
      case _GardenWeather.rain:
        _paintRain(canvas, size);
      case _GardenWeather.storm:
        _paintStorm(canvas, size);
      case _GardenWeather.clear:
        break;
    }
  }

  void _paintSunny(Canvas canvas, Size size) {
    final cx = size.width * 0.8;
    final cy = size.height * 0.08;
    final r = 30.0 + 4 * math.sin(t * 2 * math.pi);
    final alpha = 0.15 + 0.05 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.3),
    );
  }

  void _paintCloudy(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    for (var i = 0; i < 5; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = size.height * (0.02 + rnd.nextDouble() * 0.12);
      final w = 60.0 + rnd.nextDouble() * 80;
      final h = 20.0 + rnd.nextDouble() * 15;
      final drift = math.sin(t * 2 * math.pi + i) * 10;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + drift, cy), width: w, height: h),
        Paint()
          ..color = const Color(0xFF90A4AE).withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    _paintCloudy(canvas, size);
    final rnd = math.Random(77);
    final rainPaint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 40; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final y = ((t * speed + rnd.nextDouble()) % 1.0) * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 8),
        rainPaint,
      );
    }
  }

  void _paintStorm(Canvas canvas, Size size) {
    _paintRain(canvas, size);
    final flash = math.sin(t * 20 * math.pi);
    if (flash > 0.95) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.04),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) =>
      old.weather != weather || old.t != t;
}

class _PremiumBadge extends StatefulWidget {
  const _PremiumBadge();

  @override
  State<_PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<_PremiumBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            gradient: C.gradientGold,
            borderRadius: BorderRadius.circular(R.s),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.s),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 3.0 * t, 0),
              end: Alignment(-0.5 + 3.0 * t, 0),
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
          child: const Text(
            'Premium',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
