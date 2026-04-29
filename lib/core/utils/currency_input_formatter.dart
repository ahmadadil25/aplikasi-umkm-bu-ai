import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 1. Bersihkan input dari semua karakter selain angka
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    // 2. Tambahkan titik setiap 3 digit dari belakang
    String formatted = '';
    int count = 0;
    for (int i = cleanText.length - 1; i >= 0; i--) {
      if (count == 3) {
        formatted = '.$formatted';
        count = 0;
      }
      formatted = cleanText[i] + formatted;
      count++;
    }

    // 3. Pastikan posisi kursor tidak loncat-loncat saat mengetik
    int selectionIndexFromTheRight = newValue.text.length - newValue.selection.end;
    int newOffset = formatted.length - selectionIndexFromTheRight;
    if (newOffset < 0) newOffset = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}