import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/paper_builder_models.dart';

class PaperPreset {
  const PaperPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.system = true,
  });
  final String id;
  final String name;
  final PaperBuilderSettings settings;
  final bool system;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
    'system': system,
  };
  factory PaperPreset.fromJson(Map<String, dynamic> json) => PaperPreset(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    settings: PaperBuilderSettings.fromJson(
      Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
    ),
    system: json['system'] as bool? ?? false,
  );
}

class PaperTemplateService {
  static const _customKey = 'paper_builder.custom_templates_v3';

  static const systemPresets = <PaperPreset>[
    PaperPreset(
      id: 'quick',
      name: '快速小测',
      settings: PaperBuilderSettings(
        paperName: '快速小测',
        totalQuestions: 10,
        durationMinutes: 15,
        questionCounts: {
          'choice': 4,
          'multi_choice': 1,
          'true_false': 2,
          'fill': 2,
          'subjective': 1,
        },
      ),
    ),
    PaperPreset(
      id: 'classroom',
      name: '课堂练习',
      settings: PaperBuilderSettings(
        paperName: '课堂练习',
        totalQuestions: 20,
        durationMinutes: 30,
      ),
    ),
    PaperPreset(
      id: 'unit',
      name: '单元测试',
      settings: PaperBuilderSettings(
        paperName: '单元测试',
        totalQuestions: 30,
        durationMinutes: 60,
        questionCounts: {
          'choice': 12,
          'multi_choice': 3,
          'true_false': 4,
          'fill': 6,
          'subjective': 5,
        },
      ),
    ),
    PaperPreset(
      id: 'wrong',
      name: '错题强化',
      settings: PaperBuilderSettings(
        paperName: '错题强化',
        totalQuestions: 10,
        durationMinutes: 20,
        preferWrongs: true,
        avoidHistoricalDuplicates: true,
        questionCounts: {
          'choice': 4,
          'multi_choice': 1,
          'true_false': 1,
          'fill': 2,
          'subjective': 2,
        },
      ),
    ),
  ];

  Future<List<PaperPreset>> loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_customKey) ?? '[]') as List;
      return raw
          .whereType<Map>()
          .map((e) => PaperPreset.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustom(List<PaperPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customKey,
      jsonEncode(
        presets.where((e) => !e.system).map((e) => e.toJson()).toList(),
      ),
    );
  }
}
