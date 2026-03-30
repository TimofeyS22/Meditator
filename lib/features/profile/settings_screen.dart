import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:meditator/shared/models/user_profile.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meditator/main.dart' show themeNotifier, setThemeMode;

const _kDuration = 'settings_preferred_duration';
const _kVoice = 'settings_preferred_voice';
const _kHour = 'settings_preferred_time_hour';
const _kNotifPractice = 'settings_notif_practice';
const _kNotifPartner = 'settings_notif_partner';

PreferredDuration _parseDuration(String? v) {
  if (v == null || v.isEmpty) return PreferredDuration.min10;
  for (final e in PreferredDuration.values) {
    if (e.name == v) return e;
  }
  return PreferredDuration.min10;
}

PreferredVoice _parseVoice(String? v) {
  if (v == null || v.isEmpty) return PreferredVoice.any;
  return PreferredVoiceX.fromString(v);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PreferredDuration _duration = PreferredDuration.min10;
  PreferredVoice _voice = PreferredVoice.any;
  int _timeHour = 9;
  bool _notifPractice = true;
  bool _notifPartner = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _duration = _parseDuration(p.getString(_kDuration));
      _voice = _parseVoice(p.getString(_kVoice));
      _timeHour = p.getInt(_kHour) ?? 9;
      _notifPractice = p.getBool(_kNotifPractice) ?? true;
      _notifPartner = p.getBool(_kNotifPartner) ?? true;
    });
  }

  Future<void> _saveDuration(PreferredDuration v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDuration, v.name);
    setState(() => _duration = v);
    _syncToBackend();
  }

  Future<void> _saveVoice(PreferredVoice v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kVoice, v.jsonName);
    setState(() => _voice = v);
    _syncToBackend();
  }

  Future<void> _saveHour(int h) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHour, h);
    setState(() => _timeHour = h);
    _syncToBackend();
  }

  Future<void> _saveNotifPractice(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifPractice, v);
    setState(() => _notifPractice = v);
    _syncToBackend();
  }

  Future<void> _saveNotifPartner(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifPartner, v);
    setState(() => _notifPartner = v);
    _syncToBackend();
  }

  void _syncToBackend() {
    final uid = AuthService.instance.userId;
    if (uid == null || uid.isEmpty) return;
    Db.instance.upsertProfile({
      'preferred_duration': _duration.name,
      'preferred_voice': _voice.jsonName,
      'preferred_time_hour': _timeHour,
      'notif_practice': _notifPractice,
      'notif_partner': _notifPartner,
    });
  }

  Future<void> _pickDuration() async {
    final chosen = await showDialog<PreferredDuration>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        title: const Text('Длительность практики'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PreferredDuration.values
              .map(
                (d) => ListTile(
                  title: Text(d.label),
                  trailing: _duration == d
                      ? const MIcon(MIconType.check, color: C.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, d),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (chosen != null) await _saveDuration(chosen);
  }

  Future<void> _pickVoice() async {
    final chosen = await showDialog<PreferredVoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        title: const Text('Голос'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PreferredVoice.values
              .map(
                (v) => ListTile(
                  title: Text(switch (v) {
                    PreferredVoice.male => 'Мужской',
                    PreferredVoice.female => 'Женский',
                    PreferredVoice.any => 'Любой',
                  }),
                  trailing: _voice == v
                      ? const MIcon(MIconType.check, color: C.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, v),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (chosen != null) await _saveVoice(chosen);
  }

  Future<void> _pickTime() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        title: const Text('Время напоминания'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 24,
            itemBuilder: (_, i) {
              return ListTile(
                title: Text('${i.toString().padLeft(2, '0')}:00'),
                trailing: _timeHour == i
                    ? const MIcon(MIconType.check, color: C.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, i),
              );
            },
          ),
        ),
      ),
    );
    if (chosen != null) await _saveHour(chosen);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.l)),
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Данные будут удалены безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: C.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await Db.instance.deleteAccount();
    if (!mounted) return;
    if (success) {
      await AuthService.instance.signOut();
      if (mounted) context.go('/onboarding');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить аккаунт. Попробуйте позже.')),
      );
    }
  }

  String get _timeLabel => '${_timeHour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBg(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(S.s, 0, S.m, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: MIcon(MIconType.arrowBack, color: context.cText),
                    tooltip: 'Назад',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Настройки',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
                children: [
                  _SectionTitle(title: 'Тема')
                      .animate()
                      .fadeIn(duration: Anim.normal),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, mode, _) {
                      return GlassCard(
                        padding: EdgeInsets.zero,
                        semanticLabel: 'Выбор темы приложения',
                        child: Column(
                          children: [
                            _ThemeTile(
                              label: 'Системная',
                              icon: MIconType.settings,
                              selected: mode == ThemeMode.system,
                              onTap: () => setThemeMode(ThemeMode.system),
                            ),
                            Divider(height: 1, color: context.cSurfaceBorder),
                            _ThemeTile(
                              label: 'Светлая',
                              icon: MIconType.eco,
                              selected: mode == ThemeMode.light,
                              onTap: () => setThemeMode(ThemeMode.light),
                            ),
                            Divider(height: 1, color: context.cSurfaceBorder),
                            _ThemeTile(
                              label: 'Тёмная',
                              icon: MIconType.moon,
                              selected: mode == ThemeMode.dark,
                              onTap: () => setThemeMode(ThemeMode.dark),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: Anim.normal)
                      .slideY(begin: 0.04, end: 0, duration: Anim.normal, curve: Anim.curve),

                  const SizedBox(height: S.l),

                  _SectionTitle(title: 'Практика')
                      .animate()
                      .fadeIn(duration: Anim.normal),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    semanticLabel: 'Секция настроек практики',
                    child: Column(
                      children: [
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.timer,
                                color: Colors.white),
                          ),
                          title: const Text('Длительность'),
                          subtitle: Text(_duration.label,
                              style: TextStyle(color: context.cTextSec)),
                          trailing: MIcon(MIconType.chevronRight,
                              color: context.cTextDim),
                          onTap: _pickDuration,
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.air,
                                color: Colors.white),
                          ),
                          title: const Text('Голос'),
                          subtitle: Text(
                            switch (_voice) {
                              PreferredVoice.male => 'Мужской',
                              PreferredVoice.female => 'Женский',
                              PreferredVoice.any => 'Любой',
                            },
                            style: TextStyle(color: context.cTextSec),
                          ),
                          trailing: MIcon(MIconType.chevronRight,
                              color: context.cTextDim),
                          onTap: _pickVoice,
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.timer,
                                color: Colors.white),
                          ),
                          title: const Text('Время'),
                          subtitle: Text(_timeLabel,
                              style: TextStyle(color: context.cTextSec)),
                          trailing: MIcon(MIconType.chevronRight,
                              color: context.cTextDim),
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: Anim.normal)
                      .slideY(
                          begin: 0.04,
                          end: 0,
                          duration: Anim.normal,
                          curve: Anim.curve),

                  const SizedBox(height: S.l),

                  _SectionTitle(title: 'Уведомления')
                      .animate()
                      .fadeIn(delay: 40.ms, duration: Anim.normal),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    semanticLabel: 'Секция уведомлений',
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Напоминания о практике'),
                          value: _notifPractice,
                          activeThumbColor: C.primary,
                          activeTrackColor: C.primary.withValues(alpha: 0.45),
                          inactiveTrackColor: context.cSurfaceLight,
                          onChanged: (v) => _saveNotifPractice(v),
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        SwitchListTile(
                          title: const Text('Сообщения партнёра'),
                          value: _notifPartner,
                          activeThumbColor: C.primary,
                          activeTrackColor: C.primary.withValues(alpha: 0.45),
                          inactiveTrackColor: context.cSurfaceLight,
                          onChanged: (v) => _saveNotifPartner(v),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 60.ms, duration: Anim.normal)
                      .slideY(
                          begin: 0.04,
                          end: 0,
                          delay: 60.ms,
                          duration: Anim.normal,
                          curve: Anim.curve),

                  const SizedBox(height: S.l),

                  _SectionTitle(title: 'О приложении')
                      .animate()
                      .fadeIn(delay: 80.ms, duration: Anim.normal),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    semanticLabel: 'Секция о приложении',
                    child: Column(
                      children: [
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.insights,
                                color: Colors.white),
                          ),
                          title: const Text('Версия'),
                          subtitle: Text('1.0.0',
                              style: TextStyle(color: context.cTextSec)),
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.lock,
                                color: Colors.white),
                          ),
                          title: const Text('Конфиденциальность'),
                          trailing: MIcon(MIconType.arrowForward,
                              size: 20, color: context.cTextDim),
                          onTap: () =>
                              _openUrl('https://mymeditator.ru/privacy'),
                        ),
                        Divider(height: 1, color: context.cSurfaceBorder),
                        ListTile(
                          leading: ShaderMask(
                            shaderCallback: (b) =>
                                C.gradientPrimary.createShader(b),
                            child: const MIcon(MIconType.book,
                                color: Colors.white),
                          ),
                          title: const Text('Условия'),
                          trailing: MIcon(MIconType.arrowForward,
                              size: 20, color: context.cTextDim),
                          onTap: () =>
                              _openUrl('https://mymeditator.ru/terms'),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: Anim.normal)
                      .slideY(
                          begin: 0.04,
                          end: 0,
                          delay: 100.ms,
                          duration: Anim.normal,
                          curve: Anim.curve),

                  const SizedBox(height: S.l),

                  _SectionTitle(title: 'Аккаунт')
                      .animate()
                      .fadeIn(delay: 120.ms, duration: Anim.normal),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    onTap: _confirmDeleteAccount,
                    semanticLabel: 'Удалить аккаунт',
                    opacity: 0.06,
                    child: ListTile(
                      leading: MIcon(MIconType.delete,
                          color: C.error.withValues(alpha: 0.8)),
                      title: Text('Удалить аккаунт',
                          style: TextStyle(color: C.error)),
                      subtitle: Text(
                        'Безвозвратно удалить все данные',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: C.error.withValues(alpha: 0.6)),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 140.ms, duration: Anim.normal)
                      .slideY(
                          begin: 0.04,
                          end: 0,
                          delay: 140.ms,
                          duration: Anim.normal,
                          curve: Anim.curve),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: S.xs, bottom: S.s),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.cTextSec,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final MIconType icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ShaderMask(
        shaderCallback: (b) => C.gradientPrimary.createShader(b),
        child: MIcon(icon, color: Colors.white),
      ),
      title: Text(label),
      trailing: selected
          ? const MIcon(MIconType.check, color: C.accent)
          : null,
      onTap: onTap,
    );
  }
}
