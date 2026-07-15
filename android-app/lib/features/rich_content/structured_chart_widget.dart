import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data.dart';

class StructuredChartWidget extends StatelessWidget {
  const StructuredChartWidget({super.key, required this.data});

  final StructuredChartData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final english = Localizations.localeOf(context).languageCode == 'en';
    if (!data.isValid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_chart_outlined, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                english
                    ? 'Chart data is incomplete. The question text is still available.'
                    : '图表数据不完整，已保留题目文字。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final chart = switch (data.chartType) {
      StructuredChartType.line => _line(context),
      StructuredChartType.pie => _pie(context),
      StructuredChartType.bar => _bar(context),
      _ => _bar(context),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.title.isNotEmpty) ...[
          Text(data.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
        ],
        SizedBox(height: 250, child: chart),
        if (data.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            data.description,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _line(BuildContext context) {
    final colors = _palette(context);
    final spots = <LineChartBarData>[];
    for (var seriesIndex = 0; seriesIndex < data.series.length; seriesIndex++) {
      final series = data.series[seriesIndex];
      spots.add(
        LineChartBarData(
          spots: List.generate(
            series.values.length,
            (index) => FlSpot(index.toDouble(), series.values[index]),
          ),
          isCurved: true,
          barWidth: 3,
          color: colors[seriesIndex % colors.length],
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: seriesIndex == 0,
            color: colors[seriesIndex % colors.length].withValues(alpha: 0.12),
          ),
        ),
      );
    }
    return LineChart(
      LineChartData(
        lineBarsData: spots,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final colors = _palette(context);
    return BarChart(
      BarChartData(
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        barGroups: List.generate(data.xLabels.length, (x) {
          return BarChartGroupData(
            x: x,
            barsSpace: 3,
            barRods: List.generate(data.series.length, (seriesIndex) {
              return BarChartRodData(
                toY: data.series[seriesIndex].values[x],
                width: data.series.length > 1 ? 10 : 18,
                color: colors[seriesIndex % colors.length],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final colors = _palette(context);
    final values = data.series.first.values;
    return PieChart(
      PieChartData(
        centerSpaceRadius: 42,
        sectionsSpace: 3,
        sections: List.generate(values.length, (index) {
          return PieChartSectionData(
            value: values[index].abs(),
            color: colors[index % colors.length],
            radius: 78,
            title:
                '${data.xLabels[index]}\n${_number(values[index])}${data.unit}',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          );
        }),
      ),
    );
  }

  FlTitlesData _titles(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          getTitlesWidget: (value, meta) => Text(
            '${_number(value)}${data.unit}',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= data.xLabels.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                data.xLabels[index],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color),
              ),
            );
          },
        ),
      ),
    );
  }

  FlGridData _grid(BuildContext context) => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => FlLine(
      color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
      strokeWidth: 1,
    ),
  );

  List<Color> _palette(BuildContext context) => [
    Theme.of(context).colorScheme.primary,
    const Color(0xFF10B981),
    const Color(0xFFF97316),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
