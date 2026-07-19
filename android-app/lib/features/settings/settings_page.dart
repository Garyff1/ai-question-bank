import 'package:flutter/material.dart';

import '../../core/localization/localization_extensions.dart';
import '../../core/theme/app_spacing.dart';
import 'settings_center_card.dart';

/// 独立偏好设置页。
///
/// 将外观、语言、声音与震动等低频设置从“我的”学习数据流中移出，
/// 让统计与练习历史保持更高的信息优先级。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: const [SettingsCenterCard()],
        ),
      ),
    );
  }
}
