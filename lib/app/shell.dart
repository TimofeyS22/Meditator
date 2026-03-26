import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/utils/spring_utils.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _prevIdx = 0;

  int _idx(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).uri.path;
    if (loc.startsWith('/garden')) return 1;
    if (loc.startsWith('/breathing')) return 2;
    if (loc.startsWith('/journal')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int target) {
    final current = _idx(context);
    if (current == target) return;
    HapticFeedback.selectionClick();
    const paths = ['/home', '/garden', '/breathing', '/journal', '/profile'];
    context.go(paths[target]);
  }

  @override
  Widget build(BuildContext context) {
    final i = _idx(context);
    final changed = i != _prevIdx;
    _prevIdx = i;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0x0FFFFFFF),
              border: Border(
                top: BorderSide(color: C.surfaceBorder, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavTab(
                      iconType: NavIconType.home,
                      label: 'Главная',
                      active: i == 0,
                      justActivated: changed && i == 0,
                      onTap: () => _onTap(context, 0),
                    ),
                    _NavTab(
                      iconType: NavIconType.garden,
                      label: 'Сад',
                      active: i == 1,
                      justActivated: changed && i == 1,
                      onTap: () => _onTap(context, 1),
                    ),
                    _NavTab(
                      iconType: NavIconType.breathing,
                      label: 'Дыхание',
                      active: i == 2,
                      justActivated: changed && i == 2,
                      onTap: () => _onTap(context, 2),
                    ),
                    _NavTab(
                      iconType: NavIconType.journal,
                      label: 'Журнал',
                      active: i == 3,
                      justActivated: changed && i == 3,
                      onTap: () => _onTap(context, 3),
                    ),
                    _NavTab(
                      iconType: NavIconType.profile,
                      label: 'Профиль',
                      active: i == 4,
                      justActivated: changed && i == 4,
                      onTap: () => _onTap(context, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatefulWidget {
  final NavIconType iconType;
  final String label;
  final bool active;
  final bool justActivated;
  final VoidCallback onTap;
  const _NavTab({
    required this.iconType,
    required this.label,
    required this.active,
    required this.justActivated,
    required this.onTap,
  });

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      lowerBound: 1.0,
      upperBound: 1.15,
    );
  }

  @override
  void didUpdateWidget(covariant _NavTab old) {
    super.didUpdateWidget(old);
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (reduceMotion) return;
    if (widget.justActivated && !old.active) {
      _scaleCtrl.stop();
      _scaleCtrl.value = 1.0;
      _scaleCtrl
          .animateWith(
            SpringSimulation(SpringUtils.gentle, 1.0, 1.15, 0.0),
          )
          .then((_) {
            if (!mounted) return;
            _scaleCtrl.animateWith(
              SpringSimulation(SpringUtils.gentle, 1.15, 1.0, 0.0),
            );
          });
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final semanticLabel = '${widget.label}, вкладка';

    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: AnimatedBuilder(
              animation: _scaleCtrl,
              builder: (context, child) => Transform.scale(
                scale: active ? _scaleCtrl.value : 1.0,
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIcon(active),
                  const SizedBox(height: 3),
                  _buildLabel(active),
                  const SizedBox(height: 3),
                  _buildGlowDot(active),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool active) {
    final icon = CustomNavIcon(
      type: widget.iconType,
      size: 22,
      color: active ? Colors.white : C.textDim,
    );
    if (!active) return icon;
    return ShaderMask(
      shaderCallback: (bounds) => C.gradientPrimary.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: icon,
    );
  }

  Widget _buildLabel(bool active) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      color: active ? Colors.white : C.textDim,
    );

    if (!active) return Text(widget.label, style: style);

    return ShaderMask(
      shaderCallback: (bounds) => C.gradientPrimary.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(widget.label, style: style),
    );
  }

  Widget _buildGlowDot(bool active) {
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    return AnimatedScale(
      scale: active ? 1.0 : 0.0,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.0,
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: C.gradientPrimary,
            boxShadow: [
              BoxShadow(color: C.glowPrimary, blurRadius: 6, spreadRadius: 1),
            ],
          ),
        ),
      ),
    );
  }
}
