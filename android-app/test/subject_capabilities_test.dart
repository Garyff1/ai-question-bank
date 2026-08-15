import 'package:flutter_test/flutter_test.dart';
import 'package:ai_question_bank_android/core/subject/subject_capabilities.dart';

void main() {
  group('SubjectCapabilities', () {
    for (final subject in const ['数学', '物理', '化学', '生物', '地理']) {
      test('$subject 默认允许图表', () {
        expect(SubjectCapabilities.resolve(subject).allowCharts, isTrue);
      });
    }

    for (final subject in const ['语文', '英语', '历史', '政治']) {
      test('$subject 默认隐藏图表', () {
        expect(SubjectCapabilities.resolve(subject).allowCharts, isFalse);
      });
    }

    test('英语允许听力，普通非英语学科隐藏听力', () {
      expect(SubjectCapabilities.resolve('英语').allowListening, isTrue);
      expect(SubjectCapabilities.resolve('数学').allowListening, isFalse);
      expect(SubjectCapabilities.resolve('语文').allowListening, isFalse);
    });

    test('自定义允许用户覆盖图表公式和听力', () {
      final profile = SubjectCapabilities.resolve('自定义');
      expect(profile.allowCharts, isTrue);
      expect(profile.allowFormulas, isTrue);
      expect(profile.allowListening, isTrue);
    });

    test('资料有明确图表内容时允许显示图表能力', () {
      final profile = SubjectCapabilities.resolve(
        '历史',
        materialText: '下表为人口统计数据，请结合柱状图分析变化趋势。',
      );
      expect(profile.allowCharts, isTrue);
      expect(profile.chartEnabledByMaterial, isTrue);
    });

    test('自动判断可从核心内容推断学科', () {
      expect(
        SubjectCapabilities.resolve(
          '自动判断',
          materialText: '一次函数与二次方程的解法',
        ).subject,
        '数学',
      );
    });
  });
}
