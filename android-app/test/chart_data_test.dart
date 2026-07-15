import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/rich_content/chart_data.dart';

void main() {
  test('reads the v3 structured chart schema', () {
    final chart = StructuredChartData.fromRichContent({
      'chartType': 'line',
      'title': '温度变化',
      'xLabels': ['1月', '2月', '3月'],
      'series': [
        {
          'name': '温度',
          'values': [12, 15.5, 18],
        },
      ],
      'unit': '℃',
    });

    expect(chart.isValid, isTrue);
    expect(chart.chartType, StructuredChartType.line);
    expect(chart.series.single.values, [12, 15.5, 18]);
    expect(chart.toLegacyDataString(), '1月:12,2月:15.50,3月:18');
  });

  test('keeps legacy chart data readable', () {
    final chart = StructuredChartData.fromRichContent({
      'chart_type': 'pie',
      'title': '占比',
      'data': '语文:30,数学:45,英语:25',
    });

    expect(chart.isValid, isTrue);
    expect(chart.chartType, StructuredChartType.pie);
    expect(chart.xLabels, ['语文', '数学', '英语']);
    expect(chart.series.single.values, [30, 45, 25]);
  });

  test('invalid chart data degrades safely', () {
    final chart = StructuredChartData.fromRichContent({
      'chartType': 'bar',
      'xLabels': ['A'],
      'series': [
        {
          'name': '数量',
          'values': [1],
        },
      ],
    });

    expect(chart.isValid, isFalse);
  });
}
