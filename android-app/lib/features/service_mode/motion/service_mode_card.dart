import 'package:flutter/material.dart';

import '../../../core/motion/app_motion_tokens.dart';
import '../service_mode_controller.dart';

class ServiceModePortalCard extends StatelessWidget {
  const ServiceModePortalCard({
    super.key,
    required this.mode,
    required this.selected,
    required this.officialServiceEnabled,
    required this.onTap,
    this.heroEnabled = false,
    this.reduceMotion = false,
  });

  static const heroTag = 'knowledge-forge-service-mode';

  final AiServiceMode mode;
  final bool selected;
  final bool officialServiceEnabled;
  final VoidCallback onTap;
  final bool heroEnabled;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    final official = mode == AiServiceMode.official;
    final accent = official ? scheme.primary : scheme.tertiary;
    final card = Semantics(
      selected: selected,
      button: true,
      label: official
          ? (english ? 'Official AI service' : '官方 AI 服务')
          : (english ? 'Use my API Key' : '使用自己的 API Key'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: AppMotionTokens.resolve(
            reduceMotion: reduceMotion,
            regular: AppMotionTokens.selection,
          ),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(scheme.surface, accent, .13)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected ? accent : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected && !reduceMotion
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .2),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      official ? Icons.cloud_outlined : Icons.key_rounded,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, color: accent),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                official
                    ? (english ? 'Official AI service' : '官方 AI 服务')
                    : (english ? 'Use my API Key' : '使用自己的 API Key'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                official
                    ? (english
                          ? 'No key needed · pay by usage'
                          : '无需配置 Key · 按生成内容计费')
                    : (english
                          ? 'Local, controllable, no app generation fee'
                          : '本地可控 · 软件不额外收取生成费'),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              if (official && !officialServiceEnabled) ...[
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      english
                          ? 'INTERNAL TEST · NO REAL CHARGE'
                          : '内部测试 · 真实支付未开放',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!heroEnabled) return card;
    return Hero(
      tag: heroTag,
      child: Material(type: MaterialType.transparency, child: card),
    );
  }
}
