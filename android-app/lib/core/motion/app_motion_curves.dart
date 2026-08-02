import 'package:flutter/animation.dart';

abstract final class AppMotionCurves {
  static const enter = Cubic(.22, 1, .36, 1);
  static const exit = Cubic(.4, 0, 1, 1);
  static const emphasized = Cubic(.2, .8, .2, 1);
  static const settle = Cubic(.16, 1, .3, 1);
}
