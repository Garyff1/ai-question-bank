enum CardRunCardType { review, boost, challenge, support, event }

enum CardRunRarity { common, uncommon, rare, special }

class CardDefinition {
  const CardDefinition({
    required this.id,
    required this.type,
    required this.rarity,
    required this.title,
    required this.description,
    required this.effect,
    this.parameters = const {},
    this.durationQuestions = 0,
    this.weight = 1,
  });

  final String id;
  final CardRunCardType type;
  final CardRunRarity rarity;
  final String title;
  final String description;
  final String effect;
  final Map<String, num> parameters;
  final int durationQuestions;
  final int weight;
}

class CardRunQuestion {
  const CardRunQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.answer,
    this.explanation = '',
    this.knowledgePoint = '综合',
    this.isWrong = false,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final String explanation;
  final String knowledgePoint;
  final bool isWrong;
}

class CardRunAnswer {
  const CardRunAnswer({
    required this.question,
    required this.userAnswer,
    required this.correct,
    required this.corrected,
    required this.baseXp,
    required this.bonusXp,
  });

  final CardRunQuestion question;
  final String userAnswer;
  final bool correct;
  final bool corrected;
  final int baseXp;
  final int bonusXp;
}

class CardRunSubmitResult {
  const CardRunSubmitResult({
    required this.correct,
    required this.corrected,
    required this.requiresRetry,
    required this.shieldUsed,
    required this.baseXp,
    required this.bonusXp,
  });

  final bool correct;
  final bool corrected;
  final bool requiresRetry;
  final bool shieldUsed;
  final int baseXp;
  final int bonusXp;
}

class CardRunResult {
  const CardRunResult({
    required this.answers,
    required this.selectedCards,
    required this.eventBonusXp,
  });

  final List<CardRunAnswer> answers;
  final List<CardDefinition> selectedCards;
  final int eventBonusXp;

  int get total => answers.length;
  int get correct => answers.where((item) => item.correct).length;
  int get corrected => answers.where((item) => item.corrected).length;
  int get baseXp => answers.fold(0, (sum, item) => sum + item.baseXp);
  int get cardBonusXp => answers.fold(0, (sum, item) => sum + item.bonusXp);
  int get totalXp => baseXp + cardBonusXp + eventBonusXp;
}

const cardRunDeck = <CardDefinition>[
  CardDefinition(
    id: 'review_rematch',
    type: CardRunCardType.review,
    rarity: CardRunRarity.common,
    title: '再战',
    description: '下一题优先抽取历史错题，答对获得额外成长。',
    effect: 'prioritize_wrong',
    parameters: {'bonus': 4},
    durationQuestions: 1,
    weight: 4,
  ),
  CardDefinition(
    id: 'review_weak_strike',
    type: CardRunCardType.review,
    rarity: CardRunRarity.uncommon,
    title: '薄弱突袭',
    description: '接下来三题优先当前薄弱知识点。',
    effect: 'prioritize_weak',
    durationQuestions: 3,
    weight: 3,
  ),
  CardDefinition(
    id: 'review_recent_scene',
    type: CardRunCardType.review,
    rarity: CardRunRarity.common,
    title: '重返现场',
    description: '将一道历史错题移动到下一题。',
    effect: 'prioritize_wrong',
    durationQuestions: 1,
    weight: 4,
  ),
  CardDefinition(
    id: 'boost_double_growth',
    type: CardRunCardType.boost,
    rarity: CardRunRarity.rare,
    title: '双倍成长',
    description: '接下来两道答对题额外获得等同基础值的 XP。',
    effect: 'bonus_percent',
    parameters: {'percent': 100},
    durationQuestions: 2,
    weight: 2,
  ),
  CardDefinition(
    id: 'boost_golden_focus',
    type: CardRunCardType.boost,
    rarity: CardRunRarity.uncommon,
    title: '黄金专注',
    description: '接下来五题答对时额外获得 25% 基础 XP。',
    effect: 'bonus_percent',
    parameters: {'percent': 25},
    durationQuestions: 5,
    weight: 3,
  ),
  CardDefinition(
    id: 'boost_steady_growth',
    type: CardRunCardType.boost,
    rarity: CardRunRarity.common,
    title: '稳定成长',
    description: '接下来三道答对题每题额外获得 3 XP。',
    effect: 'bonus_fixed',
    parameters: {'bonus': 3},
    durationQuestions: 3,
    weight: 4,
  ),
  CardDefinition(
    id: 'challenge_precision',
    type: CardRunCardType.challenge,
    rarity: CardRunRarity.uncommon,
    title: '精准猎手',
    description: '接下来五题保持至少 80% 正确率，结算额外奖励。',
    effect: 'accuracy_challenge',
    parameters: {'bonus': 8, 'target': 80},
    durationQuestions: 5,
    weight: 3,
  ),
  CardDefinition(
    id: 'challenge_flawless',
    type: CardRunCardType.challenge,
    rarity: CardRunRarity.rare,
    title: '无伤挑战',
    description: '连续答对三题即可获得额外奖励。',
    effect: 'streak_challenge',
    parameters: {'bonus': 8, 'target': 3},
    durationQuestions: 3,
    weight: 2,
  ),
  CardDefinition(
    id: 'challenge_leap',
    type: CardRunCardType.challenge,
    rarity: CardRunRarity.uncommon,
    title: '越级挑战',
    description: '下一题视为高难挑战，答对获得额外奖励。',
    effect: 'next_correct_bonus',
    parameters: {'bonus': 6},
    durationQuestions: 1,
    weight: 3,
  ),
  CardDefinition(
    id: 'support_shield',
    type: CardRunCardType.support,
    rarity: CardRunRarity.common,
    title: '学习护盾',
    description: '下一次答错不打断本局连胜，但仍如实记录错题。',
    effect: 'shield',
    parameters: {'charges': 1},
    weight: 4,
  ),
  CardDefinition(
    id: 'support_retry',
    type: CardRunCardType.support,
    rarity: CardRunRarity.uncommon,
    title: '再试一次',
    description: '下一道答错题允许立即再答一次，首次错误仍会保留。',
    effect: 'retry',
    parameters: {'charges': 1},
    weight: 3,
  ),
  CardDefinition(
    id: 'support_reroll',
    type: CardRunCardType.support,
    rarity: CardRunRarity.common,
    title: '重抽',
    description: '下一次三选一可以免费刷新一次。',
    effect: 'reroll',
    parameters: {'charges': 1},
    weight: 4,
  ),
  CardDefinition(
    id: 'event_chest',
    type: CardRunCardType.event,
    rarity: CardRunRarity.rare,
    title: '知识宝箱',
    description: '立即获得 5 点事件 XP。',
    effect: 'event_bonus',
    parameters: {'bonus': 5},
    weight: 2,
  ),
  CardDefinition(
    id: 'event_hidden_boss',
    type: CardRunCardType.event,
    rarity: CardRunRarity.special,
    title: '隐藏 Boss',
    description: '接下来三题全部答对可获得 12 点事件 XP。',
    effect: 'boss_challenge',
    parameters: {'bonus': 12, 'target': 3},
    durationQuestions: 3,
    weight: 1,
  ),
  CardDefinition(
    id: 'event_mystery',
    type: CardRunCardType.event,
    rarity: CardRunRarity.special,
    title: '神秘卡',
    description: '揭示一份随机事件奖励。',
    effect: 'mystery',
    weight: 1,
  ),
];
