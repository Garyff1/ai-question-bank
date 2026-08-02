import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/paper_builder_models.dart';

class PaperDraftStorage {
  static const settingsKey = 'paper_builder.settings_draft_v3';
  static const editorKey = 'paper_builder.editor_draft_v3';

  Future<void> saveSettings(PaperBuilderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  Future<PaperBuilderSettings?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PaperBuilderSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEditor(PaperEditorDocument document) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(editorKey, jsonEncode(document.toJson()));
  }

  Future<PaperEditorDocument?> loadEditor() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(editorKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PaperEditorDocument.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSettings() async =>
      (await SharedPreferences.getInstance()).remove(settingsKey);
  Future<void> clearEditor() async =>
      (await SharedPreferences.getInstance()).remove(editorKey);
}
