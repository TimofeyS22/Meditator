import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/connectivity_banner.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorCtrl;

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  int _idx(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).uri.path;
    if (loc.startsWith('/journal')) return 1;
    if (loc.startsWith('/you')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int target) {
    final current = _idx(context);
    if (current == target) return;
    HapticFeedback.selectionClick();
    const paths = ['/practice', '/journal', '/you'];
    context.go(paths[target]);
  }

  @override
  Widget build(BuildContext context) {
    final i = _idx(context);

    return Scaffold(
      body: Stack(
        children: [
          ConnectivityBanner(child: widget.child),
          Positioned(
            left: S.m,
            right: S.m,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: S.m),
                child: _NavBar(
                  currentIndex: i,
                  onTap: (idx) => _onTap(context, idx),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _icons = [
    Icons.self_improvement_rounded,
    Icons.book_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Практика', 'Журнал', 'Ты'];
  static const double _h = 56;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.full),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(R.full),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: _NavItem(
                    icon: _icons[i],
                    label: _labels[i],
                    active: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    final dur = reduceMotion ? Duration.zero : Anim.fast;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final activeColor = isLight ? C.primary : Colors.white;
    final inactiveColor = context.cTextDim;

    return Semantics(
      button: true,
      selected: active,
      label: '$label, вкладка',
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: dur,
              curve: Anim.curve,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.full),
                color: active
                    ? (isLight
                        ? C.primary.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.1))
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: dur,
                    child: Icon(
                      icon,
                      key: ValueKey('${icon.hashCode}_$active'),
                      size: 22,
                      color: active ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? activeColor : inactiveColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
