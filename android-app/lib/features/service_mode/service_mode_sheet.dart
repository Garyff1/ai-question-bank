import 'package:flutter/material.dart';

import 'service_mode_controller.dart';

Future<AiServiceMode?> showServiceModeSheet(
  BuildContext context, {
  required AiServiceMode currentMode,
  required bool officialServiceEnabled,
}) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return showModalBottomSheet<AiServiceMode>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              english ? 'Choose AI service' : '选择 AI 服务模式',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              english
                  ? 'Switching modes keeps your local materials and API configuration.'
                  : '切换模式不会删除本地资料、API Key 或其他配置。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ModeChoiceCard(
              selected: currentMode == AiServiceMode.byok,
              icon: Icons.key_rounded,
              title: english ? 'Use my API Key' : '使用自己的 API Key',
              lines: english
                  ? const [
                      'No additional app fee',
                      'Provider bills model usage',
                      'Stored only in secure storage',
                      'No official account required',
                    ]
                  : const [
                      '无需向 AI题库 支付生成费用',
                      '模型费用由所选服务商收取',
                      'API Key 仅保存在本机安全存储',
                      '无需登录官方账户',
                    ],
              onTap: () => Navigator.pop(context, AiServiceMode.byok),
            ),
            const SizedBox(height: 12),
            _ModeChoiceCard(
              selected: currentMode == AiServiceMode.official,
              icon: Icons.cloud_outlined,
              title: english ? 'Official AI service' : '使用官方 AI 服务',
              badge: officialServiceEnabled
                  ? null
                  : (english ? 'INTERNAL TEST' : '内部测试中'),
              lines: english
                  ? const [
                      'No API Key required',
                      'Pay by generated quantity',
                      'Real payment is not available',
                    ]
                  : const ['无需配置 API Key', '根据生成数量计费', '真实支付尚未开放'],
              onTap: () => Navigator.pop(context, AiServiceMode.official),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeChoiceCard extends StatelessWidget {
  const _ModeChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.lines,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Text(
                          badge!,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $line',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
