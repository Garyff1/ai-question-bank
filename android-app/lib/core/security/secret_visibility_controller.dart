import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SecretVisibilityController extends ChangeNotifier
    with WidgetsBindingObserver {
  SecretVisibilityController({
    this.visibleDuration = const Duration(seconds: 8),
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Duration visibleDuration;
  Timer? _timer;
  bool _visible = false;

  bool get visible => _visible;

  void revealTemporarily() {
    _timer?.cancel();
    _visible = true;
    notifyListeners();
    _timer = Timer(visibleDuration, hide);
  }

  void hide() {
    _timer?.cancel();
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) hide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
