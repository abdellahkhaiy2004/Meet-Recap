import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/settings_page.dart';
import 'services/notification_service.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Bind the notification tap handler so OS taps deep-link into the app.
    // Called on every build but harmless — just replaces the callback reference.
    NotificationService.instance.bindOnTap(router.go);

    return MaterialApp.router(
      title: 'Auto-Derdacha',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
    );
  }
}
