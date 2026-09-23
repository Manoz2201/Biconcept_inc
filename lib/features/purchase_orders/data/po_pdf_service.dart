import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/appwrite/row_permissions.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

class PoPdfService implements PurchaseOrderPdfService {
  @override
  Future<Uint8List> generatePdf(PurchaseOrder order, {String? vendorName, String? projectTitle}) async {
    final doc = pw.Document(title: order.poNumber, author: 'BiConcept');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(order.poNumber),
          pw.SizedBox(height: 12),
          pw.Text('Vendor: ${vendorName ?? order.vendorId}'),
          pw.Text('Project: ${projectTitle ?? order.projectId}'),
          pw.Text('Delivery: ${formatDisplayDate(order.deliveryDate)}'),
          pw.Text('Status: ${order.status.label}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Qty', 'Unit', 'Rate', 'Total'],
            data: [
              for (final item in order.items)
                [item.itemName, item.quantity.toString(), item.unit, formatMoney(item.rate), formatMoney(item.total)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal  ${formatMoney(order.subtotal)}'),
                pw.Text('GST ${order.taxRate.toStringAsFixed(0)}%  ${formatMoney(order.taxAmount)}'),
                pw.Text('Total  ${formatMoney(order.total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          if (order.notes != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('Notes'),
            pw.Text(order.notes!),
          ],
          pw.SizedBox(height: 24),
          pw.Text('BiConcept', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<void> sharePdf(PurchaseOrder order, {String? vendorName, String? projectTitle}) async {
    final bytes = await generatePdf(order, vendorName: vendorName, projectTitle: projectTitle);
    await Printing.sharePdf(bytes: bytes, filename: '${order.poNumber}.pdf');
  }
}
