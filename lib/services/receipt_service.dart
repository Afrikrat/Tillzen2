import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  static Future<File> generateReceiptPdf({
    required Sale sale,
    required List<SaleItemEnriched> items,
    required String shopName,
    required String shopId,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp);

    // Ghana Tax Calculations (re-validated from CartProvider)
    final subtotal = items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
    final nhil = subtotal * 0.025;
    final getFund = subtotal * 0.025;
    final vat = subtotal * 0.150;
    final totalTax = nhil + getFund + vat;
    final grandTotal = subtotal + totalTax;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text('Shop ID: $shopId', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('OFFICIAL RECEIPT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.Text('Date: $dateStr'),
              pw.Text('Receipt #: ${sale.id}'),
              pw.Text('Payment: ${sale.paymentMethod}'),
              if (sale.transactionId != null) pw.Text('Ref: ${sale.transactionId}'),
              pw.Divider(),
              pw.Table(
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Text(item.productName),
                      pw.Text('${item.quantity}'),
                      pw.Text(item.unitPrice.toStringAsFixed(2)),
                      pw.Text((item.unitPrice * item.quantity).toStringAsFixed(2)),
                    ],
                  )),
                ],
              ),
              pw.Divider(),
              _pdfRow('Subtotal', subtotal),
              _pdfRow('NHIL (2.5%)', nhil),
              _pdfRow('GETFund (2.5%)', getFund),
              _pdfRow('VAT (15%)', vat),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('GHS ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Thank you for shopping at $shopName!')),
              pw.Center(child: pw.Text('Tillzen POS - Ghana Retail Engine', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt_${sale.id}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _pdfRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value.toStringAsFixed(2)),
        ],
      ),
    );
  }

  static Future<void> shareReceipt(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Tillzen POS Receipt');
  }

  static Future<List<int>> formatForThermalPrinter({
    required Sale sale,
    required List<SaleItemEnriched> items,
    required String shopName,
  }) async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    bytes += generator.text(shopName, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text('OFFICIAL RECEIPT', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.text('Date: ${DateFormat('dd-MM-yy HH:mm').format(sale.timestamp)}');
    bytes += generator.text('ID: ${sale.id} | ${sale.paymentMethod}');
    bytes += generator.hr();

    for (final item in items) {
      bytes += generator.row([
        PosColumn(text: item.productName, width: 6),
        PosColumn(text: 'x${item.quantity}', width: 2),
        PosColumn(text: (item.unitPrice * item.quantity).toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 8),
      PosColumn(text: sale.totalAmount.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Taxes', width: 8),
      PosColumn(text: sale.taxAmount.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'GHS ${(sale.totalAmount + sale.taxAmount).toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}

class SaleItemEnriched {
  final String productName;
  final int quantity;
  final double unitPrice;

  SaleItemEnriched({required this.productName, required this.quantity, required this.unitPrice});
}
