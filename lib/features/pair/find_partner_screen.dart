import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/config/env.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/pair.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/morphing_blob.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDemoPartnershipKey = 'meditator_demo_partnership';
const _kDemoMessagesKey = 'meditator_demo_pair_messages';

class FindPartnerScreen extends StatefulWidget {
  const FindPartnerScreen({super.key});

  @override
  State<FindPartnerScreen> createState() => _FindPartnerScreenState();
}

class _FindPartnerScreenState extends State<FindPartnerScreen>
    with SingleTickerProviderStateMixin {
  bool _searching = false;
  List<MeditationGoal> _goals = MeditationGoal.values.take(4).toList();
  late final AnimationController _pulseCtrl;
  bool _reduceMotion = false;

  String? get _uid => AuthService.instance.userId;

  String get _inviteCode {
    final id = _uid ?? 'guest';
    if (id.length >= 8) return id.substring(0, 8).toUpperCase();
    return id.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadGoals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      if (_pulseCtrl.isAnimating) _pulseCtrl.stop();
    } else if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final row = await Db.instance.getProfile(uid);
      if (row != null && mounted) {
        final p = UserProfile.fromJson(row);
        if (p.goals.isNotEmpty) setState(() => _goals = p.goals);
      }
    } catch (_) {}
  }

  Partnership _buildDemoPartnership(String uid) {
    return Partnership(
      id: 'demo-$uid',
      myId: uid,
      partnerId: 'aura-demo',
      partnerName: 'Практик Aura',
      status: PairStatus.active,
      sharedGoals: _goals.map((g) => g.name).toList(),
      myStreak: 3,
      partnerStreak: 5,
      sharedSessions: 12,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _matchByGoals() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Войди в аккаунт, чтобы найти партнёра')),
        );
      }
      return;
    }

    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(seconds: 2));

    final demoId = Env.demoPartnerId.trim();
    var inserted = false;
    if (demoId.isNotEmpty) {
      try {
        await Db.instance.insertPartnership({
          'user_id': uid,
          'partner_id': demoId,
          'partner_name': 'Партнёр по целям',
          'status': 'active',
          'shared_goals': _goals.map((g) => g.name).toList(),
          'my_streak': 3,
          'partner_streak': 5,
          'shared_sessions': 1,
        });
        inserted = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kDemoPartnershipKey);
        await prefs.remove(_kDemoMessagesKey);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Не удалось создать пару на сервере — сохраняем демо локально')),
          );
        }
      }
    }

    if (!inserted) {
      final demo = _buildDemoPartnership(uid);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kDemoPartnershipKey, jsonEncode(demo.toJson()));
      await prefs.remove(_kDemoMessagesKey);
    }

    if (!mounted) return;
    setState(() => _searching = false);
    context.pop();
  }

  Future<void> _shareInvite() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Партнёр по практике в Meditator — код: $_inviteCode\n'
            'Aura и мы вместе держим мотивацию',
        subject: 'Приглашение в Meditator',
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: context.cText),
                        tooltip: 'Назад',
                        onPressed: _searching ? null : () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Найти партнёра',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: S.m),
                  Text(
                    'Партнёр — не конкурент, а союзник: вы видите серии друг друга, кидаете «напоминалки» и не пропадаете в рутине.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: S.l),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Зачем это Gen Z',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: S.s),
                        Text(
                          'Аккаунтабилити бустит дисциплину до ~95% — короткие чек-ины с Aura и партнёром превращают практику в социальный ритуал без токсичности.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: S.l),

                  Text('Твой код приглашения',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: context.cTextSec),
                      textAlign: TextAlign.center),
                  const SizedBox(height: S.s),
                  GlassCard(
                    onTap: _copyCode,
                    semanticLabel: 'Код приглашения $_inviteCode, нажмите чтобы скопировать',
                    showBorder: true,
                    child: Center(
                      child: Text(
                        _inviteCode,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: C.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: S.xs),
                  Text(
                    'Нажми, чтобы скопировать',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),

                  const SizedBox(height: S.xl),
                  GlowButton(
                    onPressed: _searching ? null : _matchByGoals,
                    width: double.infinity,
                    showGlow: true,
                    semanticLabel: 'Найти партнёра по целям',
                    child: const Text('Найти по целям'),
                  ),
                  const SizedBox(height: S.m),
                  GlowButton(
                    onPressed: _searching ? null : _shareInvite,
                    width: double.infinity,
                    glowColor: C.glowAccent,
                    semanticLabel: 'Поделиться кодом приглашения',
                    child: const Text('Пригласить друга'),
                  ),
                ],
              ),
            ),

            if (_searching)
              Positioned.fill(
                child: ColoredBox(
                  color: context.cBg.withValues(alpha: 0.88),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, _) {
                            final t = _reduceMotion ? 0.0 : _pulseCtrl.value;
                            return SizedBox(
                              height: 160,
                              width: 160,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: 0.3 + t * 0.2,
                                    child: Transform.scale(
                                      scale: 1.0 + t * 0.3,
                                      child: MorphingBlob(
                                          size: 140, color: C.primary),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: 0.5 + t * 0.3,
                                    child: Transform.scale(
                                      scale: 0.7 + t * 0.15,
                                      child: MorphingBlob(
                                          size: 100, color: C.accent),
                                    ),
                                  ),
                                  Icon(Icons.hub_rounded,
                                      size: 40,
                                      color: C.primary.withValues(
                                          alpha: 0.9 + t * 0.1)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: S.l),
                        Text(
                          'Ищем партнёра…',
                          style: theme.textTheme.titleMedium,
                        ).animate().fadeIn(duration: Anim.normal),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
