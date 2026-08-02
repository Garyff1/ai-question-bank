import 'package:flutter/material.dart';

@immutable
class MotionPerformancePolicy {
  const MotionPerformancePolicy({
    required this.blurEnabled,
    required this.particlesEnabled,
    required this.maxMovingObjects,
    required this.shadowLayers,
  });

  final bool blurEnabled;
  final bool particlesEnabled;
  final int maxMovingObjects;
  final int shadowLayers;

  factory MotionPerformancePolicy.resolve({
    required bool reduceMotion,
    required bool lowPerformance,
  }) {
    if (reduceMotion) {
      return const MotionPerformancePolicy(
        blurEnabled: false,
        particlesEnabled: false,
        maxMovingObjects: 1,
        shadowLayers: 0,
      );
    }
    if (lowPerformance) {
      return const MotionPerformancePolicy(
        blurEnabled: false,
        particlesEnabled: false,
        maxMovingObjects: 4,
        shadowLayers: 1,
      );
    }
    return const MotionPerformancePolicy(
      blurEnabled: true,
      particlesEnabled: true,
      maxMovingObjects: 10,
      shadowLayers: 2,
    );
  }
}
