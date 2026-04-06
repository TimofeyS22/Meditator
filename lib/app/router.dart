import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/features/splash/splash_screen.dart';
import 'package:meditator/features/onboarding/onboarding_flow.dart';
import 'package:meditator/features/home/home_screen.dart';
import 'package:meditator/features/session/session_screen.dart';
import 'package:meditator/features/profile/profile_screen.dart';
import 'package:meditator/features/paywall/paywall_screen.dart';
import 'package:meditator/features/reality_break/reality_break_screen.dart';
import 'package:meditator/features/timeline/timeline_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      if (path == '/onboarding' && auth.isOnboarded) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: SplashScreen(),
          transitionsBuilder: _slowFade,
          transitionDuration: Duration(milliseconds: 1200),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: OnboardingFlow(),
          transitionsBuilder: _slowFade,
          transitionDuration: Duration(milliseconds: 1200),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: HomeScreen(),
          transitionsBuilder: _slowFade,
          transitionDuration: Duration(milliseconds: 1200),
        ),
      ),
      GoRoute(
        path: '/session',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, state) => CustomTransitionPage(
          child: SessionScreen(
            type: state.uri.queryParameters['type'] ?? 'deepen',
            durationSeconds:
                int.tryParse(state.uri.queryParameters['duration'] ?? '') ?? 60,
          ),
          transitionsBuilder: _scaleUp,
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ),
      GoRoute(
        path: '/reality-break',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, __) => CustomTransitionPage(
          child: const RealityBreakScreen(),
          transitionsBuilder: _instantDim,
          transitionDuration: const Duration(milliseconds: 200),
        ),
      ),
      GoRoute(
        path: '/timeline',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: TimelineScreen(),
          transitionsBuilder: _slideUp,
          transitionDuration: Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: ProfileScreen(),
          transitionsBuilder: _slideUp,
          transitionDuration: Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: '/paywall',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, __) => const CustomTransitionPage(
          child: PaywallScreen(),
          transitionsBuilder: _slideUp,
          transitionDuration: Duration(milliseconds: 400),
        ),
      ),
    ],
  );
});

Widget _slowFade(_, Animation<double> a, __, Widget child) {
  final curved = CurvedAnimation(
    parent: a, curve: const Cubic(0.4, 0.0, 0.2, 1.0),
  );
  return FadeTransition(opacity: curved, child: child);
}

Widget _fade(_, Animation<double> a, __, Widget child) =>
    FadeTransition(opacity: a, child: child);

Widget _scaleUp(_, Animation<double> a, __, Widget child) {
  final c = CurvedAnimation(parent: a, curve: const Cubic(0.16, 1, 0.3, 1));
  return FadeTransition(
    opacity: c,
    child: ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.0).animate(c),
      child: child,
    ),
  );
}

Widget _slideUp(_, Animation<double> a, __, Widget child) {
  final c = CurvedAnimation(parent: a, curve: const Cubic(0.16, 1, 0.3, 1));
  return FadeTransition(
    opacity: c,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c),
      child: child,
    ),
  );
}

Widget _instantDim(_, Animation<double> a, __, Widget child) =>
    FadeTransition(opacity: a, child: child);
