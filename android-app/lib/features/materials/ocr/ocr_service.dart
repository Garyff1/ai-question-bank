import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../app/app_settings_controller.dart';
import 'ocr_models.dart';

class OcrService {
  const OcrService();

  Future<String?> cropForDocument(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪与旋转',
          toolbarColor: Color(0xFF2563EB),
          toolbarWidgetColor: Color(0xFFFFFFFF),
          activeControlsWidgetColor: Color(0xFF2563EB),
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(title: '裁剪与旋转'),
      ],
    );
    return cropped?.path;
  }

  Future<OcrPageResult> recognizePage(String path, OcrLanguageMode mode) async {
    final file = File(path);
    if (!await file.exists()) {
      return OcrPageResult(path: path, text: '', error: '图片文件不存在');
    }
    try {
      final primary = mode == OcrLanguageMode.english
          ? TextRecognitionScript.latin
          : TextRecognitionScript.chinese;
      var text = await _recognize(path, primary);
      if (text.trim().isEmpty && primary != TextRecognitionScript.latin) {
        text = await _recognize(path, TextRecognitionScript.latin);
      }
      if (text.trim().isEmpty) {
        return OcrPageResult(path: path, text: '', error: '未识别到文字');
      }
      return OcrPageResult(path: path, text: _normalize(text));
    } catch (error, stack) {
      debugPrint('[OCR] $path recognition failed: $error');
      debugPrintStack(stackTrace: stack);
      return OcrPageResult(path: path, text: '', error: '识别失败，请调整图片方向或清晰度后重试');
    }
  }

  Future<String> _recognize(String path, TextRecognitionScript script) async {
    final recognizer = TextRecognizer(script: script);
    try {
      final input = InputImage.fromFilePath(path);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  String _normalize(String value) => value
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
