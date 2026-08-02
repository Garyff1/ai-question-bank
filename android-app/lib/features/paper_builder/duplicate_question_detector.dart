import 'models/paper_builder_models.dart';

class DuplicateQuestionMatch {
  const DuplicateQuestionMatch(this.firstIndex, this.secondIndex, this.reason);
  final int firstIndex;
  final int secondIndex;
  final String reason;
}

class DuplicateQuestionDetector {
  static List<DuplicateQuestionMatch> detect(
    List<PaperEditorQuestion> questions,
  ) {
    final matches = <DuplicateQuestionMatch>[];
    for (var i = 0; i < questions.length; i++) {
      for (var j = i + 1; j < questions.length; j++) {
        final a = questions[i];
        final b = questions[j];
        final promptSimilarity = _similarity(a.prompt, b.prompt);
        final sameOptions =
            a.options.isNotEmpty &&
            b.options.isNotEmpty &&
            _normalized(a.options.join('|')) ==
                _normalized(b.options.join('|'));
        if (promptSimilarity >= 0.82) {
          matches.add(DuplicateQuestionMatch(i, j, '题干高度相似'));
        } else if (sameOptions) {
          matches.add(DuplicateQuestionMatch(i, j, '选项完全相同'));
        }
      }
    }
    return matches;
  }

  static String _normalized(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');

  static double _similarity(String a, String b) {
    final left = _normalized(a);
    final right = _normalized(b);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    final leftBigrams = <String>{};
    final rightBigrams = <String>{};
    for (var i = 0; i < left.length - 1; i++)
      leftBigrams.add(left.substring(i, i + 2));
    for (var i = 0; i < right.length - 1; i++)
      rightBigrams.add(right.substring(i, i + 2));
    if (leftBigrams.isEmpty || rightBigrams.isEmpty) return 0;
    final intersection = leftBigrams.intersection(rightBigrams).length;
    return 2 * intersection / (leftBigrams.length + rightBigrams.length);
  }
}
