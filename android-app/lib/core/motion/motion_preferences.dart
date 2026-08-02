import 'package:flutter/material.dart';

import '../../app/app_settings_controller.dart';

@immutable
class MotionPreferences {
  const MotionPreferences({
    required this.reduceMotion,
    required this.lowPerformance,
    required this.hapticsEnabled,
    required this.soundEnabled,
  });

  final bool reduceMotion;
  final bool lowPerformance;
  final bool hapticsEnabled;
  final bool soundEnabled;

  bool get allowSpatialMotion => !reduceMotion;
  bool get allowContinuousEffects => !reduceMotion && !lowPerformance;
  bool get allowBlur => !reduceMotion && !lowPerformance;

  factory MotionPreferences.of(
    BuildContext context, {
    bool simulateLowPerformance = false,
  }) {
    final settings = AppSettingsScope.maybeOf(context);
    final media = MediaQuery.maybeOf(context);
    return MotionPreferences(
      reduceMotion:
          (settings?.reduceMotion ?? false) ||
          (media?.disableAnimations ?? false),
      lowPerformance: simulateLowPerformance,
      hapticsEnabled: settings?.hapticsEnabled ?? true,
      soundEnabled: settings?.soundEnabled ?? true,
    );
  }
}
