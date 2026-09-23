import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/appwrite/appwrite_client.dart';
import '../../../core/appwrite/row_permissions.dart';
import '../../../core/result/app_result.dart';
import '../../auth/domain/user.dart';
import '../domain/quotation.dart';

class QuotationPdfService {
  Future<Uint8List> generatePdf(Quotation quotation, User client) async {
    final doc = pw.Document(title: quotation.quotationNumber, author: 'BiConcept');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('BiConcept', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Quotation ${quotation.quotationNumber}'),
          if (quotation.revisionNumber > 0) pw.Text('Revision ${quotation.revisionNumber}'),
          pw.SizedBox(height: 16),
          pw.Text('Client: ${client.name}'),
          pw.Text(client.email),
          pw.SizedBox(height: 8),
          pw.Text('Issued: ${quotation.createdAt == null ? '—' : formatDisplayDate(quotation.createdAt!)}'),
          pw.Text('Valid until: ${formatDisplayDate(quotation.validUntil)}'),
          pw.SizedBox(height: 16),
          pw.Text(quotation.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Description', 'Qty', 'Unit price', 'Total'],
            data: [
              for (final item in quotation.items)
                [
                  item.description,
                  item.quantity.toString(),
                  formatMoney(item.unitPrice),
                  formatMoney(item.total),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal  ${formatMoney(quotation.subtotal)}'),
                pw.Text('GST ${quotation.taxRate.toStringAsFixed(0)}%  ${formatMoney(quotation.taxAmount)}'),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Total  ${formatMoney(quotation.total)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> sharePdf(Quotation quotation, User client) async {
    final bytes = await generatePdf(quotation, client);
    await Printing.sharePdf(bytes: bytes, filename: '${quotation.quotationNumber}.pdf');
  }

  Future<AppResult<Uint8List>> fromFunctionOrLocal(Quotation quotation, User client) {
    return AppwriteService.guard(() async {
      try {
        final execution = await AppwriteService.functions.createExecution(
          functionId: AppwriteService.generateQuotationPdfFn,
          body: '{"quotationId":"${quotation.id}"}',
        );
        final body = execution.responseBody;
        if (body.isNotEmpty && execution.responseStatusCode == 200) {
          return Uint8List.fromList(body.codeUnits);
        }
      } catch (_) {}
      return generatePdf(quotation, client);
    });
  }
}
