import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'pages/dashboard/dashboard_page.dart';

class CKasApp extends StatelessWidget {
  const CKasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C-Kas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const DashboardPage(),
    );
  }
}