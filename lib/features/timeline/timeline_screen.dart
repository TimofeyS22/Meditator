import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aura = ref.watch(auraProvider);
    final history = aura.moodHistory;

    return Scaffold(
      backgroundColor: Cosmic.bg,
      body: CosmicBackground(
        intensity: 0.5,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _enterCtrl,
            builder: (_, __) {
              final val =
                  CurvedAnimation(parent: _enterCtrl, curve: Anim.curve).value;
              return Opacity(
                opacity: val,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Space.sm, Space.sm, Space.lg, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Cosmic.text),
                          ),
                          const Spacer(),
                          Text('Путь', style: t.titleLarge),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.sm),

                    if (aura.totalSessions > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg),
                        child: GlassCard(
                          padding: const EdgeInsets.all(Space.md),
                          opacity: 0.06,
                          child: Row(
                            children: [
                              _MiniStat(
                                value: '${aura.totalSessions}',
                                label: 'сессий',
                                color: Cosmic.primary,
                              ),
                              _MiniStat(
                                value: '${aura.streak}',
                                label: 'подряд',
                                color: Cosmic.warm,
                              ),
                              _MiniStat(
                                value: '${aura.totalMinutes}',
                                label: 'мин',
                                color: Cosmic.accent,
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: Space.lg),

                    if (history.isEmpty)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Space.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timeline_rounded,
                                    size: 48,
                                    color: Cosmic.textDim
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: Space.md),
                                Text(
                                  'Здесь появится твой путь',
                                  style: t.bodyLarge
                                      ?.copyWith(color: Cosmic.textDim),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: Space.sm),
                                Text(
                                  'После каждого чекина ты будешь видеть,\nкак меняется твоё состояние',
                                  style: t.bodySmall
                                      ?.copyWith(color: Cosmic.textDim),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Space.lg),
                          itemCount: history.length,
                          itemBuilder: (_, i) {
                            final entry =
                                history[history.length - 1 - i];
                            return _TimelineEntry(
                                entry: entry, isFirst: i == 0);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniStat(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: t.headlineLarge?.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: t.bodySmall?.copyWith(color: Cosmic.textDim, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final MoodEntry entry;
  final bool isFirst;

  const _TimelineEntry({required this.entry, required this.isFirst});

  (String label, IconData icon, Color color) get _data =>
      switch (entry.state) {
        EmotionalState.anxiety =>
          ('Тревога', Icons.air_rounded, Cosmic.accent),
        EmotionalState.fatigue =>
          ('Усталость', Icons.bedtime_rounded, Cosmic.warm),
        EmotionalState.overload =>
          ('Перегрузка', Icons.flash_on_rounded, Cosmic.rose),
        EmotionalState.emptiness =>
          ('Пустота', Icons.blur_on_rounded, Cosmic.primary),
        EmotionalState.calm =>
          ('Спокойствие', Icons.spa_rounded, Cosmic.green),
      };

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'сейчас';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} д назад';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (label, icon, color) = _data;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: isFirst ? 12 : 8,
                  height: isFirst ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? color : color.withValues(alpha: 0.4),
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                ),
                Container(
                    width: 1, height: 48, color: Cosmic.surfaceBorder),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              opacity: isFirst ? 0.08 : 0.04,
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(label,
                        style: t.titleMedium?.copyWith(color: color)),
                  ),
                  Text(_formatTime(entry.timestamp),
                      style: t.bodySmall?.copyWith(color: Cosmic.textDim)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
