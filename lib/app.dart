import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'core/theme/app_theme.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/alarm_ring_page.dart';
import 'services/theme_service.dart';

// Pindahkan navigatorKey ke sini sebagai global variable
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CKasApp extends StatefulWidget {
  const CKasApp({Key? key}) : super(key: key);

  @override
  State<CKasApp> createState() => _CKasAppState();
}

class _CKasAppState extends State<CKasApp> {
  @override
  void initState() {
    super.initState();
    // Dengarkan stream alarm yang berbunyi saat aplikasi berjalan di background/foreground
    Alarm.ringStream.stream.listen((alarmSettings) {
      _navigateToAlarmPage(alarmSettings);
    });
  }

  void _navigateToAlarmPage(AlarmSettings alarmSettings) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmRingPage(alarmSettings: alarmSettings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey, // Pasang navigatorKey untuk fitur alarm
          title: 'C-Kas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const DashboardPage(), // Ini akan memanggil dashboard asli Anda
        );
      },
    );
  }
}