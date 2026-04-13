import 'package:intl/intl.dart';

class DateHelper {
  static String formatToId(String isoDate) {
    DateTime date = DateTime.parse(isoDate);
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  static String getTodayIsoPrefix() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}