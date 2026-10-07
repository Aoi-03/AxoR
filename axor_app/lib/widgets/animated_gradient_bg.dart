import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Animated mesh-gradient background
/// Creates a subtle, slowly-moving gradient effect behind content
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final double intensity;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.intensity = 0.15,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        [
          AppColors.primary.withAlpha((widget.intensity * 255).toInt()),
          AppColors.secondary.withAlpha((widget.intensity * 255).toInt()),
          AppColors.accent.withAlpha((widget.intensity * 100).toInt()),
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
          ),
          child: Stack(
            children: [
              // Animated gradient orbs
              Positioned(
                top: -100 + math.sin(value) * 50,
                right: -80 + math.cos(value * 0.7) * 40,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors[0],
                        colors[0].withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -120 + math.cos(value * 0.8) * 60,
                left: -100 + math.sin(value * 0.5) * 30,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors[1],
                        colors[1].withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
              if (colors.length > 2)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4 +
                      math.sin(value * 0.6) * 30,
                  left: MediaQuery.of(context).size.width * 0.3 +
                      math.cos(value * 0.9) * 20,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors[2],
                          colors[2].withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              // Content
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
