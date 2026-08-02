import 'package:ai_question_bank_android/features/paper_builder/models/paper_builder_models.dart';
import 'package:ai_question_bank_android/features/paper_builder/paper_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'editor draft survives restart-style reload and can be cleared',
    () async {
      final storage = PaperDraftStorage();
      final document = PaperEditorDocument(
        id: 'paper-1',
        name: '草稿试卷',
        durationMinutes: 30,
        totalScore: 20,
        materialName: '资料A',
        questions: const [
          PaperEditorQuestion(
            id: 'q-1',
            type: 'choice',
            prompt: '1+1=?',
            options: ['1', '2'],
            answer: '2',
            explanation: '基础加法',
            knowledgePoint: '加法',
            score: 2,
            section: '选择题',
          ),
        ],
        updatedAt: DateTime(2026, 8, 2),
      );

      await storage.saveEditor(document);
      final restored = await PaperDraftStorage().loadEditor();
      expect(restored?.name, '草稿试卷');
      expect(restored?.questions.single.prompt, '1+1=?');

      await storage.clearEditor();
      expect(await storage.loadEditor(), isNull);
    },
  );
}
