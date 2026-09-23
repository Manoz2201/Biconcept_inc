import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/appwrite/row_permissions.dart';
import '../../payments/domain/payment.dart';
import '../domain/invoice.dart';

class InvoicePdfBuilder {
  Future<Uint8List> generatePdf(
    Invoice invoice, {
    String? clientName,
    String? firmName,
    String? firmGstin,
    String? clientGstin,
  }) async {
    final doc = pw.Document(title: invoice.invoiceNumber, author: firmName ?? 'BiConcept');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(invoice.invoiceNumber),
          pw.Text('Date ${formatDisplayDate(invoice.invoiceDate)} · Due ${formatDisplayDate(invoice.dueDate)}'),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('From', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(firmName ?? 'BiConcept'),
                    if (firmGstin != null && firmGstin.isNotEmpty) pw.Text('GSTIN $firmGstin'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill to', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(clientName ?? invoice.clientId),
                    if (clientGstin != null && clientGstin.isNotEmpty) pw.Text('GSTIN $clientGstin'),
                    pw.Text('Place of supply: ${invoice.placeOfSupply} (${invoice.placeOfSupplyCode})'),
                    pw.Text(invoice.isInterState ? 'IGST (inter-state)' : 'CGST + SGST (intra-state)'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'HSN/SAC', 'Qty', 'Rate', 'Taxable', 'CGST', 'SGST', 'IGST', 'Total'],
            data: [
              for (final item in invoice.items)
                [
                  item.description,
                  item.hsnSac,
                  item.quantity.toString(),
                  formatMoney(item.rate),
                  formatMoney(item.taxableValue),
                  formatMoney(item.cgst),
                  formatMoney(item.sgst),
                  formatMoney(item.igst),
                  formatMoney(item.total),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal  ${formatMoney(invoice.subtotal)}'),
                pw.Text('CGST  ${formatMoney(invoice.totalCgst)}'),
                pw.Text('SGST  ${formatMoney(invoice.totalSgst)}'),
                pw.Text('IGST  ${formatMoney(invoice.totalIgst)}'),
                if (invoice.roundOff != 0) pw.Text('Round off  ${formatMoney(invoice.roundOff)}'),
                pw.Text('Grand total  ${formatMoney(invoice.grandTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(invoice.amountInWords),
          if (invoice.bankDetails != null) ...[
            pw.SizedBox(height: 12),
            pw.Text('Bank details'),
            pw.Text(invoice.bankDetails!),
          ],
          if (invoice.termsAndConditions != null) ...[
            pw.SizedBox(height: 12),
            pw.Text('Terms'),
            pw.Text(invoice.termsAndConditions!),
          ],
        ],
      ),
    );
    return doc.save();
  }

  Future<void> sharePdf(
    Invoice invoice, {
    String? clientName,
    String? firmName,
    String? firmGstin,
    String? clientGstin,
  }) async {
    final bytes = await generatePdf(
      invoice,
      clientName: clientName,
      firmName: firmName,
      firmGstin: firmGstin,
      clientGstin: clientGstin,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber.replaceAll('/', '-')}.pdf');
  }

  Future<Uint8List> generateReceipt(Invoice invoice, Payment payment) async {
    final doc = pw.Document(title: payment.receiptNumber ?? payment.paymentNumber, author: 'BiConcept');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text(payment.receiptNumber ?? payment.paymentNumber),
            pw.SizedBox(height: 12),
            pw.Text('Invoice ${invoice.invoiceNumber}'),
            pw.Text('Date ${formatDisplayDate(payment.paymentDate)}'),
            pw.Text('Method ${payment.paymentMethod.label}'),
            pw.Text('Amount ${formatMoney(payment.amount)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('BiConcept'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> shareBytes(Uint8List bytes, String filename) {
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
