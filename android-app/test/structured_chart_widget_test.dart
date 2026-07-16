import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_question_bank_android/features/rich_content/chart_data.dart';
import 'package:ai_question_bank_android/features/rich_content/structured_chart_widget.dart';

void main() {
  final dataByType = <StructuredChartType, List<double>>{
    StructuredChartType.line: [-2.5, 4.25, 8],
    StructuredChartType.bar: [-3, 2.5, 9],
    StructuredChartType.pie: [20, 30, 50],
  };

  for (final brightness in Brightness.values) {
    for (final locale in const [Locale('zh'), Locale('en')]) {
      for (final entry in dataByType.entries) {
        testWidgets(
          '${entry.key.name} renders in ${brightness.name}/${locale.languageCode}',
          (tester) async {
            tester.view.physicalSize = const Size(360, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final data = StructuredChartData(
              chartType: entry.key,
              title: locale.languageCode == 'en' ? 'Weekly trend' : '每周趋势',
              xLabels: const ['第一季度超长标签', '第二季度超长标签', '第三季度'],
              series: [StructuredChartSeries(name: '数量', values: entry.value)],
              unit: '%',
            );

            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: brightness,
                  ),
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: StructuredChartWidget(data: data),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(find.text(data.title), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('invalid chart shows a localized fallback', (tester) async {
    const invalid = StructuredChartData(
      chartType: StructuredChartType.pie,
      title: '',
      xLabels: ['A', 'B'],
      series: [
        StructuredChartSeries(name: '', values: [0, 0]),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(body: StructuredChartWidget(data: invalid)),
      ),
    );

    expect(find.textContaining('incomplete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
