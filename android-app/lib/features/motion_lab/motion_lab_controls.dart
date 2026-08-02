import 'package:flutter/material.dart';

class MotionLabControls extends StatelessWidget {
  const MotionLabControls({
    super.key,
    required this.playing,
    required this.speed,
    required this.dark,
    required this.english,
    required this.reduceMotion,
    required this.lowPerformance,
    required this.onPlayPause,
    required this.onReplay,
    required this.onSpeedChanged,
    required this.onDarkChanged,
    required this.onEnglishChanged,
    required this.onReduceMotionChanged,
    required this.onLowPerformanceChanged,
  });

  final bool playing;
  final double speed;
  final bool dark;
  final bool english;
  final bool reduceMotion;
  final bool lowPerformance;
  final VoidCallback onPlayPause;
  final VoidCallback onReplay;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<bool> onEnglishChanged;
  final ValueChanged<bool> onReduceMotionChanged;
  final ValueChanged<bool> onLowPerformanceChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: onPlayPause,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: '重播',
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay_rounded),
                ),
                const SizedBox(width: 12),
                Text('${speed.toStringAsFixed(1)}×'),
                Expanded(
                  child: Slider(
                    value: speed,
                    min: .5,
                    max: 1.5,
                    divisions: 4,
                    onChanged: onSpeedChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('深色'),
                  selected: dark,
                  onSelected: onDarkChanged,
                ),
                FilterChip(
                  label: const Text('English'),
                  selected: english,
                  onSelected: onEnglishChanged,
                ),
                FilterChip(
                  label: const Text('减少动态'),
                  selected: reduceMotion,
                  onSelected: onReduceMotionChanged,
                ),
                FilterChip(
                  label: const Text('低性能'),
                  selected: lowPerformance,
                  onSelected: onLowPerformanceChanged,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.science_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '仅使用本地模拟数据，不读取 API Key，不调用模型或支付。',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
