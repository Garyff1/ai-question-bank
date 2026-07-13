// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AI题库';

  @override
  String get navHome => '首页';

  @override
  String get navGenerate => '出题';

  @override
  String get navPaper => '试卷';

  @override
  String get navWrong => '错题';

  @override
  String get navMe => '我的';

  @override
  String get homeGreetingMorning => '早上好，同学';

  @override
  String get homeGreetingAfternoon => '下午好，同学';

  @override
  String get homeGreetingEvening => '晚上好，同学';

  @override
  String get homeWorkspaceTitle => '今日学习工作台';

  @override
  String get homeKnowledgePrompt => '今天也来巩固一点知识吧';

  @override
  String get todayTasks => '今日任务';

  @override
  String get continueChallenge => '继续挑战';

  @override
  String get startChallenge => '开始挑战';

  @override
  String get scanMaterial => '扫描资料';

  @override
  String get scanComingSoon => '扫描资料将在 v3 第二阶段开放';

  @override
  String get settingsTitle => '偏好设置';

  @override
  String get appearance => '外观';

  @override
  String get followSystem => '跟随系统';

  @override
  String get lightMode => '浅色模式';

  @override
  String get darkMode => '深色模式';

  @override
  String get language => '界面语言';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get english => 'English';

  @override
  String get generationLanguage => '题目生成语言';

  @override
  String get followMaterial => '跟随资料';

  @override
  String get soundAndHaptics => '声音与震动';

  @override
  String get soundEffects => '音效';

  @override
  String get backgroundSound => '背景音';

  @override
  String get hapticFeedback => '震动反馈';

  @override
  String get reduceMotion => '减少动态效果';

  @override
  String get aiService => 'AI 服务';

  @override
  String get ownApiKey => '使用自己的 API Key';

  @override
  String get officialAiComingSoon => '官方 AI 服务（即将开放）';

  @override
  String get dataAndPrivacy => '数据与隐私';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get challengeMap => '闯关地图';

  @override
  String get knowledgeShield => '知识护盾';

  @override
  String get combo => '连击';

  @override
  String get maxCombo => '最高连击';

  @override
  String get remainingShield => '剩余护盾';

  @override
  String get weakKnowledge => '需要继续巩固';

  @override
  String get roundNotPassed => '本轮挑战暂未通过';

  @override
  String get challengePassed => '挑战完成';

  @override
  String get retry => '重新挑战';

  @override
  String get backToMap => '返回地图';

  @override
  String get nextLevel => '下一关';

  @override
  String get reviewWrongs => '巩固本轮错题';

  @override
  String get viewExplanation => '查看解析';

  @override
  String get taskChallenge => '完成一次闯关';

  @override
  String get taskWrongReview => '复习 5 道错题';

  @override
  String get taskCheckIn => '完成每日打卡';

  @override
  String get taskPractice => '生成一组练习';

  @override
  String get streakLabel => '连续打卡';

  @override
  String get configured => '已配置';

  @override
  String get notConfigured => '待配置';

  @override
  String get configureKey => '配置 Key';

  @override
  String get todayLearningStatus => '今日学习状态';

  @override
  String get checkedInToday => '今日已打卡';

  @override
  String get checkInNow => '立即打卡';

  @override
  String get todayXp => '今日 XP';

  @override
  String get totalQuestions => '累计做题';

  @override
  String get accuracy => '正确率';

  @override
  String get mistakes => '错题';

  @override
  String get boostActive => '三倍经验进行中';

  @override
  String get boostHint => '错题抽卡 5 题全对，可开启 10 分钟三倍经验';

  @override
  String get uploadMaterial => '上传资料';

  @override
  String get pasteMaterial => '粘贴资料';

  @override
  String get quickTextEntry => '快速录入文本';

  @override
  String get startGeneration => '开始出题';

  @override
  String get generationShortcutSubtitle => '按步骤生成练习';

  @override
  String get wrongCardChallenge => '错题抽卡';

  @override
  String get wrongCardSubtitle => '随机复习薄弱点';

  @override
  String get rpgChallenge => '闯关挑战';

  @override
  String get rpgChallengeSubtitle => '闯关赢取徽章';

  @override
  String get generatePageTitle => '出题练习';

  @override
  String get generatePageSubtitle => '选择资料、题型和数量，AI 将在手机端直接生成练习。';

  @override
  String get paperPageTitle => '试卷生成';

  @override
  String get paperPageSubtitle => '按常用模板生成可预览、可下载的完整试卷。';

  @override
  String get wrongPageTitle => '错题本';

  @override
  String get wrongPageSubtitle => '错题全部保存在手机本地。';

  @override
  String get mePageTitle => '我的';

  @override
  String get mePageSubtitle => '学习数据、API 配置和项目信息都在这里。';

  @override
  String get apiPageTitle => 'API 配置';

  @override
  String get apiPageSubtitle => '安卓单体版直接从手机请求大模型，不需要外部后端。';
}
