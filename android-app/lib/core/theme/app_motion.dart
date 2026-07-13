import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const tap = Duration(milliseconds: 140);
  static const state = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 360);
  static const reward = Duration(milliseconds: 760);
  static const standardCurve = Curves.easeOutCubic;

  static Duration resolve(bool reduceMotion, Duration duration) {
    return reduceMotion ? Duration.zero : duration;
  }
}
