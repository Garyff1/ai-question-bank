import 'package:flutter/material.dart';

/// Knowledge Forge 的统一动效节奏。业务页面只引用这些 token，避免各自写死。
abstract final class AppMotionTokens {
  static const micro = Duration(milliseconds: 150);
  static const selection = Duration(milliseconds: 190);
  static const page = Duration(milliseconds: 340);
  static const panel = Duration(milliseconds: 380);
  static const sharedElement = Duration(milliseconds: 580);
  static const forge = Duration(milliseconds: 820);
  static const binding = Duration(milliseconds: 900);
  static const reduced = Duration(milliseconds: 140);

  static const entranceInterval = 0.12;
  static const maxStrongTransition = Duration(milliseconds: 1000);

  static Duration resolve({
    required bool reduceMotion,
    required Duration regular,
  }) => reduceMotion ? reduced : regular;
}

@immutable
class MotionSemanticColors extends ThemeExtension<MotionSemanticColors> {
  const MotionSemanticColors({
    required this.byokGlow,
    required this.providerGlow,
    required this.forgeCore,
    required this.successGlow,
    required this.warningGlow,
  });

  final Color byokGlow;
  final Color providerGlow;
  final Color forgeCore;
  final Color successGlow;
  final Color warningGlow;

  factory MotionSemanticColors.from(ColorScheme scheme) => MotionSemanticColors(
    byokGlow: scheme.tertiary,
    providerGlow: scheme.primary,
    forgeCore: Color.lerp(scheme.primary, scheme.tertiary, .45)!,
    successGlow: const Color(0xFF10B981),
    warningGlow: const Color(0xFFF59E0B),
  );

  @override
  MotionSemanticColors copyWith({
    Color? byokGlow,
    Color? providerGlow,
    Color? forgeCore,
    Color? successGlow,
    Color? warningGlow,
  }) => MotionSemanticColors(
    byokGlow: byokGlow ?? this.byokGlow,
    providerGlow: providerGlow ?? this.providerGlow,
    forgeCore: forgeCore ?? this.forgeCore,
    successGlow: successGlow ?? this.successGlow,
    warningGlow: warningGlow ?? this.warningGlow,
  );

  @override
  MotionSemanticColors lerp(
    covariant ThemeExtension<MotionSemanticColors>? other,
    double t,
  ) {
    if (other is! MotionSemanticColors) return this;
    return MotionSemanticColors(
      byokGlow: Color.lerp(byokGlow, other.byokGlow, t)!,
      providerGlow: Color.lerp(providerGlow, other.providerGlow, t)!,
      forgeCore: Color.lerp(forgeCore, other.forgeCore, t)!,
      successGlow: Color.lerp(successGlow, other.successGlow, t)!,
      warningGlow: Color.lerp(warningGlow, other.warningGlow, t)!,
    );
  }
}
