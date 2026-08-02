import 'package:flutter/material.dart';

import 'app_motion_curves.dart';
import 'app_motion_tokens.dart';

class SharedElementRoute<T> extends PageRouteBuilder<T> {
  SharedElementRoute({
    required WidgetBuilder builder,
    super.opaque = true,
    Color barrierColor = const Color(0x99020A18),
    super.barrierLabel,
  }) : super(
         barrierColor: opaque ? null : barrierColor,
         barrierDismissible: !opaque,
         transitionDuration: AppMotionTokens.sharedElement,
         reverseTransitionDuration: AppMotionTokens.panel,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final disable =
               MediaQuery.maybeOf(context)?.disableAnimations ?? false;
           if (disable) return FadeTransition(opacity: animation, child: child);
           final curve = CurvedAnimation(
             parent: animation,
             curve: AppMotionCurves.enter,
             reverseCurve: AppMotionCurves.exit,
           );
           return FadeTransition(
             opacity: curve,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0, .045),
                 end: Offset.zero,
               ).animate(curve),
               child: ScaleTransition(
                 scale: Tween<double>(begin: .97, end: 1).animate(curve),
                 child: child,
               ),
             ),
           );
         },
       );
}
