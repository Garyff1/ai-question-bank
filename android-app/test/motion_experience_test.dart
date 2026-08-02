import 'package:ai_question_bank_android/core/motion/motion_performance_policy.dart';
import 'package:ai_question_bank_android/core/motion/motion_states.dart';
import 'package:ai_question_bank_android/features/generation/motion/generation_motion_controller.dart';
import 'package:ai_question_bank_android/features/generation/motion/knowledge_forge_view.dart';
import 'package:ai_question_bank_android/features/paper_builder/motion/answer_layer_reveal.dart';
import 'package:ai_question_bank_android/features/paper_builder/motion/paper_binding_transition.dart';
import 'package:ai_question_bank_android/features/service_mode/motion/service_mode_transition_controller.dart';
import 'package:ai_question_bank_android/features/service_mode/service_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generation motion follows real states and ignores backwards moves', () {
    final controller = GenerationMotionController();
    controller.moveTo(GenerateMotionState.readingMaterial);
    controller.moveTo(GenerateMotionState.generatingQuestions);
    controller.moveTo(GenerateMotionState.validating, actualQuestionCount: 6);
    controller.moveTo(GenerateMotionState.planningTypes);

    expect(controller.state, GenerateMotionState.validating);
    expect(controller.actualQuestionCount, 6);

    controller.reset();
    expect(controller.state, GenerateMotionState.idle);
    expect(controller.actualQuestionCount, isNull);
  });

  test('service portal locks the selected mode after confirmation', () {
    final controller = ServiceModeTransitionController(AiServiceMode.byok);
    controller.open();
    controller.select(AiServiceMode.official);
    controller.confirm();
    controller.select(AiServiceMode.byok);

    expect(controller.selected, AiServiceMode.official);
    expect(controller.state, ServicePortalState.confirming);
    expect(controller.locked, isTrue);
  });

  test('reduced and low-performance policies remove expensive effects', () {
    final reduced = MotionPerformancePolicy.resolve(
      reduceMotion: true,
      lowPerformance: false,
    );
    final low = MotionPerformancePolicy.resolve(
      reduceMotion: false,
      lowPerformance: true,
    );
    final full = MotionPerformancePolicy.resolve(
      reduceMotion: false,
      lowPerformance: false,
    );

    expect(reduced.blurEnabled, isFalse);
    expect(reduced.maxMovingObjects, 1);
    expect(low.particlesEnabled, isFalse);
    expect(low.maxMovingObjects, lessThan(full.maxMovingObjects));
    expect(full.blurEnabled, isTrue);
  });

  testWidgets('knowledge forge never invents question progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KnowledgeForgeView(
            state: GenerateMotionState.generatingQuestions,
            materialName: '测试资料.pdf',
            totalQuestions: 10,
            reduceMotionOverride: true,
          ),
        ),
      ),
    );

    expect(find.text('Generating questions'), findsOneWidget);
    expect(find.textContaining('/ 10'), findsNothing);
    expect(find.textContaining('No fake question count'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KnowledgeForgeView(
            state: GenerateMotionState.validating,
            actualQuestionCount: 7,
            totalQuestions: 10,
            reduceMotionOverride: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7 / 10'), findsOneWidget);
  });

  testWidgets('paper binding and answer layer have safe reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PaperBindingTransition(
                state: PaperBindingState.binding,
                questionCount: 12,
                reduceMotionOverride: true,
                compact: true,
              ),
              AnswerLayerReveal(visible: false, child: Text('参考答案')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Binding paper'), findsOneWidget);
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });
}
