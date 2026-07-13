import 'package:flutter/material.dart';

import 'app_settings_controller.dart';

/// v3 的统一页面过渡入口。旧页面可逐步迁移，不要求一次性改写现有路由。
abstract final class AppRouter {
  static Route<T> page<T>(Widget child) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: const Duration(milliseconds: 360),
      transitionsBuilder: (context, animation, secondaryAnimation, page) {
        if (AppSettingsScope.of(context).reduceMotion) return page;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: page,
          ),
        );
      },
    );
  }
}
