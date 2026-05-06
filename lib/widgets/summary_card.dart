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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRow(context, 'Total Pemasukan', sales, AppTheme.salesGreen),
            const SizedBox(height: 8),
            _buildRow(context, 'Total Pengeluaran', expense, AppTheme.expenseRed),
            const Divider(height: 24, thickness: 1),
            _buildRow(context, 'Bersih', net, AppTheme.primaryBlue, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, int amount, Color color,
      {bool isBold = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: colorScheme.onSurface,
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
