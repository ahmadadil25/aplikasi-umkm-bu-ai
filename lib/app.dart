import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'services/theme_service.dart';

class CKasApp extends StatelessWidget {
  const CKasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'C-Kas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const DashboardPage(),
        );
      },
    );
  }
}
