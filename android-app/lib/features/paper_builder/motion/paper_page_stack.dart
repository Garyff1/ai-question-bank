import 'package:flutter/material.dart';

class PaperPageStack extends StatelessWidget {
  const PaperPageStack({
    super.key,
    required this.progress,
    required this.questionCount,
    required this.color,
    this.compact = false,
  });

  final double progress;
  final int questionCount;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final width = compact ? 126.0 : 180.0;
    final height = compact ? 92.0 : 132.0;
    final lineFactors = compact
        ? const [.92, .76, .84]
        : const [.92, .76, .84, .58];
    return SizedBox(
      width: width + 32,
      height: height + 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 2; i >= 0; i--)
            Transform.translate(
              offset: Offset(i * 5 * p, -i * 4 * p),
              child: Transform.rotate(
                angle: (1 - p) * (i - 1) * .055,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(compact ? 15 : 19),
                    border: Border.all(
                      color: i == 0
                          ? color
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: i == 0
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: .14),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: i == 0
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$questionCount',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              for (final factor in lineFactors) ...[
                                FractionallySizedBox(
                                  widthFactor: factor,
                                  child: Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 5 : 7),
                              ],
                            ],
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
