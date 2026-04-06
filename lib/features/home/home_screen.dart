import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/aura/aura_engine.dart';
import 'package:meditator/core/aura/atmosphere.dart';
import 'package:meditator/core/cosmos/cosmos_state.dart';
import 'package:meditator/shared/theme/cosmic.dart';
import 'package:meditator/shared/widgets/cosmic_background.dart';
import 'package:meditator/shared/widgets/particle_field.dart';
import 'package:meditator/shared/widgets/aura_presence.dart';
import 'package:meditator/shared/widgets/cosmic_button.dart';
import 'package:meditator/shared/widgets/glass_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _moodTransitionCtrl;
  late final AnimationController _postSessionPulseCtrl;
  bool _hasPlayedPostPulse = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _moodTransitionCtrl = AnimationController(
      vsync: this,
      duration: Anim.slow,
    );

    _postSessionPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _moodTransitionCtrl.dispose();
    _postSessionPulseCtrl.dispose();
    super.dispose();
  }

  EmotionalState? _pendingMood;
  int _pendingIntensity = 3;

  void _selectMood(EmotionalState mood) {
    HapticFeedback.mediumImpact();

    // High-urgency moods skip intensity — get to help faster
    if (mood == EmotionalState.anxiety || mood == EmotionalState.overload) {
      setState(() => _pendingMood = null);
      ref.read(auraProvider.notifier).checkIn(mood, intensity: 4);
      _moodTransitionCtrl.forward(from: 0);
      return;
    }

    setState(() {
      _pendingMood = mood;
      _pendingIntensity = 3;
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _pendingMood != null) {
        _confirmMood();
      }
    });
  }

  void _setIntensity(int value) {
    HapticFeedback.selectionClick();
    setState(() => _pendingIntensity = value);
  }

  void _confirmMood() {
    if (_pendingMood == null) return;
    final mood = _pendingMood!;
    final intensity = _pendingIntensity;
    setState(() => _pendingMood = null);
    ref.read(auraProvider.notifier).checkIn(mood, intensity: intensity);
    _moodTransitionCtrl.forward(from: 0);
  }

  void _startAction() {
    HapticFeedback.mediumImpact();
    final atm = ref.read(auraProvider).atmosphere;
    context.push(
      '/session?type=${atm.action.sessionType}&duration=${atm.action.durationSeconds}',
    );
  }

  void _realityBreak() {
    HapticFeedback.heavyImpact();
    ref.read(auraProvider.notifier).realityBreakTriggered();
    context.push('/reality-break');
  }

  Widget _reveal(Animation<double> parent, double delay, Widget child) {
    final curved = CurvedAnimation(
      parent: parent,
      curve: Interval(delay, (delay + 0.5).clamp(0, 1), curve: Anim.curve),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, w) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - curved.value)),
          child: w,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final aura = ref.watch(auraProvider);
    final cosmos = ref.watch(cosmosStateProvider);
    final atm = aura.atmosphere;
    final cfg = atm.visualConfig;
    final mode = atm.responseMode;

    // Play entry pulse once when returning from session with active glow
    if (cosmos.postSessionGlow > 0.5 && !_hasPlayedPostPulse) {
      _hasPlayedPostPulse = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _postSessionPulseCtrl.forward(from: 0);
      });
    }

    return Scaffold(
      backgroundColor: Cosmic.bg,
      body: AnimatedBuilder(
        animation: _postSessionPulseCtrl,
        builder: (_, child) {
          final pulseT = _postSessionPulseCtrl.value;
          final pulseScale = pulseT > 0
              ? 1.0 + 0.015 * Curves.easeInOutSine.transform(
                  pulseT < 0.5 ? pulseT * 2 : 2.0 - pulseT * 2)
              : 1.0;
          return Transform.scale(scale: pulseScale, child: child);
        },
        child: CosmicBackground(
          mood: cosmos.mood,
          silentMode: cosmos.silentMode,
          seed: cosmos.personalSeed,
          extraStars: cosmos.starCount - 50,
          bloomBoost: cosmos.bloomBoost + cosmos.memoryEchoBloom,
          child: Stack(
          children: [
            Positioned.fill(
              child: ParticleField(
                count: cfg.particleCount,
                maxRadius: cfg.particleMaxPx,
                minRadius: cfg.particleMinPx,
                color: cfg.accentColor,
                speed: cfg.particleSpeed * cosmos.particleSpeedMod,
                alpha: (cfg.particleAlpha + cosmos.contrastAlphaBoost).clamp(0.0, 1.0),
                chaotic: cfg.chaotic || cosmos.glowChaosOverride,
              ),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _enterCtrl,
                builder: (_, __) => Column(
                  children: [
                    // ── Top bar ──────────────────────────────────
                    _reveal(
                      _enterCtrl,
                      0.0,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Space.lg, Space.sm, Space.lg, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (aura.streak > 0)
                              Row(children: [
                                const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 16,
                                    color: Cosmic.warm),
                                const SizedBox(width: 4),
                                Text(
                                  '${aura.streak} ${_pluralDays(aura.streak)}',
                                  style: t.bodySmall?.copyWith(
                                    color: Cosmic.warm,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ])
                            else
                              const SizedBox.shrink(),
                            Row(children: [
                              _TopButton(
                                icon: Icons.timeline_rounded,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.push('/timeline');
                                },
                              ),
                              const SizedBox(width: Space.sm),
                              _TopButton(
                                icon: Icons.person_rounded,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.push('/profile');
                                },
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),

                    // ── Scrollable center content ───────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            SizedBox(height: aura.hasCheckedIn ? Space.lg : Space.xxxl),

                            // ── Intensity picker (between mood select and check-in)
                            if (_pendingMood != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                                child: Column(
                                  children: [
                                    Text(
                                      'Насколько сильно?',
                                      style: t.bodyLarge?.copyWith(
                                        color: Cosmic.textMuted,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    const SizedBox(height: Space.lg),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(5, (i) {
                                        final level = i + 1;
                                        final active = level <= _pendingIntensity;
                                        return GestureDetector(
                                          onTap: () => _setIntensity(level),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            margin: const EdgeInsets.symmetric(horizontal: 5),
                                            width: 40, height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: active
                                                  ? Cosmic.primary.withValues(alpha: 0.3 + 0.15 * level)
                                                  : Colors.white.withValues(alpha: 0.06),
                                              border: Border.all(
                                                color: active
                                                    ? Cosmic.primary.withValues(alpha: 0.5)
                                                    : Colors.white.withValues(alpha: 0.1),
                                              ),
                                              boxShadow: active ? [
                                                BoxShadow(
                                                  color: Cosmic.primary.withValues(alpha: 0.15),
                                                  blurRadius: 10,
                                                ),
                                              ] : null,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: Space.lg),
                                    GestureDetector(
                                      onTap: _confirmMood,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(Radii.full),
                                          color: Cosmic.primary.withValues(alpha: 0.15),
                                          border: Border.all(color: Cosmic.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Text('Готово', style: t.labelMedium?.copyWith(color: Cosmic.primary)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── Mood selector (before check-in) ─────────
                            if (!aura.hasCheckedIn && _pendingMood == null) ...[
                              _reveal(
                                _enterCtrl,
                                0.1,
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Space.lg),
                                  child: Text('Как ты сейчас?',
                                      style: t.displayMedium,
                                      textAlign: TextAlign.center),
                                ),
                              ),
                              const SizedBox(height: Space.xl),
                              _reveal(
                                _enterCtrl,
                                0.2,
                                _MoodSelector(onSelect: _selectMood),
                              ),
                            ],

                            // ── After check-in: orb + AI response ───────
                            if (aura.hasCheckedIn) ...[
                              _reveal(
                                _enterCtrl,
                                0.0,
                                AuraPresence(
                                  size: 160,
                                  color: cfg.accentColor,
                                  glowColor: cfg.bloomColor.withValues(alpha: 0.5),
                                  state: presenceStateFromResponse(
                                    responseMode: mode,
                                    hasCheckedIn: aura.hasCheckedIn,
                                  ),
                                  onTap: _startAction,
                                ),
                              ),

                              if (mode != 'silent' && atm.auraPresence.isNotEmpty) ...[
                                const SizedBox(height: Space.md),
                                AnimatedSwitcher(
                                  duration: Anim.slow,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Space.xl),
                                    child: Text(
                                      atm.auraPresence,
                                      key: ValueKey(atm.auraPresence),
                                      style: t.bodyLarge?.copyWith(
                                        color: Cosmic.textMuted,
                                        fontWeight: FontWeight.w300,
                                        fontSize: 18,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],

                              if (mode == 'reflective' && atm.insight != null) ...[
                                const SizedBox(height: Space.md),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Space.lg),
                                  child: GlassCard(
                                    opacity: 0.08,
                                    borderRadius:
                                        BorderRadius.circular(Radii.md),
                                    padding: const EdgeInsets.all(Space.md),
                                    child: Text(
                                      atm.insight!,
                                      style: t.bodyMedium?.copyWith(
                                        color: Cosmic.text.withValues(alpha: 0.8),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: Space.xl),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Space.lg),
                                child: CosmicButton(
                                  onPressed: _startAction,
                                  width: double.infinity,
                                  gradient: mode == 'suggestion'
                                      ? LinearGradient(colors: [
                                          cfg.accentColor,
                                          cfg.accentColor.withValues(alpha: 0.8),
                                        ])
                                      : LinearGradient(colors: [
                                          atm.action.color,
                                          atm.action.color.withValues(alpha: 0.7),
                                        ]),
                                  child: Text(atm.action.label),
                                ),
                              ),

                              if (mode != 'silent') ...[
                                const SizedBox(height: Space.sm),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Space.xxl),
                                  child: Text(
                                    atm.action.shortPrompt,
                                    style: t.bodySmall
                                        ?.copyWith(color: Cosmic.textDim),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],

                              const SizedBox(height: Space.lg),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(auraProvider.notifier).resetCheckIn();
                                },
                                child: Text(
                                  'Изменилось состояние?',
                                  style: t.bodySmall?.copyWith(
                                    color: Cosmic.textDim,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        Cosmic.textDim.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: Space.lg),
                          ],
                        ),
                      ),
                    ),

                    // ── Reality break button (always visible) ───
                    _reveal(
                      _enterCtrl,
                      0.4,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Space.lg, 0, Space.lg, Space.md),
                        child: _RealityBreakButton(onTap: _realityBreak),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _pluralDays(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }
}

// ─── Top icon button ─────────────────────────────────────────────────────────

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Cosmic.surface.withValues(alpha: 0.5),
          border: Border.all(color: Cosmic.surfaceBorder),
        ),
        child: Icon(icon, color: Cosmic.textDim, size: 20),
      ),
    );
  }
}

// ─── Mood selector ───────────────────────────────────────────────────────────

class _MoodSelector extends StatelessWidget {
  final ValueChanged<EmotionalState> onSelect;
  const _MoodSelector({required this.onSelect});

  static const _moods = [
    (EmotionalState.anxiety, 'Тревога', Icons.air_rounded, Cosmic.accent),
    (EmotionalState.fatigue, 'Усталость', Icons.bedtime_rounded, Cosmic.warm),
    (EmotionalState.overload, 'Перегрузка', Icons.flash_on_rounded, Cosmic.rose),
    (EmotionalState.emptiness, 'Пустота', Icons.blur_on_rounded, Cosmic.primary),
    (EmotionalState.calm, 'Спокойствие', Icons.spa_rounded, Cosmic.green),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        alignment: WrapAlignment.center,
        children: _moods.map((item) {
          final (state, label, icon, color) = item;
          return GestureDetector(
            onTap: () => onSelect(state),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: Space.md, vertical: 12),
              opacity: 0.06,
              borderRadius: BorderRadius.circular(Radii.full),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: Space.sm),
                  Text(label,
                      style: t.labelMedium?.copyWith(color: color)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Reality Break Button ────────────────────────────────────────────────────

class _RealityBreakButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RealityBreakButton({required this.onTap});
  @override
  State<_RealityBreakButton> createState() => _RealityBreakButtonState();
}

class _RealityBreakButtonState extends State<_RealityBreakButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = Curves.easeInOut.transform(_pulseCtrl.value);
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              color: Cosmic.surface,
              border: Border.all(
                color: Cosmic.rose.withValues(alpha: 0.15 + 0.1 * pulse),
              ),
              boxShadow: [
                BoxShadow(
                  color: Cosmic.rose.withValues(alpha: 0.06 + 0.04 * pulse),
                  blurRadius: 16 + 8 * pulse,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded,
                    size: 18,
                    color: Cosmic.rose.withValues(alpha: 0.7)),
                const SizedBox(width: Space.sm),
                Text(
                  'Мне плохо',
                  style: t.labelLarge?.copyWith(
                    color: Cosmic.rose.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
