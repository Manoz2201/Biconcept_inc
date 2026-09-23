import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/appwrite/row_permissions.dart';
import '../domain/tds_deduction.dart';

class TdsCertificateService {
  Future<Uint8List> form16A({
    required TDSDeduction tds,
    required String firmName,
    String? firmPan,
    String? firmTan,
  }) async {
    final doc = pw.Document(title: 'Form 16A ${tds.deducteeName}');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('FORM 16A', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Certificate under Section 203 of the Income-tax Act, 1961'),
            pw.SizedBox(height: 16),
            pw.Text('Certificate No: ${tds.certificateNumber ?? 'Pending'}'),
            pw.Text('Financial Year: ${tds.financialYear}  Quarter: ${tds.quarter}'),
            pw.Text('Section: ${tds.section.value}'),
            pw.SizedBox(height: 12),
            pw.Text('Deductor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(firmName),
            if (firmTan != null && firmTan.isNotEmpty) pw.Text('TAN $firmTan'),
            if (firmPan != null && firmPan.isNotEmpty) pw.Text('PAN $firmPan'),
            pw.SizedBox(height: 12),
            pw.Text('Deductee', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(tds.deducteeName),
            pw.Text('PAN ${tds.deducteePan}'),
            pw.SizedBox(height: 12),
            pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Gross ${formatMoney(tds.grossAmount)}'),
            pw.Text('TDS ${tds.tdsRate}% = ${formatMoney(tds.tdsAmount)}'),
            pw.Text('Net payable ${formatMoney(tds.netPayable)}'),
            pw.Text('Invoice ${formatDisplayDate(tds.invoiceDate)}'),
            if (tds.challanNumber != null) pw.Text('Challan ${tds.challanNumber}'),
            if (tds.challanDate != null) pw.Text('Challan date ${formatDisplayDate(tds.challanDate!)}'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<void> share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);
}
