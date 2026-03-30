import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Урок внутри курса.
class CourseLesson {
  const CourseLesson({
    required this.dayNumber,
    required this.title,
    this.meditationId,
    required this.durationMinutes,
  });

  final int dayNumber;
  final String title;
  final String? meditationId;
  final int durationMinutes;
}

/// Курс медитации (7–21 день).
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.category,
    required this.color,
    required this.iconData,
    required this.lessons,
    this.isPremium = false,
  });

  final String id;
  final String title;
  final String description;
  final int durationDays;
  final String category;
  final Color color;
  final IconData iconData;
  final List<CourseLesson> lessons;
  final bool isPremium;

  /// Ключ SharedPreferences: число последнего полностью пройденного дня (1…N), 0 — не начат.
  static String progressKey(String courseId) => 'course_progress_$courseId';
}

/// Демо-курсы (общие для списка и экрана деталей).
final List<Course> kSampleCourses = _buildSampleCourses();

List<CourseLesson> _lessonsBasics() => const [
      CourseLesson(
        dayNumber: 1,
        title: 'Дыхание как опора',
        meditationId: 'course_basics_1',
        durationMinutes: 8,
      ),
      CourseLesson(
        dayNumber: 2,
        title: 'Тишина и внимание',
        meditationId: null,
        durationMinutes: 5,
      ),
      CourseLesson(
        dayNumber: 3,
        title: 'Скан тела',
        meditationId: 'course_basics_3',
        durationMinutes: 12,
      ),
      CourseLesson(
        dayNumber: 4,
        title: 'Звуки без оценки',
        meditationId: null,
        durationMinutes: 7,
      ),
      CourseLesson(
        dayNumber: 5,
        title: 'Мысли как облака',
        meditationId: 'course_basics_5',
        durationMinutes: 10,
      ),
      CourseLesson(
        dayNumber: 6,
        title: 'Доброта к себе',
        meditationId: null,
        durationMinutes: 8,
      ),
      CourseLesson(
        dayNumber: 7,
        title: 'Завершение недели',
        meditationId: 'course_basics_7',
        durationMinutes: 15,
      ),
    ];

List<CourseLesson> _lessonsAnxiety() => List<CourseLesson>.generate(
      14,
      (i) {
        final d = i + 1;
        final guided = d.isOdd;
        return CourseLesson(
          dayNumber: d,
          title: switch (d) {
            1 => 'Заземление при тревоге',
            2 => 'Дыхание 4-7-8',
            3 => 'Отпускание напряжения',
            4 => 'Тихая медитация',
            5 => 'Работа с телом',
            6 => 'Наблюдатель за мыслями',
            7 => 'Безопасное место',
            8 => 'Мягкое дыхание',
            9 => 'Принятие неопределённости',
            10 => 'Таймер тишины',
            11 => 'Короткая передышка',
            12 => 'Расширение комфорта',
            13 => 'Устойчивость',
            14 => 'Интеграция спокойствия',
            _ => 'День $d',
          },
          meditationId: guided ? 'course_anxiety_$d' : null,
          durationMinutes: 6 + (d % 5),
        );
      },
    );

List<CourseLesson> _lessonsSleep() => List<CourseLesson>.generate(
      21,
      (i) {
        final d = i + 1;
        final guided = d % 3 != 0;
        return CourseLesson(
          dayNumber: d,
          title: d <= 7
              ? 'Вечерний ритуал — фаза $d'
              : d <= 14
                  ? 'Глубокий отдых — неделя ${((d - 1) ~/ 7) + 1}, день ${((d - 1) % 7) + 1}'
                  : 'Сон и восстановление — день $d',
          meditationId: guided ? 'course_sleep_$d' : null,
          durationMinutes: 8 + (d % 7),
        );
      },
    );

List<CourseLesson> _lessonsMorning() => const [
      CourseLesson(
        dayNumber: 1,
        title: 'Мягкое пробуждение',
        meditationId: 'course_morning_1',
        durationMinutes: 6,
      ),
      CourseLesson(
        dayNumber: 2,
        title: 'Свет и намерение',
        meditationId: null,
        durationMinutes: 5,
      ),
      CourseLesson(
        dayNumber: 3,
        title: 'Энергия дыхания',
        meditationId: 'course_morning_3',
        durationMinutes: 8,
      ),
      CourseLesson(
        dayNumber: 4,
        title: 'Тишина перед днём',
        meditationId: null,
        durationMinutes: 5,
      ),
      CourseLesson(
        dayNumber: 5,
        title: 'Благодарность телу',
        meditationId: 'course_morning_5',
        durationMinutes: 7,
      ),
      CourseLesson(
        dayNumber: 6,
        title: 'Фокус на день',
        meditationId: null,
        durationMinutes: 6,
      ),
      CourseLesson(
        dayNumber: 7,
        title: 'Старт недели с ясностью',
        meditationId: 'course_morning_7',
        durationMinutes: 10,
      ),
    ];

List<CourseLesson> _lessonsSelfLove() => List<CourseLesson>.generate(
      14,
      (i) {
        final d = i + 1;
        return CourseLesson(
          dayNumber: d,
          title: switch (d) {
            1 => 'Нежное присутствие',
            2 => 'Тихая практика принятия',
            3 => 'Голос внутреннего друга',
            4 => 'Медитация без слов',
            5 => 'Тело достойно заботы',
            6 => 'Пространство для себя',
            7 => 'Полпути — пауза',
            8 => 'Прощение мелочей',
            9 => 'Тепло в ладонях',
            10 => 'Тишина поддержки',
            11 => 'Границы с любовью',
            12 => 'Мягкость к себе',
            13 => 'Сбор силы',
            14 => 'Объятие завершения',
            _ => 'День $d',
          },
          meditationId: d.isEven ? null : 'course_selflove_$d',
          durationMinutes: 7 + (d % 4),
        );
      },
    );

