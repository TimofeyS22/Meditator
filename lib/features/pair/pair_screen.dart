import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/pair.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/animated_number.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/aura_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDemoPartnershipKey = 'meditator_demo_partnership';
const _kDemoMessagesKey = 'meditator_demo_pair_messages';

Partnership? _partnershipFromRow(Map<String, dynamic> row, String uid) {
  final userId = row['user_id'] as String?;
  final partnerId = row['partner_id'] as String?;
  if (userId == null || partnerId == null) return null;
  final iAmUser = userId == uid;
  return Partnership.fromJson({
    'id': row['id'],
    'myId': uid,
    'partnerId': iAmUser ? partnerId : userId,
    'partnerName': iAmUser ? row['partner_name'] : null,
    'partnerAvatarUrl': row['partner_avatar_url'],
    'status': row['status'] ?? 'active',
    'sharedGoals': row['shared_goals'] ?? [],
    'myStreak': iAmUser
        ? (row['my_streak'] as num?)?.toInt() ?? 0
        : (row['partner_streak'] as num?)?.toInt() ?? 0,
    'partnerStreak': iAmUser
        ? (row['partner_streak'] as num?)?.toInt() ?? 0
        : (row['my_streak'] as num?)?.toInt() ?? 0,
    'sharedSessions': (row['shared_sessions'] as num?)?.toInt() ?? 0,
    'createdAt': row['created_at'],
  });
}

