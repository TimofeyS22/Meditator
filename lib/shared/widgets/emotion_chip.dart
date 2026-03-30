import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/shared/utils/accessibility.dart';
import 'package:meditator/shared/widgets/sticker_icon.dart';

class EmotionChip extends StatefulWidget {
  const EmotionChip({
    super.key,
    required this.iconData,
    required this.iconColor,
    required this.label,
    required this.color,
    required this.isSelected,
    this.onTap,
  });

  final IconData iconData;
  final Color iconColor;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<EmotionChip> createState() => _EmotionChipState();
}

class _EmotionChipState extends State<EmotionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final CurvedAnimation _scaleCurve;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleCurve = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeIn,
      reverseCurve: Anim.curveGentle,
    );
  }

  @override
  void dispose() {
    _scaleCurve.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final semanticLabel = widget.label;
    final enabled = widget.onTap != null;
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    return ListenableBuilder(
      listenable: _scaleCurve,
      builder: (context, child) => Transform.scale(
        scale: reduceMotion ? 1.0 : 1.0 - 0.05 * _scaleCurve.value,
        child: child,
      ),
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        enabled: enabled,
        label: semanticLabel,
        child: Tooltip(
          message: widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _scaleCtrl.forward() : null,
            onTapUp: enabled ? (_) => _scaleCtrl.reverse() : null,
            onTapCancel: enabled ? () => _scaleCtrl.reverse() : null,
            onTap: enabled ? _onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Anim.curve,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.color.withValues(alpha: 0.15)
                    : context.cSurfaceLight,
                borderRadius: BorderRadius.circular(R.xl),
                border: Border.all(
                  color: widget.isSelected
                      ? widget.color.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minHeight: S.minTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: S.m, vertical: S.s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StickerIcon(
                    icon: widget.iconData,
                    color: widget.iconColor,
                    size: 20,
                    showBackground: false,
                  ),
                  const SizedBox(width: S.s),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  AnimatedSize(
                    duration: Anim.fast,
                    curve: Anim.curve,
                    child: widget.isSelected
                        ? Padding(
                            padding: const EdgeInsets.only(left: S.xs),
                            child: Icon(
                              Icons.check_circle,
                              color: widget.color,
                              size: 18,
                            ),
                          )
                        : const SizedBox.shrink(),
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
