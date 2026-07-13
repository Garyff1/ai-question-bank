import 'package:flutter/material.dart';

enum ChallengeLevelType { warmup, combo, wrongAmbush, survival, boss }

class ChallengeRule {
  const ChallengeRule({
    required this.level,
    required this.type,
    required this.titleZh,
    required this.titleEn,
    required this.descriptionZh,
    required this.descriptionEn,
    required this.icon,
    required this.shield,
    required this.questionCount,
    this.timeLimit,
  });

  final int level;
  final ChallengeLevelType type;
  final String titleZh;
  final String titleEn;
  final String descriptionZh;
  final String descriptionEn;
  final IconData icon;
  final int shield;
  final int questionCount;
  final Duration? timeLimit;

  bool get isBoss => type == ChallengeLevelType.boss;
  bool get usesCombo => type == ChallengeLevelType.combo || isBoss;
  bool get mixesWrongQuestions => type == ChallengeLevelType.wrongAmbush;

  String title(Locale locale) =>
      locale.languageCode == 'en' ? titleEn : titleZh;
  String description(Locale locale) =>
      locale.languageCode == 'en' ? descriptionEn : descriptionZh;
}

abstract final class ChallengeRules {
  static const levels = <ChallengeRule>[
    ChallengeRule(
      level: 1,
      type: ChallengeLevelType.warmup,
      titleZh: '基础热身',
      titleEn: 'Warm-up',
      descriptionZh: '3 道基础互动题，无时间压力',
      descriptionEn: '3 foundation questions without time pressure',
      icon: Icons.wb_sunny_rounded,
      shield: 3,
      questionCount: 3,
    ),
    ChallengeRule(
      level: 2,
      type: ChallengeLevelType.combo,
      titleZh: '连击挑战',
      titleEn: 'Combo Run',
      descriptionZh: '连续答对可点亮知识连击',
      descriptionEn: 'Build a knowledge combo with correct answers',
      icon: Icons.bolt_rounded,
      shield: 3,
      questionCount: 5,
    ),
    ChallengeRule(
      level: 3,
      type: ChallengeLevelType.wrongAmbush,
      titleZh: '错题伏击',
      titleEn: 'Mistake Ambush',
      descriptionZh: '围绕薄弱知识点展开强化训练',
      descriptionEn: 'Reinforce your weakest knowledge points',
      icon: Icons.style_rounded,
      shield: 3,
      questionCount: 5,
    ),
    ChallengeRule(
      level: 4,
      type: ChallengeLevelType.survival,
      titleZh: '知识生存',
      titleEn: 'Knowledge Survival',
      descriptionZh: '限时守住 3 格知识护盾',
      descriptionEn: 'Protect 3 knowledge shields before time runs out',
      icon: Icons.shield_rounded,
      shield: 3,
      questionCount: 5,
      timeLimit: Duration(seconds: 120),
    ),
    ChallengeRule(
      level: 5,
      type: ChallengeLevelType.boss,
      titleZh: 'Boss 综合测试',
      titleEn: 'Boss Knowledge Core',
      descriptionZh: '击破 5 格知识核心，完成章节终局',
      descriptionEn: 'Break the 5-layer knowledge core to finish the chapter',
      icon: Icons.hub_rounded,
      shield: 3,
      questionCount: 5,
    ),
  ];

  static ChallengeRule forLevel(int level) {
    return levels[(level.clamp(1, levels.length)) - 1];
  }
}
