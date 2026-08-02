import 'package:flutter/animation.dart';

class StaggeredSequence {
  const StaggeredSequence._();

  static Animation<double> item(
    Animation<double> parent, {
    required int index,
    required int count,
    double overlap = .58,
    Curve curve = Curves.easeOutCubic,
  }) {
    final safeCount = count < 1 ? 1 : count;
    final segment = 1 / (safeCount + (safeCount - 1) * overlap);
    final start = index * segment * overlap;
    final end = (start + segment).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: curve),
    );
  }
}
