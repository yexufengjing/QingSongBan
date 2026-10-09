import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/widgets/design_canvas.dart';

class QingSongBanApp extends StatelessWidget {
  const QingSongBanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '轻松办',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      theme: AppTheme.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: DesignCanvas(child: child!),
      ),
      routerConfig: appRouter,
    );
  }
}
