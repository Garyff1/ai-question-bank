import '../paper_builder/models/paper_builder_models.dart';

abstract final class MotionLabDemoData {
  static const materialName = '光合作用复习资料.pdf';
  static const questionTypes = [
    'choice',
    'multi_choice',
    'fill',
    'subjective',
    'chart',
  ];

  static const questions = [
    PaperEditorQuestion(
      id: 'motion-1',
      type: 'choice',
      prompt: '光合作用发生的主要场所是什么？',
      options: ['A. 细胞核', 'B. 叶绿体', 'C. 液泡', 'D. 线粒体'],
      answer: 'B',
      explanation: '叶绿体中的叶绿素能够吸收光能。',
      knowledgePoint: '光合作用',
      score: 3,
      section: '选择题',
    ),
    PaperEditorQuestion(
      id: 'motion-2',
      type: 'fill',
      prompt: '植物吸收光能后，会释放出____。',
      options: [],
      answer: '氧气',
      explanation: '光合作用释放氧气。',
      knowledgePoint: '光合作用产物',
      score: 4,
      section: '填空题',
    ),
    PaperEditorQuestion(
      id: 'motion-3',
      type: 'subjective',
      prompt: '请说明影响光合作用强度的三个因素。',
      options: [],
      answer: '光照强度、二氧化碳浓度、温度等。',
      explanation: '这些因素共同影响光合作用速率。',
      knowledgePoint: '影响因素',
      score: 8,
      section: '主观题',
    ),
  ];
}
