import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reminders/application/reminder_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class QingSongBanApp extends ConsumerStatefulWidget {
  const QingSongBanApp({super.key});

  @override
  ConsumerState<QingSongBanApp> createState() => _QingSongBanAppState();
}

class _QingSongBanAppState extends ConsumerState<QingSongBanApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapReminders());
  }

  Future<void> _bootstrapReminders() async {
    try {
      final scheduler = ref.read(reminderSchedulerProvider);
      await scheduler.initialize(
        onOpenReminder: (id) => appRouter.push('/home/reminders/$id'),
      );
      await scheduler.rescheduleAll();
    } catch (_) {
      // A denied permission or unavailable platform channel must not prevent
      // the local-first app from opening; the settings page surfaces status.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '轻松办',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
