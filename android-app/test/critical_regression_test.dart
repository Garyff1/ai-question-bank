import 'package:ai_question_bank_android/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _rpgResult = RpgLevelResult(
  chapter: 1,
  level: 1,
  stars: 2,
  earnedXp: 17,
  newBadges: [],
  chapterCleared: false,
  allCleared: false,
);

void main() {
  test('RPG every level selects five non-listening mini games', () {
    for (final subject in ['通用', '语文', '英语']) {
      for (var chapter = 1; chapter <= 3; chapter++) {
        for (var level = 1; level <= 5; level++) {
          final types = rpgMiniGameTypesFor(
            subject: subject,
            chapter: chapter,
            level: level,
          );
          expect(types, hasLength(5));
          expect(types, isNot(contains('listening')));
        }
      }
    }
  });

  test('rich content target stays between twenty and thirty percent', () {
    expect(richContentTargetCount(5), 1);
    expect(richContentTargetCount(10), 3);
    expect(richContentTargetCount(20), 5);
  });

  test('PDF chart parser accepts common AI response shapes', () {
    expect(parsePdfChartData('甲：10，乙：20，丙：30'), {'甲': 10, '乙': 20, '丙': 30});
    expect(
      parsePdfChartData({
        'labels': ['一月', '二月'],
        'values': [12, 18],
      }),
      {'一月': 12, '二月': 18},
    );
    expect(
      parsePdfChartData([
        {'label': 'A组', 'value': 25},
        {'label': 'B组', 'value': 40},
      ]),
      {'A组': 25, 'B组': 40},
    );
  });

  test('PDF math formatter removes raw LaTeX control code', () {
    final printable = formatMathForPdf(
      r'$$\mathbf{F}=\mathbf{a}\quad \lambda=\frac{2}{3}$$',
    );
    expect(printable, isNot(contains(r'\mathbf')));
    expect(printable, isNot(contains(r'\frac')));
    expect(printable, isNot(contains(r'$$')));
    expect(printable, contains('λ'));
    expect(printable, contains('(2)/(3)'));
  });

  test('PDF math formatter converts matrices and derivatives', () {
    final printable = formatMathForPdf(
      r'\begin{bmatrix}1 & 0 \\ 0 & 1\end{bmatrix}, '
      r'\ddot{q}+\tau=\omega',
    );
    expect(printable, isNot(contains(r'\begin')));
    expect(printable, isNot(contains(r'\\')));
    expect(printable, contains('[1, 0; 0, 1]'));
    expect(printable, contains('d²(q)/dt²'));
    expect(printable, contains('τ'));
    expect(printable, contains('ω'));
  });

  test('API handshake errors are translated to Chinese', () {
    final error = Exception('HandshakeConnection terminated during handshake');
    expect(isTransientApiError(error), isTrue);
    expect(apiErrorMessage(error), contains('安全连接握手失败'));
    expect(apiErrorMessage(error), isNot(contains('HandshakeConnection')));
  });

  test(
    'paper PDF draws chart and never prints raw rich-content code',
    () async {
      final question = AiQuestion(
        type: 'choice',
        question: '根据各组人数统计图，选择人数最多的一组。',
        options: const ['A. 甲组', 'B. 乙组', 'C. 丙组', 'D. 丁组'],
        answer: 'C',
        explanation: '丙组人数最多。',
        richContent: const [
          {
            'type': 'chart',
            'data': {
              'chart_type': 'bar',
              'data': {'甲组': 10, '乙组': 20, '丙组': 30, '丁组': 15},
              'title': '各组人数',
            },
          },
          {
            'type': 'math',
            'data': {'content': r'$$x=\frac{2}{3}$$'},
          },
        ],
      );
      final paper = Paper(
        id: 'pdf-regression',
        subject: '数学',
        gradeLevel: '初中',
        pageCount: 1,
        materialName: '测试资料',
        questions: [
          PaperQuestion(
            section: '一、单项选择题',
            indexInSection: 1,
            question: question,
          ),
        ],
        createdAt: DateTime(2026, 7, 13),
      );

      final bytes = await PaperPdfService.buildPaperPdf(paper);
      final document = PdfDocument(inputBytes: bytes);
      final extracted = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(bytes.length, greaterThan(1000));
      expect(extracted, isNot(contains(r'\frac')));
      expect(extracted, isNot(contains('图表数据暂不可绘制')));
    expect(extracted, contains('数学公式：x=(2)/(3)'));
    },
  );

  testWidgets('RPG completion callback does not pop the host route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    RpgCompletionAction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: RpgLevelCompleteOverlay(
          result: _rpgResult,
          onAction: (action) => selected = action,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('下一关'));
    await tester.pump();

    expect(selected, RpgCompletionAction.next);
    expect(find.byType(RpgLevelCompleteOverlay), findsOneWidget);
  });

  testWidgets('selected wrong card remains horizontally centered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WrongCardDrawDialog(count: 5, canActivateBoost: true),
      ),
    );
    await tester.tap(find.text('帮我抽一张'));
    await tester.pump(const Duration(milliseconds: 900));

    final stage = find.byKey(const ValueKey('wrong-card-selected-stage'));
    expect(stage, findsOneWidget);
    expect(tester.getCenter(stage).dx, closeTo(180, 0.5));
    expect(tester.getTopLeft(stage).dx, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(stage).dx, lessThanOrEqualTo(360));

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const ValueKey('wrong-card-selected-card')), findsOneWidget);
    expect(find.text('错题卡'), findsOneWidget);
    expect(find.text('已抽 5 题'), findsOneWidget);
  });
}
