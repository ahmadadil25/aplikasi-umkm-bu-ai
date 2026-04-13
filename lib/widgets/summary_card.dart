import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final int sales;
  final int expense;
  final int net;

  const SummaryCard({
    Key? key,
    required this.sales,
    required this.expense,
    required this.net,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRow('Total Penjualan', sales, AppTheme.salesGreen),
            const SizedBox(height: 8),
            _buildRow('Total Pengeluaran', expense, AppTheme.expenseRed),
            const Divider(height: 24, thickness: 1),
            _buildRow('Bersih', net, AppTheme.primaryBlue, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, int amount, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          CurrencyFormatter.formatRupiah(amount),
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}