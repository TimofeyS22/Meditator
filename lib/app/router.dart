import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditator/app/shell.dart';
import 'package:meditator/features/onboarding/onboarding_screen.dart';
import 'package:meditator/features/home/home_screen.dart';
import 'package:meditator/features/meditation/meditation_player_screen.dart';
import 'package:meditator/features/meditation/library_screen.dart';
import 'package:meditator/features/ai_companion/aura_screen.dart';
import 'package:meditator/features/mood_journal/journal_screen.dart';
import 'package:meditator/features/mood_journal/new_entry_screen.dart';
import 'package:meditator/features/mood_journal/analytics_screen.dart';
import 'package:meditator/features/garden/garden_screen.dart';
import 'package:meditator/features/breathing/breathing_list_screen.dart';
import 'package:meditator/features/breathing/breathing_session_screen.dart';
import 'package:meditator/features/pair/pair_screen.dart';
import 'package:meditator/features/pair/find_partner_screen.dart';
import 'package:meditator/features/profile/profile_screen.dart';
import 'package:meditator/features/profile/settings_screen.dart';
import 'package:meditator/features/subscription/paywall_screen.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';

final _root = GlobalKey<NavigatorState>();
final _shell = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _root,
  initialLocation: '/onboarding',
  redirect: (context, state) async {
    if (state.uri.path == '/onboarding') {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('onboarding_done') == true) return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      pageBuilder: (_, __) => CustomTransitionPage(
        child: const OnboardingScreen(),
        transitionsBuilder: _fadeTransition,
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),

    ShellRoute(
      navigatorKey: _shell,
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) => _tabPage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/garden',
          pageBuilder: (_, state) => _tabPage(state, const GardenScreen()),
        ),
        GoRoute(
          path: '/breathing',
          pageBuilder: (_, state) => _tabPage(state, const BreathingListScreen()),
        ),
        GoRoute(
          path: '/journal',
          pageBuilder: (_, state) => _tabPage(state, const JournalScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => _tabPage(state, const ProfileScreen()),
        ),
      ],
    ),

    GoRoute(
      path: '/play',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) {
        final reduceMotion = _reduceMotionEnabled;
        final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 500);
        return CustomTransitionPage(
          key: state.pageKey,
          child: MeditationPlayerScreen(
            meditationId: state.uri.queryParameters['id'],
          ),
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Anim.curve);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: reduceMotion ? 1.0 : 0.92,
                  end: 1.0,
                ).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: reduceMotion ? Offset.zero : const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/library',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _pushPage(state, const LibraryScreen()),
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
      path: '/breathe',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) {
        final reduceMotion = _reduceMotionEnabled;
        final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 500);
        return CustomTransitionPage(
          key: state.pageKey,
          child: BreathingSessionScreen(
            exerciseId: state.uri.queryParameters['id'] ?? 'box',
          ),
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Anim.curve);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: reduceMotion ? 1.0 : 0.92,
                  end: 1.0,
                ).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: reduceMotion ? Offset.zero : const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
      },
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
      path: '/settings',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _modalPage(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/paywall',
      parentNavigatorKey: _root,
      pageBuilder: (_, state) => _modalPage(state, const PaywallScreen()),
    ),
  ],
);

// Tab-to-tab: crossfade 300ms
CustomTransitionPage _tabPage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final d = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: d,
    reverseTransitionDuration: d,
    transitionsBuilder: _fadeTransition,
  );
}

// Push screens: slide up 8% + fade, 350ms, easeOutCubic
CustomTransitionPage _pushPage(GoRouterState state, Widget child) {
  final reduceMotion = _reduceMotionEnabled;
  final duration = reduceMotion ? Duration.zero : Anim.normal;
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Anim.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: reduceMotion ? Offset.zero : const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// Modal screens: slide from bottom 20% + fade + dimmed barrier, 400ms
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
      final curved = CurvedAnimation(parent: animation, curve: Anim.curve);
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
