import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);
  
  // Inisialisasi local notifications
  await NotificationService.initialize();

  // Inisialisasi preferensi tema
  await ThemeService.initialize();

  runApp(const CKasApp());
}
