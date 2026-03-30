import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditator/app/shell.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/features/auth/login_screen.dart';
import 'package:meditator/features/onboarding/onboarding_screen.dart';
import 'package:meditator/features/home/home_screen.dart';
import 'package:meditator/features/meditation/ai_player_screen.dart';
import 'package:meditator/features/meditation/meditation_player_screen.dart';
import 'package:meditator/features/meditation/library_screen.dart';
import 'package:meditator/features/ai_companion/aura_screen.dart';
import 'package:meditator/features/mood_journal/journal_screen.dart';
import 'package:meditator/features/mood_journal/new_entry_screen.dart';
import 'package:meditator/features/mood_journal/analytics_screen.dart';
import 'package:meditator/features/garden/garden_screen.dart';
import 'package:meditator/features/breathing/breathing_list_screen.dart';
import 'package:meditator/features/breathing/breathing_session_screen.dart';
import 'package:meditator/features/interventions/micro_intervention_screen.dart';
import 'package:meditator/features/pair/pair_screen.dart';
import 'package:meditator/features/pair/find_partner_screen.dart';
import 'package:meditator/features/pair/live_session_screen.dart';
import 'package:meditator/features/insights/aura_insights_screen.dart';
import 'package:meditator/features/consciousness_map/consciousness_map_screen.dart';
import 'package:meditator/features/sound_lab/sound_lab_screen.dart';
import 'package:meditator/features/profile/profile_screen.dart';
import 'package:meditator/features/profile/settings_screen.dart';
import 'package:meditator/features/splash/splash_screen.dart';
import 'package:meditator/features/meditation/timer_screen.dart';
import 'package:meditator/features/downloads/downloads_screen.dart';
import 'package:meditator/features/sleep_stories/sleep_stories_screen.dart';
import 'package:meditator/features/courses/courses_screen.dart';
import 'package:meditator/features/courses/course_detail_screen.dart';
import 'package:meditator/features/community/community_screen.dart';
import 'package:meditator/features/subscription/paywall_screen.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

final _root = GlobalKey<NavigatorState>();
final _shell = GlobalKey<NavigatorState>();

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = AuthService.instance.onAuthChange.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

final appRouter = GoRouter(
  navigatorKey: _root,
  initialLocation: '/splash',
  refreshListenable: _authNotifier,
  redirect: (context, state) async {
    final loggedIn = AuthService.instance.currentUser != null;
    final path = state.uri.path;

    if (path == '/splash') return null;

    // Legacy path redirects
    if (path == '/home') return '/practice';
    if (path == '/profile') return '/you';

    final isAuthPage = path == '/onboarding' || path == '/login';

    if (isAuthPage && loggedIn) return '/practice';
    if (isAuthPage && !loggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') == true;
      if (done && path != '/login') return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, _) => const CustomTransitionPage(
        child: SplashScreen(),
        transitionsBuilder: _fadeTransition,
        transitionDuration: Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, _) => CustomTransitionPage(
        child: const OnboardingScreen(),
        transitionsBuilder: _fadeTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (_, _) => CustomTransitionPage(
        child: const LoginScreen(),
        transitionsBuilder: _fadeTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),

    // 3-tab shell: Practice, Journal, You
    ShellRoute(
      navigatorKey: _shell,
      builder: (_, _, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/practice',
          pageBuilder: (_, state) => _tabPage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/journal',
          pageBuilder: (_, state) => _tabPage(state, const JournalScreen()),
        ),
        GoRoute(
          path: '/you',
          pageBuilder: (_, state) => _tabPage(state, const ProfileScreen()),
        ),
      ],
    ),

    // Immersive / push routes
    GoRoute(
      path: '/play',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(
        state,
        MeditationPlayerScreen(meditationId: state.uri.queryParameters['id']),
      ),
    ),
    GoRoute(
      path: '/ai-play',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) {
        final dur = int.tryParse(state.uri.queryParameters['duration'] ?? '') ?? 10;
        final mood = state.uri.queryParameters['mood'];
        return _immersivePage(state, AiPlayerScreen(durationMinutes: dur, moodOverride: mood));
      },
    ),
    GoRoute(
      path: '/library',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const LibraryScreen()),
    ),
    GoRoute(
      path: '/timer',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(state, const TimerScreen()),
    ),
    GoRoute(
      path: '/aura',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const AuraScreen()),
    ),
    GoRoute(
      path: '/journal/new',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const NewEntryScreen()),
    ),
    GoRoute(
      path: '/journal/analytics',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const AnalyticsScreen()),
    ),
    GoRoute(
      path: '/breathing',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const BreathingListScreen()),
    ),
    GoRoute(
      path: '/breathe',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(
        state,
        BreathingSessionScreen(
          exerciseId: state.uri.queryParameters['id'] ?? 'box',
        ),
      ),
    ),
    GoRoute(
      path: '/micro',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(
        state,
        MicroInterventionScreen(type: state.uri.queryParameters['type'] ?? 'breathing'),
      ),
    ),
    GoRoute(
      path: '/garden',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const GardenScreen()),
    ),
    GoRoute(
      path: '/pair',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const PairScreen()),
    ),
    GoRoute(
      path: '/pair/find',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const FindPartnerScreen()),
    ),
    GoRoute(
      path: '/pair/live',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(state, const LiveSessionScreen()),
    ),
    GoRoute(
      path: '/insights',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const AuraInsightsScreen()),
    ),
    GoRoute(
      path: '/consciousness-map',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const ConsciousnessMapScreen()),
    ),
    GoRoute(
      path: '/sound-lab',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _immersivePage(state, const SoundLabScreen()),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _modalPage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/downloads',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const DownloadsScreen()),
    ),
    GoRoute(
      path: '/sleep-stories',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const SleepStoriesScreen()),
    ),
    GoRoute(
      path: '/courses',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const CoursesScreen()),
    ),
    GoRoute(
      path: '/course',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(
        state,
        CourseDetailScreen(courseId: state.uri.queryParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/community',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const CommunityScreen()),
    ),
    GoRoute(
      path: '/paywall',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _modalPage(state, const PaywallScreen()),
    ),
  ],
);

CustomTransitionPage _tabPage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final d = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: d,
    reverseTransitionDuration: d,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Anim.curve),
        child: child,
      );
    },
  );
}

CustomTransitionPage _pushPage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final duration = reduceMotion ? Duration.zero : Anim.pageTransition;
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Anim.curveDramatic);
      final secondaryCurved = CurvedAnimation(parent: secondaryAnimation, curve: Anim.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: reduceMotion ? Offset.zero : const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.96).animate(secondaryCurved),
            child: child,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage _immersivePage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 550);
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Anim.curveDramatic);
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
        ),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: reduceMotion ? 1.0 : 0.88,
            end: 1.0,
          ).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: reduceMotion ? Offset.zero : const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage _modalPage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 400);
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: false,
    barrierColor: Colors.black26,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Anim.curveDramatic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: reduceMotion ? Offset.zero : const Offset(0, 0.20),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

bool get _reduceMotionEnabled {
  final context = _root.currentContext ?? _shell.currentContext;
  if (context == null) return false;
  return AccessibilityUtils.reduceMotion(context);
}
