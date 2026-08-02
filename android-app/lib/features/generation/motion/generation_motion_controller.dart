import 'package:flutter/foundation.dart';

import '../../../core/motion/motion_states.dart';

class GenerationMotionController extends ChangeNotifier {
  GenerateMotionState _state = GenerateMotionState.idle;
  int? _actualQuestionCount;

  GenerateMotionState get state => _state;
  int? get actualQuestionCount => _actualQuestionCount;

  void moveTo(GenerateMotionState next, {int? actualQuestionCount}) {
    if (!_state.canTransitionTo(next)) return;
    _state = next;
    _actualQuestionCount = actualQuestionCount;
    notifyListeners();
  }

  void reset() {
    _state = GenerateMotionState.idle;
    _actualQuestionCount = null;
    notifyListeners();
  }
}
