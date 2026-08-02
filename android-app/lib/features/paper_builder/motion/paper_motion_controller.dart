import 'package:flutter/foundation.dart';

import '../../../core/motion/motion_states.dart';

class PaperMotionController extends ChangeNotifier {
  PaperBindingState _state = PaperBindingState.idle;
  PaperBindingState get state => _state;

  void moveTo(PaperBindingState state) {
    _state = state;
    notifyListeners();
  }
}
