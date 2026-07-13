import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'app_settings_controller.dart';

class AiQuestionBankApp extends StatelessWidget {
  const AiQuestionBankApp({
    super.key,
    required this.settings,
    required this.home,
  });

  final AppSettingsController settings;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      controller: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'AI题库',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              final dark = brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarColor: dark
                      ? const Color(0xFF0E192A)
                      : Colors.white,
                  systemNavigationBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: home,
          );
        },
      ),
    );
  }
}
