import 'package:flutter/material.dart';

import '../../core/ai/provider_catalog.dart';
import '../../core/motion/app_motion_tokens.dart';

class CurrentProviderCard extends StatelessWidget {
  const CurrentProviderCard({
    super.key,
    required this.providerId,
    required this.model,
    required this.keyConfigured,
    required this.onTap,
  });

  final String providerId;
  final String model;
  final bool keyConfigured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = AiProviderCatalog.byId(providerId);
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.hub_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      english ? 'Current provider' : '当前模型服务商',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${provider.name} · ${model.trim().isEmpty ? (english ? 'Model not set' : '未设置模型') : model}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keyConfigured
                          ? (english
                                ? 'API Key stored securely on this device'
                                : 'API Key 已安全保存在本机')
                          : (english
                                ? 'API Key is not configured'
                                : '尚未配置 API Key'),
                      style: TextStyle(
                        color: keyConfigured ? scheme.tertiary : scheme.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.swap_horiz_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showProviderPortal(
  BuildContext context, {
  required String currentProviderId,
  required bool keyConfigured,
  required String currentModel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProviderPortalSheet(
      currentProviderId: currentProviderId,
      keyConfigured: keyConfigured,
      currentModel: currentModel,
    ),
  );
}

class _ProviderPortalSheet extends StatefulWidget {
  const _ProviderPortalSheet({
    required this.currentProviderId,
    required this.keyConfigured,
    required this.currentModel,
  });

  final String currentProviderId;
  final bool keyConfigured;
  final String currentModel;

  @override
  State<_ProviderPortalSheet> createState() => _ProviderPortalSheetState();
}

class _ProviderPortalSheetState extends State<_ProviderPortalSheet> {
  late String _selected = widget.currentProviderId;

  IconData _iconFor(String id) => switch (id) {
    'deepseek' => Icons.water_drop_outlined,
    'qwen' => Icons.cloud_queue_rounded,
    'zhipu' => Icons.auto_awesome_rounded,
    'siliconflow' => Icons.memory_rounded,
    'mimo' => Icons.bolt_rounded,
    'kimi' => Icons.nightlight_round,
    _ => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? 'Provider Portal' : '模型服务商传送门',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    english
                        ? 'Choose where requests are sent. Your API Key stays in Android Keystore.'
                        : '选择本次请求使用的服务商。API Key 始终保存在 Android Keystore。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: AiProviderCatalog.presets.length,
                itemBuilder: (context, index) {
                  final provider = AiProviderCatalog.presets[index];
                  final selected = provider.id == _selected;
                  return InkWell(
                    onTap: () => setState(() => _selected = provider.id),
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: AppMotionTokens.resolve(
                        reduceMotion: reduceMotion,
                        regular: AppMotionTokens.selection,
                      ),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected && !reduceMotion
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: .18),
                                  blurRadius: 22,
                                  offset: const Offset(0, 9),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconFor(provider.id),
                                color: scheme.primary,
                              ),
                              const Spacer(),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            provider.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.id == widget.currentProviderId
                                ? (widget.keyConfigured
                                      ? (english ? 'Key configured' : 'Key 已配置')
                                      : (english ? 'Key required' : '需要配置 Key'))
                                : provider.model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.hub_rounded),
                  label: Text(english ? 'Use this provider' : '使用这个服务商'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
