import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:alarm/alarm.dart';
import 'app.dart'; // Sekarang import ini akan terpakai dengan benar
import 'services/notification_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi package alarm
  await Alarm.init();

  // Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);
  
  // Inisialisasi local notifications & permission
  await NotificationService.initialize();

  // Inisialisasi preferensi tema
  await ThemeService.initialize();

  // Jalankan aplikasi utama
  runApp(const CKasApp());
}