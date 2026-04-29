import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahkan import ini untuk TextInputFormatter

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType; 
  final List<TextInputFormatter>? inputFormatters; // Properti baru untuk mengatur format input

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text, 
    this.inputFormatters, // Tambahkan di constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType, 
      inputFormatters: inputFormatters, // Gunakan properti di sini
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
    );
  }
}