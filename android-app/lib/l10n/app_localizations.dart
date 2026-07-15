import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI题库'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navGenerate.
  ///
  /// In zh, this message translates to:
  /// **'出题'**
  String get navGenerate;

  /// No description provided for @navPaper.
  ///
  /// In zh, this message translates to:
  /// **'试卷'**
  String get navPaper;

  /// No description provided for @navWrong.
  ///
  /// In zh, this message translates to:
  /// **'错题'**
  String get navWrong;

  /// No description provided for @navMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMe;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好，同学'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好，同学'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好，同学'**
  String get homeGreetingEvening;

  /// No description provided for @homeWorkspaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日学习工作台'**
  String get homeWorkspaceTitle;

  /// No description provided for @homeKnowledgePrompt.
  ///
  /// In zh, this message translates to:
  /// **'今天也来巩固一点知识吧'**
  String get homeKnowledgePrompt;

  /// No description provided for @todayTasks.
  ///
  /// In zh, this message translates to:
  /// **'今日任务'**
  String get todayTasks;

  /// No description provided for @continueChallenge.
  ///
  /// In zh, this message translates to:
  /// **'继续挑战'**
  String get continueChallenge;

  /// No description provided for @startChallenge.
  ///
  /// In zh, this message translates to:
  /// **'开始挑战'**
  String get startChallenge;

  /// No description provided for @scanMaterial.
  ///
  /// In zh, this message translates to:
  /// **'扫描资料'**
  String get scanMaterial;

  /// No description provided for @scanComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'扫描资料将在 v3 第二阶段开放'**
  String get scanComingSoon;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get language;

  /// No description provided for @simplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @generationLanguage.
  ///
  /// In zh, this message translates to:
  /// **'题目生成语言'**
  String get generationLanguage;

  /// No description provided for @followMaterial.
  ///
  /// In zh, this message translates to:
  /// **'跟随资料'**
  String get followMaterial;

  /// No description provided for @soundAndHaptics.
  ///
  /// In zh, this message translates to:
  /// **'声音与震动'**
  String get soundAndHaptics;

  /// No description provided for @soundEffects.
  ///
  /// In zh, this message translates to:
  /// **'音效'**
  String get soundEffects;

  /// No description provided for @backgroundSound.
  ///
  /// In zh, this message translates to:
  /// **'背景音'**
  String get backgroundSound;

  /// No description provided for @hapticFeedback.
  ///
  /// In zh, this message translates to:
  /// **'震动反馈'**
  String get hapticFeedback;

  /// No description provided for @reduceMotion.
  ///
  /// In zh, this message translates to:
  /// **'减少动态效果'**
  String get reduceMotion;

  /// No description provided for @aiService.
  ///
  /// In zh, this message translates to:
  /// **'AI 服务'**
  String get aiService;

  /// No description provided for @ownApiKey.
  ///
  /// In zh, this message translates to:
  /// **'使用自己的 API Key'**
  String get ownApiKey;

  /// No description provided for @officialAiComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'官方 AI 服务（即将开放）'**
  String get officialAiComingSoon;

  /// No description provided for @dataAndPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'数据与隐私'**
  String get dataAndPrivacy;

  /// No description provided for @openSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get openSourceLicenses;

  /// No description provided for @challengeMap.
  ///
  /// In zh, this message translates to:
  /// **'闯关地图'**
  String get challengeMap;

  /// No description provided for @knowledgeShield.
  ///
  /// In zh, this message translates to:
  /// **'知识护盾'**
  String get knowledgeShield;

  /// No description provided for @combo.
  ///
  /// In zh, this message translates to:
  /// **'连击'**
  String get combo;

  /// No description provided for @maxCombo.
  ///
  /// In zh, this message translates to:
  /// **'最高连击'**
  String get maxCombo;

  /// No description provided for @remainingShield.
  ///
  /// In zh, this message translates to:
  /// **'剩余护盾'**
  String get remainingShield;

  /// No description provided for @weakKnowledge.
  ///
  /// In zh, this message translates to:
  /// **'需要继续巩固'**
  String get weakKnowledge;

  /// No description provided for @roundNotPassed.
  ///
  /// In zh, this message translates to:
  /// **'本轮挑战暂未通过'**
  String get roundNotPassed;

  /// No description provided for @challengePassed.
  ///
  /// In zh, this message translates to:
  /// **'挑战完成'**
  String get challengePassed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重新挑战'**
  String get retry;

  /// No description provided for @backToMap.
  ///
  /// In zh, this message translates to:
  /// **'返回地图'**
  String get backToMap;

  /// No description provided for @nextLevel.
  ///
  /// In zh, this message translates to:
  /// **'下一关'**
  String get nextLevel;

  /// No description provided for @reviewWrongs.
  ///
  /// In zh, this message translates to:
  /// **'巩固本轮错题'**
  String get reviewWrongs;

  /// No description provided for @viewExplanation.
  ///
  /// In zh, this message translates to:
  /// **'查看解析'**
  String get viewExplanation;

  /// No description provided for @taskChallenge.
  ///
  /// In zh, this message translates to:
  /// **'完成一次闯关'**
  String get taskChallenge;

  /// No description provided for @taskWrongReview.
  ///
  /// In zh, this message translates to:
  /// **'复习 5 道错题'**
  String get taskWrongReview;

  /// No description provided for @taskCheckIn.
  ///
  /// In zh, this message translates to:
  /// **'完成每日打卡'**
  String get taskCheckIn;

  /// No description provided for @taskPractice.
  ///
  /// In zh, this message translates to:
  /// **'生成一组练习'**
  String get taskPractice;

  /// No description provided for @streakLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续打卡'**
  String get streakLabel;

  /// No description provided for @configured.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get configured;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'待配置'**
  String get notConfigured;

  /// No description provided for @configureKey.
  ///
  /// In zh, this message translates to:
  /// **'配置 Key'**
  String get configureKey;

  /// No description provided for @todayLearningStatus.
  ///
  /// In zh, this message translates to:
  /// **'今日学习状态'**
  String get todayLearningStatus;

  /// No description provided for @checkedInToday.
  ///
  /// In zh, this message translates to:
  /// **'今日已打卡'**
  String get checkedInToday;

  /// No description provided for @checkInNow.
  ///
  /// In zh, this message translates to:
  /// **'立即打卡'**
  String get checkInNow;

  /// No description provided for @todayXp.
  ///
  /// In zh, this message translates to:
  /// **'今日 XP'**
  String get todayXp;

  /// No description provided for @totalQuestions.
  ///
  /// In zh, this message translates to:
  /// **'累计做题'**
  String get totalQuestions;

  /// No description provided for @accuracy.
  ///
  /// In zh, this message translates to:
  /// **'正确率'**
  String get accuracy;

  /// No description provided for @mistakes.
  ///
  /// In zh, this message translates to:
  /// **'错题'**
  String get mistakes;

  /// No description provided for @boostActive.
  ///
  /// In zh, this message translates to:
  /// **'三倍经验进行中'**
  String get boostActive;

  /// No description provided for @boostHint.
  ///
  /// In zh, this message translates to:
  /// **'错题抽卡 5 题全对，可开启 10 分钟三倍经验'**
  String get boostHint;

  /// No description provided for @uploadMaterial.
  ///
  /// In zh, this message translates to:
  /// **'上传资料'**
  String get uploadMaterial;

  /// No description provided for @pasteMaterial.
  ///
  /// In zh, this message translates to:
  /// **'粘贴资料'**
  String get pasteMaterial;

  /// No description provided for @quickTextEntry.
  ///
  /// In zh, this message translates to:
  /// **'快速录入文本'**
  String get quickTextEntry;

  /// No description provided for @startGeneration.
  ///
  /// In zh, this message translates to:
  /// **'开始出题'**
  String get startGeneration;

  /// No description provided for @generationShortcutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按步骤生成练习'**
  String get generationShortcutSubtitle;

  /// No description provided for @wrongCardChallenge.
  ///
  /// In zh, this message translates to:
  /// **'错题抽卡'**
  String get wrongCardChallenge;

  /// No description provided for @wrongCardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'随机复习薄弱点'**
  String get wrongCardSubtitle;

  /// No description provided for @rpgChallenge.
  ///
  /// In zh, this message translates to:
  /// **'闯关挑战'**
  String get rpgChallenge;

  /// No description provided for @rpgChallengeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'闯关赢取徽章'**
  String get rpgChallengeSubtitle;

  /// No description provided for @generatePageTitle.
  ///
  /// In zh, this message translates to:
  /// **'出题练习'**
  String get generatePageTitle;

  /// No description provided for @generatePageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择资料、题型和数量，AI 将在手机端直接生成练习。'**
  String get generatePageSubtitle;

  /// No description provided for @paperPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'试卷生成'**
  String get paperPageTitle;

  /// No description provided for @paperPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按常用模板生成可预览、可下载的完整试卷。'**
  String get paperPageSubtitle;

  /// No description provided for @wrongPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'错题本'**
  String get wrongPageTitle;

  /// No description provided for @wrongPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'错题全部保存在手机本地。'**
  String get wrongPageSubtitle;

  /// No description provided for @mePageTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get mePageTitle;

  /// No description provided for @mePageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'学习数据、API 配置和项目信息都在这里。'**
  String get mePageSubtitle;

  /// No description provided for @apiPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'API 配置'**
  String get apiPageTitle;

  /// No description provided for @apiPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'安卓单体版直接从手机请求大模型，不需要外部后端。'**
  String get apiPageSubtitle;

  /// No description provided for @ocrLanguage.
  ///
  /// In zh, this message translates to:
  /// **'OCR 识别语言'**
  String get ocrLanguage;

  /// No description provided for @ocrAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动识别'**
  String get ocrAuto;

  /// No description provided for @ocrChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get ocrChinese;

  /// No description provided for @ocrEnglish.
  ///
  /// In zh, this message translates to:
  /// **'英文'**
  String get ocrEnglish;

  /// No description provided for @ocrMixed.
  ///
  /// In zh, this message translates to:
  /// **'中英混合'**
  String get ocrMixed;

  /// No description provided for @scanReady.
  ///
  /// In zh, this message translates to:
  /// **'扫描资料'**
  String get scanReady;

  /// No description provided for @scanReadySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'拍照或选择多页图片，在本机识别并编辑'**
  String get scanReadySubtitle;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get empty;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'正在加载…'**
  String get loading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
