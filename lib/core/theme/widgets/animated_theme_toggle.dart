import 'dart:math' as math;
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An interactive toggle button with a smooth Sun <-> Moon morphing animation
/// (180-degree rotation, scale bounce, and color transition) that switches
/// between Light and Dark themes via [AdaptiveTheme].
class AnimatedThemeToggle extends StatefulWidget {
  final double size;
  final Duration duration;

  const AnimatedThemeToggle({
    super.key,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  State<AnimatedThemeToggle> createState() => _AnimatedThemeToggleState();
}

class _AnimatedThemeToggleState extends State<AnimatedThemeToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubicEmphasized,
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = AdaptiveTheme.of(context).brightness == Brightness.dark;
    if (isDark && _controller.value == 0.0) {
      _controller.value = 1.0;
    } else if (!isDark && _controller.value == 1.0) {
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleToggle() {
    HapticFeedback.selectionClick();
    final isDark = AdaptiveTheme.of(context).brightness == Brightness.dark;

    if (isDark) {
      _controller.reverse();
      AdaptiveTheme.of(context).setLight();
    } else {
      _controller.forward();
      AdaptiveTheme.of(context).setDark();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptiveThemeMode>(
      valueListenable: AdaptiveTheme.of(context).modeChangeNotifier,
      builder: (context, mode, child) {
        final isDark = AdaptiveTheme.of(context).brightness == Brightness.dark;

        return Semantics(
          label: isDark ? 'Switch to light theme' : 'Switch to dark theme',
          button: true,
          child: Tooltip(
            message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: IconButton(
              iconSize: widget.size,
              onPressed: _handleToggle,
              icon: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * math.pi,
                      child: isDark
                          ? const Icon(
                              Icons.dark_mode_rounded,
                              color: Color(0xFF818CF8), // Soft indigo moon
                            )
                          : const Icon(
                              Icons.light_mode_rounded,
                              color: Color(0xFFF59E0B), // Warm amber sun
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
