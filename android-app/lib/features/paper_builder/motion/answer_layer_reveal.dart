import 'package:flutter/material.dart';

import '../../../core/motion/app_motion_tokens.dart';
import '../../../core/motion/motion_preferences.dart';

class AnswerLayerReveal extends StatelessWidget {
  const AnswerLayerReveal({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MotionPreferences.of(context).reduceMotion;
    return ClipRect(
      child: AnimatedAlign(
        duration: AppMotionTokens.resolve(
          reduceMotion: reduce,
          regular: AppMotionTokens.page,
        ),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1 : 0,
        child: AnimatedOpacity(
          duration: AppMotionTokens.resolve(
            reduceMotion: reduce,
            regular: AppMotionTokens.selection,
          ),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}
