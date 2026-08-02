import 'dart:math' as math;

import 'package:flutter/material.dart';

class QuestionCardStack extends StatelessWidget {
  const QuestionCardStack({
    super.key,
    required this.count,
    required this.color,
    this.maxVisible = 5,
  });

  final int count;
  final Color color;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = math.min(count, maxVisible);
    if (visible == 0) return const SizedBox(height: 62);
    return SizedBox(
      height: 72,
      width: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              top: (visible - i - 1) * 5,
              left: (visible - i - 1) * 4,
              child: Transform.rotate(
                angle: (i - visible / 2) * .012,
                child: Container(
                  width: 102,
                  height: 54,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == visible - 1
                          ? color
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .09),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: 72,
                        height: 4,
                        color: color.withValues(alpha: .18),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 56,
                        height: 4,
                        color: color.withValues(alpha: .12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
