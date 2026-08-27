import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A low-cost ambient layer for important surfaces.
///
/// It uses only transforms and opacity, ignores pointer events, and becomes a
/// static composition when Reduce Motion is enabled.
class AmbientMotionLayer extends StatefulWidget {
  const AmbientMotionLayer({
    super.key,
    required this.reduceMotion,
    this.primary = const Color(0xFF93C5FD),
    this.secondary = const Color(0xFFC4B5FD),
  });

  final bool reduceMotion;
  final Color primary;
  final Color secondary;

  @override
  State<AmbientMotionLayer> createState() => _AmbientMotionLayerState();
}

class _AmbientMotionLayerState extends State<AmbientMotionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant AmbientMotionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) _syncMotion();
  }

  void _syncMotion() {
    if (widget.reduceMotion) {
      _controller.stop();
      _controller.value = 0.18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value * math.pi * 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -42 + math.sin(phase) * 10,
                top: -48 + math.cos(phase) * 8,
                child: _AmbientOrb(
                  size: 178,
                  color: widget.primary.withValues(alpha: 0.17),
                ),
              ),
              Positioned(
                left: -54 + math.cos(phase * 0.8) * 8,
                bottom: -72 + math.sin(phase * 0.8) * 10,
                child: _AmbientOrb(
                  size: 166,
                  color: widget.secondary.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                right: 44 + math.cos(phase * 1.2) * 5,
                bottom: 26 + math.sin(phase * 1.2) * 5,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.48),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primary.withValues(alpha: 0.32),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