List<Course> _buildSampleCourses() => [
      Course(
        id: 'course_focus_basics',
        title: 'Основы медитации',
        description:
            'Освойте базовые техники осознанности и дыхания за семь дней.',
        durationDays: 7,
        category: 'focus',
        color: const Color(0xFF818CF8),
        iconData: Icons.self_improvement_rounded,
        lessons: _lessonsBasics(),
        isPremium: false,
      ),
      Course(
        id: 'course_anxiety_relief',
        title: 'Снижение тревоги',
        description:
            'Пошаговая программа для спокойствия и опоры на тело и дыхание.',
        durationDays: 14,
        category: 'anxiety',
        color: const Color(0xFF38BDF8),
        iconData: Icons.cloud_rounded,
        lessons: _lessonsAnxiety(),
        isPremium: false,
      ),
      Course(
        id: 'course_better_sleep',
        title: 'Лучший сон',
        description:
            'Три недели вечерних практик для глубокого отдыха и мягкого засыпания.',
        durationDays: 21,
        category: 'sleep',
        color: const Color(0xFF6366F1),
        iconData: Icons.bedtime_rounded,
        lessons: _lessonsSleep(),
        isPremium: true,
      ),
      Course(
        id: 'course_morning_energy',
        title: 'Утренняя энергия',
        description:
            'Бодрое и ясное начало дня без спешки — семь утренних сессий.',
        durationDays: 7,
        category: 'morning',
        color: const Color(0xFFFBBF24),
        iconData: Icons.wb_sunny_rounded,
        lessons: _lessonsMorning(),
        isPremium: false,
      ),
      Course(
        id: 'course_self_love',
        title: 'Любовь к себе',
        description:
            'Четырнадцать дней нежных ежедневных практик принятия и поддержки.',
        durationDays: 14,
        category: 'selfLove',
        color: const Color(0xFFFB7185),
        iconData: Icons.favorite_rounded,
        lessons: _lessonsSelfLove(),
        isPremium: true,
      ),
    ];

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final Map<String, int> _progressByCourse = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final next = <String, int>{};
    for (final c in kSampleCourses) {
      next[c.id] = prefs.getInt(Course.progressKey(c.id)) ?? 0;
    }
    if (mounted) setState(() => _progressByCourse..clear()..addAll(next));
  }

  Future<void> _openCourse(Course c) async {
    await context.push('/course?id=${c.id}');
    if (mounted) _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBg(
          showAurora: true,
          intensity: 0.45,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(S.m, top + S.m, S.m, S.s),
                  child: Row(
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(S.s),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        child: MIcon(
                          MIconType.arrowBack,
                          size: 22,
                          color: context.cText,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Курсы',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: context.cText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, S.xxl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: S.l),
                          child: Text(
                            'Структурированные программы на 7–21 день. Проходите в своём темпе.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.cTextSec,
                                  height: 1.45,
                                ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: Anim.normal, curve: Anim.curve)
                            .slideY(begin: 0.06, end: 0, curve: Anim.curve);
                      }
                      final c = kSampleCourses[index - 1];
                      final progress = _progressByCourse[c.id] ?? 0;
                      final frac = c.durationDays > 0
                          ? (progress / c.durationDays).clamp(0.0, 1.0)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: S.m),
                        child: _CourseCard(
                          course: c,
                          progressFraction: frac,
                          completedDays: progress,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openCourse(c);
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: Anim.stagger * index,
                              duration: Anim.normal,
                              curve: Anim.curve,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              delay: Anim.stagger * index,
                              duration: Anim.normal,
                              curve: Anim.curve,
                            ),
                      );
                    },
                    childCount: kSampleCourses.length + 1,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(S.m, S.l, S.m, S.xxl),
                  child: GlowButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/library');
                    },
                    showGlow: true,
                    glowColor: C.glowPrimary,
                    width: double.infinity,
                    child: const Text(
                      'Открыть библиотеку медитаций',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
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

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.progressFraction,
    required this.completedDays,
    required this.onTap,
  });

  final Course course;
  final double progressFraction;
  final int completedDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(S.m),
      showBorder: true,
      glowColor: course.color.withValues(alpha: 0.35),
      showGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      course.color.withValues(alpha: 0.9),
                      course.color.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(R.m),
                  boxShadow: [
                    BoxShadow(
                      color: course.color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(course.iconData, color: Colors.white, size: 26),
              ),
              const SizedBox(width: S.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.cText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (course.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: S.s,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: C.gradientGold,
                              borderRadius: BorderRadius.circular(R.s),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MIcon(MIconType.premium, size: 14, color: C.bg),
                                const SizedBox(width: 4),
                                Text(
                                  'Premium',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: C.bg,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.cTextSec,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.m),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: S.s, vertical: 4),
                decoration: BoxDecoration(
                  color: course.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(R.s),
                  border: Border.all(color: course.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${course.durationDays} дней',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: course.color.withValues(alpha: 1),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                '$completedDays / ${course.durationDays}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.cTextDim,
                    ),
              ),
            ],
          ),
          const SizedBox(height: S.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.full),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: context.cSurfaceLight.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(course.color),
            ),
          ),
        ],
      ),
    );
  }
}
