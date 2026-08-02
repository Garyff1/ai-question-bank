import 'package:flutter/foundation.dart';

import '../../../core/motion/motion_states.dart';
import '../service_mode_controller.dart';

class ServiceModeTransitionController extends ChangeNotifier {
  ServiceModeTransitionController(this.initialMode) : _selected = initialMode;

  final AiServiceMode initialMode;
  AiServiceMode _selected;
  ServicePortalState _state = ServicePortalState.idle;
  bool _locked = false;

  AiServiceMode get selected => _selected;
  ServicePortalState get state => _state;
  bool get locked => _locked;

  void open() {
    _state = ServicePortalState.opening;
    notifyListeners();
  }

  void select(AiServiceMode mode) {
    if (_locked || mode == _selected) return;
    _state = ServicePortalState.switching;
    _selected = mode;
    notifyListeners();
  }

  void confirm() {
    if (_locked) return;
    _locked = true;
    _state = ServicePortalState.confirming;
    notifyListeners();
  }
}
