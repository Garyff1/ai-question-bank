enum StructuredChartType { line, bar, pie, scatter, radar }

class StructuredChartSeries {
  const StructuredChartSeries({required this.name, required this.values});

  final String name;
  final List<double> values;

  factory StructuredChartSeries.fromJson(Map<String, dynamic> json) {
    return StructuredChartSeries(
      name: (json['name'] ?? '').toString().trim(),
      values: _doubleList(json['values']),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'values': values};
}

class StructuredChartData {
  const StructuredChartData({
    required this.chartType,
    required this.title,
    required this.xLabels,
    required this.series,
    this.unit = '',
    this.description = '',
  });

  final StructuredChartType chartType;
  final String title;
  final List<String> xLabels;
  final List<StructuredChartSeries> series;
  final String unit;
  final String description;

  bool get isValid {
    if (xLabels.length < 2 || series.isEmpty) return false;
    final validSeries = series.every(
      (item) =>
          item.values.length == xLabels.length &&
          item.values.isNotEmpty &&
          item.values.every((value) => value.isFinite),
    );
    if (!validSeries) return false;
    if (chartType == StructuredChartType.pie) {
      final values = series.first.values;
      return values.every((value) => value >= 0) &&
          values.fold<double>(0, (sum, value) => sum + value) > 0;
    }
    return true;
  }

  factory StructuredChartData.fromRichContent(Map<String, dynamic> data) {
    final rawSeries = data['series'];
    final labels = _stringList(data['xLabels'] ?? data['x_labels']);
    final series = rawSeries is List
        ? rawSeries
              .whereType<Map>()
              .map(
                (value) => StructuredChartSeries.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .where((value) => value.values.isNotEmpty)
              .toList(growable: false)
        : const <StructuredChartSeries>[];

    if (labels.isNotEmpty && series.isNotEmpty) {
      return StructuredChartData(
        chartType: _parseType(data['chartType'] ?? data['chart_type']),
        title: (data['title'] ?? '').toString().trim(),
        xLabels: labels,
        series: series,
        unit: (data['unit'] ?? '').toString().trim(),
        description: (data['description'] ?? '').toString().trim(),
      );
    }
    return StructuredChartData.fromLegacy(data);
  }

  factory StructuredChartData.fromLegacy(Map<String, dynamic> data) {
    final pairs = _legacyPairs(data['data']);
    return StructuredChartData(
      chartType: _parseType(data['chart_type'] ?? data['chartType']),
      title: (data['title'] ?? '').toString().trim(),
      xLabels: pairs.map((value) => value.$1).toList(growable: false),
      series: [
        StructuredChartSeries(
          name: (data['series_name'] ?? data['unit'] ?? '').toString().trim(),
          values: pairs.map((value) => value.$2).toList(growable: false),
        ),
      ],
      unit: (data['unit'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'chartType': chartType.name,
    'title': title,
    'xLabels': xLabels,
    'series': series.map((value) => value.toJson()).toList(),
    if (unit.isNotEmpty) 'unit': unit,
    if (description.isNotEmpty) 'description': description,
  };

  String toLegacyDataString() {
    if (series.isEmpty) return '';
    final values = series.first.values;
    final length = values.length < xLabels.length
        ? values.length
        : xLabels.length;
    return List.generate(length, (index) {
      final value = values[index];
      final printable = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
      return '${xLabels[index]}:$printable';
    }).join(',');
  }
}

StructuredChartType _parseType(dynamic value) {
  return switch (value?.toString().toLowerCase()) {
    'line' => StructuredChartType.line,
    'pie' => StructuredChartType.pie,
    'scatter' => StructuredChartType.scatter,
    'radar' => StructuredChartType.radar,
    _ => StructuredChartType.bar,
  };
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<double> _doubleList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(
        (item) =>
            item is num ? item.toDouble() : double.tryParse(item.toString()),
      )
      .whereType<double>()
      .toList(growable: false);
}

List<(String, double)> _legacyPairs(dynamic value) {
  final text = value?.toString() ?? '';
  final result = <(String, double)>[];
  for (final part in text.split(RegExp(r'[,，;；\n]+'))) {
    final match = RegExp(
      r'^\s*([^:：=]+?)\s*[:：=]\s*(-?\d+(?:\.\d+)?)\s*%?\s*$',
    ).firstMatch(part);
    if (match == null) continue;
    final label = match.group(1)!.trim();
    final number = double.tryParse(match.group(2)!);
    if (label.isNotEmpty && number != null && number.isFinite) {
      result.add((label, number));
    }
  }
  return result;
}
