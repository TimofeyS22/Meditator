import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/features/courses/courses_screen.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course? _course;
  int _lastCompletedDay = 0;

  @override
  void initState() {
    super.initState();
    for (final c in kSampleCourses) {
      if (c.id == widget.courseId) {
        _course = c;
        break;
      }
    }
    if (_course != null) _loadProgress();
  }

  Future<void> _loadProgress() async {
    final c = _course;
    if (c == null) return;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(Course.progressKey(c.id)) ?? 0;
    if (mounted) setState(() => _lastCompletedDay = v);
  }

  Future<void> _markProgress(int dayNumber) async {
    final c = _course;
    if (c == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = Course.progressKey(c.id);
    final current = prefs.getInt(key) ?? 0;
    if (dayNumber > current) {
      await prefs.setInt(key, dayNumber);
    }
    if (mounted) setState(() => _lastCompletedDay = prefs.getInt(key) ?? 0);
  }

  bool _canOpenLesson(int dayNumber) =>
      dayNumber <= _lastCompletedDay + 1;

  bool _isLessonDone(int dayNumber) => dayNumber <= _lastCompletedDay;

  CourseLesson? get _nextLesson {
    final c = _course;
    if (c == null) return null;
    for (final l in c.lessons) {
      if (l.dayNumber > _lastCompletedDay) return l;
    }
    return null;
  }

  double get _overallProgress {
    final c = _course;
    if (c == null || c.durationDays == 0) return 0;
    return (_lastCompletedDay / c.durationDays).clamp(0.0, 1.0);
  }

  Future<void> _startLesson(CourseLesson lesson) async {
    if (!_canOpenLesson(lesson.dayNumber)) return;
    HapticFeedback.mediumImpact();
    if (lesson.meditationId != null && lesson.meditationId!.isNotEmpty) {
      await context.push('/play?id=${Uri.encodeComponent(lesson.meditationId!)}');
    } else {
      await context.push('/timer');
    }
    if (!mounted) return;
    await _markProgress(lesson.dayNumber);
  }

  Future<void> _continueNext() async {
    final next = _nextLesson;
    if (next != null) await _startLesson(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = _course;
    final top = MediaQuery.paddingOf(context).top;

    if (c == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: GradientBg(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(S.l),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MIcon(MIconType.meditation, size: 48, color: context.cTextSec),
                  const SizedBox(height: S.m),
                  Text(
                    'Курс не найден',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.cText,
                        ),
                  ),
                  const SizedBox(height: S.s),
                  Text(
                    'Проверьте ссылку или выберите курс из списка.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.cTextSec,
                        ),
                  ),
                  const SizedBox(height: S.l),
                  GlowButton(
                    onPressed: () => context.pop(),
                    child: const Text('Назад'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final next = _nextLesson;
    final courseFinished = next == null && c.lessons.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBg(
          showAurora: true,
          intensity: 0.4,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _CourseHeader(
                  course: c,
                  topPadding: top,
                  progress: _overallProgress,
                  lastCompleted: _lastCompletedDay,
                  onBack: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                ),
              ),
              if (next != null || courseFinished)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(S.m, S.m, S.m, S.s),
                    child: next != null
                        ? GlowButton(
                            onPressed: _continueNext,
                            showGlow: true,
                            glowColor: c.color.withValues(alpha: 0.45),
                            width: double.infinity,
                            child: Text(
                              'Продолжить — день ${next.dayNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          )
                            .animate(key: ValueKey(next.dayNumber))
                            .fadeIn(duration: Anim.normal)
                            .shimmer(
                              delay: 400.ms,
                              duration: 1200.ms,
                              color: Colors.white24,
                            )
                        : GlassCard(
                            padding: const EdgeInsets.all(S.m),
                            showBorder: true,
                            borderGradientColors: [
                              c.color.withValues(alpha: 0.6),
                              C.accent.withValues(alpha: 0.5),
                            ],
                            child: Row(
                              children: [
                                Icon(Icons.celebration_rounded, color: c.color),
                                const SizedBox(width: S.m),
                                Expanded(
                                  child: Text(
                                    'Курс завершён! Вы прошли все дни.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: context.cText),
                                  ),
                                ),
                              ],
                            ),
                          )
                            .animate()
                            .fadeIn()
                            .scale(
                              begin: const Offset(0.96, 0.96),
                              end: const Offset(1, 1),
                              curve: Anim.curveGentle,
                            ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(S.m, S.s, S.m, S.xxl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = c.lessons[index];
                      final done = _isLessonDone(lesson.dayNumber);
                      final unlocked = _canOpenLesson(lesson.dayNumber);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: S.m),
                        child: _LessonTile(
                          lesson: lesson,
                          accent: c.color,
                          done: done,
                          unlocked: unlocked,
                          onTap: unlocked ? () => _startLesson(lesson) : null,
                        )
                            .animate()
                            .fadeIn(
                              delay: Anim.stagger * index,
                              duration: Anim.normal,
                              curve: Anim.curve,
                            )
                            .slideX(
                              begin: 0.04,
                              end: 0,
                              delay: Anim.stagger * index,
                              duration: Anim.normal,
                              curve: Anim.curve,
                            ),
                      );
                    },
                    childCount: c.lessons.length,
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

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({
    required this.course,
    required this.topPadding,
    required this.progress,
    required this.lastCompleted,
    required this.onBack,
  });

  final Course course;
  final double topPadding;
  final double progress;
  final int lastCompleted;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            course.color.withValues(alpha: 0.95),
            course.color.withValues(alpha: 0.45),
            C.primary.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(R.xl)),
        boxShadow: [
          BoxShadow(
            color: course.color.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(S.m, topPadding + S.s, S.m, S.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(S.s),
                  opacity: 0.14,
                  onTap: onBack,
                  child: MIcon(MIconType.arrowBack, size: 22, color: Colors.white),
                ),
                const Spacer(),
                if (course.isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(R.s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MIcon(MIconType.premium, size: 14, color: C.gold),
                        const SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: S.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(S.m),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(R.l),
                  ),
                  child: Icon(course.iconData, color: Colors.white, size: 36),
                ),
                const SizedBox(width: S.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: S.s),
                      Text(
                        course.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.l),
            Text(
              'Прогресс: $lastCompleted из ${course.durationDays} дней',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: S.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.accent,
    required this.done,
    required this.unlocked,
    required this.onTap,
  });

  final CourseLesson lesson;
  final Color accent;
  final bool done;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !unlocked;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(S.m),
        showBorder: true,
        glowColor: done ? C.ok.withValues(alpha: 0.25) : accent.withValues(alpha: 0.2),
        showGlow: unlocked,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: unlocked
                      ? [accent, accent.withValues(alpha: 0.55)]
                      : [context.cSurfaceLight, context.cSurfaceLight],
                ),
              ),
              child: Text(
                '${lesson.dayNumber}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: unlocked ? Colors.white : context.cTextDim,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: S.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.cText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lesson.durationMinutes} мин · ${lesson.meditationId != null ? 'С аудио' : 'Тихая практика'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.cTextSec,
                        ),
                  ),
                ],
              ),
            ),
            if (done)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: C.ok.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: C.ok, size: 22),
              )
            else if (locked)
              MIcon(MIconType.lock, size: 22, color: context.cTextDim)
            else
              MIcon(MIconType.chevronRight, size: 22, color: context.cTextSec),
          ],
        ),
      ),
    );
  }
}
