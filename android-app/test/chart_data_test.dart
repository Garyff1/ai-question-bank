import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/rich_content/chart_data.dart';

void main() {
  test('reads structured decimals and long labels', () {
    final chart = StructuredChartData.fromRichContent({
      'chartType': 'line',
      'title': '温度变化',
      'xLabels': ['第一季度超长标签', '第二季度超长标签', '第三季度超长标签'],
      'series': [
        {
          'name': '温度',
          'values': [-2.5, 15.5, 18],
        },
      ],
      'unit': '℃',
    });

    expect(chart.isValid, isTrue);
    expect(chart.chartType, StructuredChartType.line);
    expect(chart.series.single.values, [-2.5, 15.5, 18]);
    expect(
      chart.toLegacyDataString(),
      '第一季度超长标签:-2.50,第二季度超长标签:15.50,第三季度超长标签:18',
    );
  });

  test('keeps legacy chart data readable, including negative values', () {
    final chart = StructuredChartData.fromRichContent({
      'chart_type': 'bar',
      'title': '温差',
      'data': '甲:-3.5,乙:2,丙:8.25',
    });

    expect(chart.isValid, isTrue);
    expect(chart.chartType, StructuredChartType.bar);
    expect(chart.xLabels, ['甲', '乙', '丙']);
    expect(chart.series.single.values, [-3.5, 2, 8.25]);
  });

  test('pie charts reject negative and all-zero values', () {
    for (final values in <List<double>>[
      [-1, 2],
      [0, 0],
    ]) {
      final chart = StructuredChartData(
        chartType: StructuredChartType.pie,
        title: '占比',
        xLabels: const ['A', 'B'],
        series: [StructuredChartSeries(name: '数量', values: values)],
      );
      expect(chart.isValid, isFalse);
    }
  });

  test('invalid lengths and non-finite numbers degrade safely', () {
    final invalidLength = StructuredChartData.fromRichContent({
      'chartType': 'bar',
      'xLabels': ['A', 'B'],
      'series': [
        {
          'name': '数量',
          'values': [1],
        },
      ],
    });
    const nonFinite = StructuredChartData(
      chartType: StructuredChartType.line,
      title: '',
      xLabels: ['A', 'B'],
      series: [
        StructuredChartSeries(name: '', values: [1, double.nan]),
      ],
    );

    expect(invalidLength.isValid, isFalse);
    expect(nonFinite.isValid, isFalse);
  });
}
