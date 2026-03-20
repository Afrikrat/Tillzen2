import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database.dart';
import 'package:drift/drift.dart' as drift;

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Intelligence', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales by Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _CategorySalesChart(db: db),
            const SizedBox(height: 32),
            const Text('Daily Reconciliation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _DailyReconciliation(db: db),
          ],
        ),
      ),
    );
  }
}

class _CategorySalesChart extends StatelessWidget {
  final AppDatabase db;
  const _CategorySalesChart({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<drift.TypedResult>>(
      future: db.getCategorySales(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No sales data yet'))));

        return AspectRatio(
          aspectRatio: 1.5,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.fold<double>(0, (max, row) {
                    final val = row.read<double>(db.saleItems.unitPrice.sum()) ?? 0;
                    return val > max ? val : max;
                  }) * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(data[value.toInt()].read(db.products.category) ?? 'Other', style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final total = row.read<double>(db.saleItems.unitPrice.sum()) ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          color: Theme.of(context).colorScheme.primary,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DailyReconciliation extends StatelessWidget {
  final AppDatabase db;
  const _DailyReconciliation({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<drift.TypedResult>>(
      future: db.getDailyReconciliation(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        
        return Column(
          children: data.map((row) {
            final method = row.read(db.sales.paymentMethod) ?? 'Unknown';
            final total = row.read<double>((db.sales.totalAmount + db.sales.taxAmount).sum()) ?? 0;
            
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: method == 'Cash' ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Icon(method == 'Cash' ? Icons.money : Icons.phone_android, color: method == 'Cash' ? Colors.green : Colors.blue),
                ),
                title: Text(method, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Today\'s Total'),
                trailing: Text('GHS ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
