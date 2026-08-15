/// 学科相关的富媒体能力集中定义。
///
/// 页面只读取这里的结果，不再各自判断“哪些学科显示图表/听力”。
/// [subject] 使用当前产品中的中文显示值；未知值会安全降级为 Other。
class SubjectCapabilityProfile {
  const SubjectCapabilityProfile({
    required this.subject,
    required this.allowCharts,
    required this.allowFormulas,
    required this.allowListening,
    required this.isCustom,
    this.chartEnabledByMaterial = false,
  });

  final String subject;
  final bool allowCharts;
  final bool allowFormulas;
  final bool allowListening;
  final bool isCustom;
  final bool chartEnabledByMaterial;
}

class SubjectCapabilities {
  const SubjectCapabilities._();

  static const auto = '自动判断';
  static const custom = '自定义';

  static const subjects = <String>[
    auto,
    '语文',
    '数学',
    '英语',
    '物理',
    '化学',
    '生物',
    '地理',
    '历史',
    '政治',
    '其他',
    custom,
  ];

  static const _chartSubjects = <String>{'数学', '物理', '化学', '生物', '地理'};

  static const _formulaSubjects = <String>{'数学', '物理', '化学'};

  static String normalize(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return auto;
    if (subjects.contains(text)) return text;
    final lower = text.toLowerCase();
    const aliases = <String, String>{
      'auto': auto,
      'chinese': '语文',
      'math': '数学',
      'mathematics': '数学',
      'english': '英语',
      'physics': '物理',
      'chemistry': '化学',
      'biology': '生物',
      'geography': '地理',
      'history': '历史',
      'politics': '政治',
      'political science': '政治',
      'other': '其他',
      'custom': custom,
      '通用': '其他',
    };
    return aliases[lower] ?? aliases[text] ?? '其他';
  }

  /// 资料明确包含图表/坐标/实验数据时，即使是通常不展示图表开关的
  /// 学科，也允许用户启用；系统仍会通过资料锚定规则拒绝“章节题量统计”等
  /// 文档元数据题。
  static bool hasExplicitChartEvidence(String materialText) {
    if (materialText.trim().isEmpty) return false;
    return RegExp(
      r'图表|统计图|柱状图|折线图|饼图|散点图|坐标系|函数图像|曲线图|'
      r'数据如下|实验数据|变化趋势|气温|降水量|人口统计|chart|graph|table',
      caseSensitive: false,
    ).hasMatch(materialText);
  }

  static SubjectCapabilityProfile resolve(
    String? subject, {
    String materialText = '',
  }) {
    final normalized = normalize(subject);
    final customMode = normalized == custom;
    final materialChart = hasExplicitChartEvidence(materialText);
    final autoMode = normalized == auto;
    final inferred = autoMode ? inferFromMaterial(materialText) : normalized;
    return SubjectCapabilityProfile(
      subject: inferred,
      allowCharts:
          customMode || _chartSubjects.contains(inferred) || materialChart,
      allowFormulas: customMode || _formulaSubjects.contains(inferred),
      allowListening: customMode || inferred == '英语',
      isCustom: customMode,
      chartEnabledByMaterial:
          materialChart && !_chartSubjects.contains(inferred) && !customMode,
    );
  }

  static String inferFromMaterial(String materialText) {
    final text = materialText.toLowerCase();
    if (RegExp(r'english|grammar|vocabulary|listening|阅读理解').hasMatch(text)) {
      return '英语';
    }
    if (RegExp(r'函数|方程|几何|概率|矩阵|微积分').hasMatch(text)) return '数学';
    if (RegExp(r'力学|电路|电压|速度|加速度|光学').hasMatch(text)) return '物理';
    if (RegExp(r'化学式|元素|反应方程|摩尔|酸碱').hasMatch(text)) return '化学';
    if (RegExp(r'细胞|遗传|生态|生理|蛋白质').hasMatch(text)) return '生物';
    if (RegExp(r'气候|地形|经纬度|人口|降水').hasMatch(text)) return '地理';
    if (RegExp(r'朝代|历史|战争|年代').hasMatch(text)) return '历史';
    if (RegExp(r'政治|法律|公民|经济制度').hasMatch(text)) return '政治';
    if (RegExp(r'语文|文言文|诗歌|修辞|作文').hasMatch(text)) return '语文';
    return '其他';
  }
}
