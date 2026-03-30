import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/app/router.dart';
import 'package:meditator/core/deeplink/deeplink_handler.dart';
import 'package:meditator/core/downloads/download_manager.dart';
import 'package:meditator/core/notifications/push_service.dart';
import 'package:meditator/core/subscription/subscription_service.dart';
import 'package:meditator/shared/widgets/gyro_parallax.dart';

import 'package:meditator/shared/utils/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> _loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('app_theme_mode');
  themeNotifier.value = switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_theme_mode', switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    initializeDateFormatting('ru'),
    dotenv.load(fileName: '.env').catchError((_) {}),
  ]);

  await _loadThemePreference();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = dotenv.env['ENVIRONMENT'] ?? 'dev';
      },
      appRunner: () => runApp(const MeditatorApp()),
    );
  } else {
    runApp(const MeditatorApp());
  }

  SubscriptionService.instance.init().catchError((_) {});
  DownloadManager.instance.init().catchError((_) {});
  DeeplinkHandler.instance.init();
  PushService.instance.init().catchError((_) {});
}

class MeditatorApp extends StatelessWidget {
  const MeditatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GyroParallaxProvider(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, mode, _) {
          return MaterialApp.router(
            title: 'Meditator',
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
