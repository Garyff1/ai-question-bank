import 'package:flutter/material.dart';

import '../../core/motion/shared_element_route.dart';
import 'motion/service_mode_portal.dart';
import 'service_mode_controller.dart';

Future<AiServiceMode?> showServiceModeSheet(
  BuildContext context, {
  required AiServiceMode currentMode,
  required bool officialServiceEnabled,
}) {
  return Navigator.of(context).push<AiServiceMode>(
    SharedElementRoute<AiServiceMode>(
      opaque: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (_) => ServiceModePortal(
        currentMode: currentMode,
        officialServiceEnabled: officialServiceEnabled,
      ),
    ),
  );
}
