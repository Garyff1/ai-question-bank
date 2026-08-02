import 'package:flutter/material.dart';

import 'service_mode_controller.dart';

class CurrentServiceModeCard extends StatelessWidget {
  const CurrentServiceModeCard({
    super.key,
    required this.mode,
    required this.onTap,
  });

  final AiServiceMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final official = mode == AiServiceMode.official;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  official ? Icons.cloud_outlined : Icons.key_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      english ? 'Current service' : '当前服务',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      official
                          ? (english ? 'Official AI service' : '官方 AI 服务')
                          : (english ? 'Use my API Key' : '使用自己的 API Key'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                english ? 'Change' : '切换',
                style: TextStyle(color: scheme.primary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