MeditationGoal? _goalByName(String name) {
  for (final g in MeditationGoal.values) {
    if (g.name == name) return g;
  }
  return null;
}

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  Partnership? _partnership;
  List<PairMessage> _messages = [];
  bool _loading = true;
  bool _demoMode = false;

  String? get _uid => AuthService.instance.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _uid;
    Partnership? p;
    List<PairMessage> msgs = [];
    var demo = false;

    try {
      if (uid != null && uid.isNotEmpty) {
        final row = await Db.instance.getPartnership(uid);
        if (row != null) {
          p = _partnershipFromRow(row, uid);
          final ownerId = row['user_id'] as String?;
          if (p != null && ownerId != null && ownerId != uid) {
            final prof = await Db.instance.getProfile(ownerId);
            final name = prof?['display_name'] as String?;
            if (name != null && name.isNotEmpty) {
              p = Partnership(
                id: p.id,
                myId: p.myId,
                partnerId: p.partnerId,
                partnerName: name,
                partnerAvatarUrl:
                    prof?['avatar_url'] as String? ?? p.partnerAvatarUrl,
                status: p.status,
                sharedGoals: p.sharedGoals,
                myStreak: p.myStreak,
                partnerStreak: p.partnerStreak,
                sharedSessions: p.sharedSessions,
                createdAt: p.createdAt,
              );
            }
          }
          if (p != null && !p.id.startsWith('demo-')) {
            final rawMsgs =
                await Db.instance.getPairMessages(p.id, limit: 50);
            msgs =
                rawMsgs.map((m) => PairMessage.fromJson(m)).toList();
          }
        }
        if (p == null) {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_kDemoPartnershipKey);
          if (raw != null && raw.isNotEmpty) {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            p = Partnership.fromJson(map);
            demo = p.id.startsWith('demo-');
            if (demo) {
              final mRaw = prefs.getString(_kDemoMessagesKey);
              if (mRaw != null && mRaw.isNotEmpty) {
                final list = jsonDecode(mRaw) as List<dynamic>;
                msgs = list
                    .map((e) => PairMessage.fromJson(
                        Map<String, dynamic>.from(e as Map)))
                    .toList();
              }
            }
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _partnership = p;
      _messages = msgs;
      _demoMode = demo;
      _loading = false;
    });
  }

  Future<void> _send(PairMessageType type, String content) async {
    final p = _partnership;
    final uid = _uid;
    if (p == null || uid == null || uid.isEmpty) return;

    if (_demoMode || p.id.startsWith('demo-')) {
      final msg = PairMessage(
        id: const Uuid().v4(),
        pairId: p.id,
        senderId: uid,
        type: type,
        content: content,
        createdAt: DateTime.now(),
      );
      final next = [msg, ..._messages];
      setState(() => _messages = next);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kDemoMessagesKey,
        jsonEncode(next.map((m) => m.toJson()).toList()),
      );
      return;
    }

    try {
      await Db.instance.insertPairMessage({
        'pair_id': p.id,
        'sender_id': uid,
        'type': type.name,
        'content': content,
      });
      if (!mounted) return;
      final rawMsgs = await Db.instance.getPairMessages(p.id, limit: 50);
      setState(() {
        _messages =
            rawMsgs.map((m) => PairMessage.fromJson(m)).toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить')),
        );
      }
    }
  }

  String _messageTitle(PairMessage m) {
    final mine = m.senderId == _uid;
    switch (m.type) {
      case PairMessageType.cheer:
        return mine ? 'Ты подбодрил(а)' : 'Подбадривание';
      case PairMessageType.nudge:
        return mine ? 'Ты напомнил(а)' : 'Напоминание';
      case PairMessageType.milestone:
        return mine ? 'Твоё событие' : 'Веха';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat.Hm('ru');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: C.primary))
            : RefreshIndicator(
                color: C.primary,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: context.cText),
                                  tooltip: 'Назад',
                                  onPressed: () => context.pop(),
                                ),
                                Expanded(
                                  child: Text(
                                    'Пара по практике',
                                    style: theme.textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: S.m),
                            if (_partnership == null) ...[
                              _NoPartnerCard(
                                onFind: () => context
                                    .push('/pair/find')
                                    .then((_) => _load()),
                              ).animate().fadeIn().slideY(begin: 0.06, end: 0),
                            ] else ...[
                              _PartnerAvatars(
                                partnership: _partnership!,
                                uid: _uid,
                              ),
                              const SizedBox(height: S.m),
                              _PartnerGoals(
                                partnership: _partnership!,
                                goalLabel: (s) {
                                  final g = _goalByName(s);
                                  return g != null
                                      ? g.label
                                      : s;
                                },
                              ),
                              const SizedBox(height: S.m),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(S.m),
                                      child: Column(
                                        children: [
                                          Text('Твоя серия',
                                              style: theme.textTheme.bodySmall),
                                          const SizedBox(height: S.xs),
                                          AnimatedNumber(
                                            value: _partnership!.myStreak,
                                            style: theme
                                                .textTheme.headlineMedium
                                                ?.copyWith(
                                                    color: C.accent,
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                          Text('дней',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: context.cTextSec)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: S.s),
                                  Expanded(
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(S.m),
                                      child: Column(
                                        children: [
                                          Text('У партнёра',
                                              style: theme.textTheme.bodySmall),
                                          const SizedBox(height: S.xs),
                                          AnimatedNumber(
                                            value:
                                                _partnership!.partnerStreak,
                                            style: theme
                                                .textTheme.headlineMedium
                                                ?.copyWith(
                                                    color: C.accent,
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                          Text('дней',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: context.cTextSec)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: S.m),
                              GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    vertical: S.m),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (b) =>
                                          C.gradientPrimary.createShader(b),
                                      child: const Icon(
                                          Icons.group_rounded,
                                          color: Colors.white,
                                          size: 20),
                                    ),
                                    const SizedBox(width: S.s),
                                    Text(
                                      'Совместных сессий: ',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    AnimatedNumber(
                                      value:
                                          _partnership!.sharedSessions,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: C.accent),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: S.m),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlowButton(
                                      onPressed: () => _send(
                                        PairMessageType.cheer,
                                        'Ты круто держишь ритм — горжусь тобой!',
                                      ),
                                      semanticLabel: 'Отправить поддержку партнёру',
                                      child: const Text('Подбодрить'),
                                    ),
                                  ),
                                  const SizedBox(width: S.s),
                                  Expanded(
                                    child: GlowButton(
                                      onPressed: () => _send(
                                        PairMessageType.nudge,
                                        'Напоминаю: короткая медитация сейчас зайдёт отлично.',
                                      ),
                                      glowColor: C.glowAccent,
                                      semanticLabel: 'Отправить напоминание партнёру',
                                      child: const Text('Напомнить'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: S.l),
                              Text('Недавние сообщения',
                                  style: theme.textTheme.headlineMedium),
                              const SizedBox(height: S.s),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_partnership != null && _messages.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Пока тихо — отправь первое сообщение',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else if (_partnership != null)
                      SliverPadding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: S.m),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final rev = _messages.reversed
                                  .toList(growable: false);
                              final m = rev[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: S.s),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(S.m),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _messageTitle(m),
                                              style: theme
                                                  .textTheme.titleSmall,
                                            ),
                                          ),
                                          Text(
                                            timeFmt.format(
                                                m.createdAt.toLocal()),
                                            style: theme
                                                .textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: S.xs),
                                      Text(m.content,
                                          style: theme
                                              .textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: (40 * index).ms);
                            },
                            childCount: _messages.length,
                          ),
                        ),
                      ),
                    if (_partnership != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(S.m),
                          child: Column(
                          children: [
                            GlowButton(
                              onPressed: () => context.push('/pair/live'),
                              width: double.infinity,
                              showGlow: true,
                              semanticLabel: 'Живая медитация с партнёром',
                              child: const Text('Живая медитация'),
                            ),
                            const SizedBox(height: S.s),
                            GlowButton(
                              onPressed: () async {
                                final meds = await Db.instance.getMeditations();
                                if (meds.isEmpty) return;
                                meds.shuffle();
                                final id = meds.first['id'] as String? ?? '';
                                if (id.isNotEmpty && context.mounted) {
                                  context.push('/play?id=${Uri.encodeComponent(id)}');
                                }
                              },
                              width: double.infinity,
                              glowColor: C.glowAccent,
                              semanticLabel: 'Запустить совместную медитацию',
                              child: const Text('Медитировать вместе'),
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
}

class _NoPartnerCard extends StatelessWidget {
  const _NoPartnerCard({required this.onFind});
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      showBorder: true,
      padding: const EdgeInsets.all(S.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Найди партнёра по практике',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: S.m),
          Text(
            'С партнёром до 95% людей чаще не бросают практику — вы держите друг друга в фокусе и честно делитесь прогрессом.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: S.s),
          Text(
            'Aura подберёт похожие цели или пришли другу код — и вы в одной волне.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: context.cTextDim, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: S.l),
          GlowButton(
            onPressed: onFind,
            width: double.infinity,
            semanticLabel: 'Открыть поиск партнёра',
            child: const Text('Найти'),
          ),
        ],
      ),
    );
  }
}

class _PartnerAvatars extends StatelessWidget {
  const _PartnerAvatars({required this.partnership, this.uid});
  final Partnership partnership;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = partnership.partnerName?.trim().isNotEmpty == true
        ? partnership.partnerName!
        : 'Партнёр';
    final url = partnership.partnerAvatarUrl;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const AuraAvatar(size: 72),
                  Text('Я',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(width: S.m),
            ShaderMask(
              shaderCallback: (b) => C.gradientPrimary.createShader(b),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: S.m),
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const AuraAvatar(size: 72),
                  if (url != null && url.isNotEmpty)
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: S.s),
        Text(name, style: theme.textTheme.headlineMedium),
      ],
    ).animate().fadeIn().slideY(begin: 0.04, end: 0);
  }
}

class _PartnerGoals extends StatelessWidget {
  const _PartnerGoals({required this.partnership, required this.goalLabel});
  final Partnership partnership;
  final String Function(String) goalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('Общие цели',
            style: theme.textTheme.titleSmall?.copyWith(color: context.cTextSec)),
        const SizedBox(height: S.s),
        Wrap(
          spacing: S.s,
          runSpacing: S.s,
          alignment: WrapAlignment.center,
          children: partnership.sharedGoals.isEmpty
              ? [
                  Text('Скоро добавите вместе',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: context.cTextDim)),
                ]
              : partnership.sharedGoals
                  .map(
                    (s) => Chip(
                      label: Text(goalLabel(s)),
                      backgroundColor: context.cSurfaceLight,
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.bodySmall,
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}
