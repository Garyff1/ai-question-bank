import 'package:flutter/material.dart';

class KnowledgeNode extends StatelessWidget {
  const KnowledgeNode({
    super.key,
    required this.label,
    required this.progress,
    required this.color,
    this.compact = false,
  });

  final String label;
  final double progress;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    return Opacity(
      opacity: value,
      child: Transform.scale(
        scale: .82 + .18 * value,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: .34)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
