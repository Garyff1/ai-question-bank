import 'package:ai_question_bank_android/core/ai/material_context_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short material remains unchanged', () {
    const source = '第一章\n机器人由执行器、传感器和控制器组成。';
    expect(
      MaterialContextSelector.select(material: source, maxChars: 6500),
      source,
    );
  });

  test('long material samples beginning, middle and ending chapters', () {
    final chapters = List.generate(
      9,
      (index) =>
          '第${index + 1}章 UNIQUE_CHAPTER_${index + 1}\n'
          '${List.filled(1100, String.fromCharCode(65 + index)).join()}',
    );
    final source = chapters.join('\n\n');
    final selected = MaterialContextSelector.select(
      material: source,
      maxChars: 6500,
    );

    expect(selected.length, lessThanOrEqualTo(6500));
    expect(selected, contains('UNIQUE_CHAPTER_1'));
    expect(selected, contains('UNIQUE_CHAPTER_5'));
    expect(selected, contains('UNIQUE_CHAPTER_9'));
    expect(selected, contains('章节片段'));
  });

  test('focus query keeps a relevant section from later source content', () {
    final source = [
      '概述\n${List.filled(600, '前言内容').join()}',
      '第七章\n${List.filled(500, '一般内容').join()}',
      '第八章 伺服控制\n${List.filled(180, '闭环控制与编码器反馈').join()}',
      '附录\n${List.filled(600, '附录内容').join()}',
    ].join('\n\n');
    final selected = MaterialContextSelector.select(
      material: source,
      maxChars: 2600,
      focusQuery: '伺服控制 编码器反馈',
    );

    expect(selected.length, lessThanOrEqualTo(2600));
    expect(selected, contains('伺服控制'));
    expect(selected, contains('编码器反馈'));
  });
}
