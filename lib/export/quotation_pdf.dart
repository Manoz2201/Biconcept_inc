import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/config/env.dart';
import '../data/local_cache.dart';
import '../features/catalog/data/storage_repository.dart';
import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../util/format.dart';
import '../util/save_export.dart';
import 'quotation_layout.dart';

class QuotationPdf {
  static const _black = PdfColor.fromInt(0xFF000000);
  static const _ink = PdfColor.fromInt(0xFF111111);
  static const _muted = PdfColor.fromInt(0xFFB5B5B5);
  static const _teal = PdfColor.fromInt(0xFF2EC4B6);
  static const _row = PdfColor.fromInt(0xFFF4F4F4);
  static const _head = PdfColor.fromInt(0xFF111111);
  static const _type = PdfColor.fromInt(0xFFE6E6E6);
  static const _letterheadHeight = 88.0;
  static const _sidebarWidth = 176.0;

  static String fileName(EstimateDraft draft) =>
      '${estimateExportStem(draft.client, draft.id, quotationDate(draft.date))}.pdf';

  Future<File> export(EstimateDraft draft) async {
    final bytes = await buildBytes(draft);
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/biconcept/exports');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final file = File('${outDir.path}/${fileName(draft)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> buildBytes(EstimateDraft draft) async {
    final logo = await _logo();
    final address = await _companyAddress(draft);
    final phone = await _companyPhone(draft);
    final lineImages = await _lineImages(draft);
    final sections = groupQuotation(draft);
    final totals = draft.totals;
    final doc = pw.Document(title: 'Estimate - ${draft.client}', author: draft.brand);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(_sidebarWidth + 10, _letterheadHeight, 12, 22),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          buildBackground: (context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Column(
                children: [
                  _letterhead(draft, logo, address, phone),
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        context.pageNumber == 1
                            ? _sidebar(draft, sections, totals)
                            : pw.Container(width: _sidebarWidth, color: _black),
                        pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: _ink, fontSize: 8),
            ),
          ),
        ),
        build: (context) => [
          _table(sections, lineImages),
          ..._termsBelowTable(draft),
        ],
      ),
    );
    return doc.save();
  }

  Future<String> _companyAddress(EstimateDraft draft) async {
    String? prefsAddress;
    try {
      prefsAddress = (await LocalCache.instance.loadPrefs()).companyAddress;
    } catch (_) {}
    return resolveCompanyAddress(prefsAddress: prefsAddress, draftAddress: draft.companyAddress);
  }

  Future<String> _companyPhone(EstimateDraft draft) async {
    String? prefsPhone;
    try {
      prefsPhone = (await LocalCache.instance.loadPrefs()).companyPhone;
    } catch (_) {}
    return resolveCompanyPhone(prefsPhone: prefsPhone, draftPhone: draft.companyPhone);
  }

  Future<pw.ImageProvider?> _logo() async {
    try {
      final data = await rootBundle.load(estimateCompanyLogoAsset);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _letterhead(EstimateDraft draft, pw.ImageProvider? logo, String address, String phone) {
    return pw.Container(
      height: _letterheadHeight,
      width: double.infinity,
      padding: pw.EdgeInsets.zero,
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E2E2), width: 0.8)),
      ),
      child: pw.Stack(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 220,
                    height: _letterheadHeight * 0.85,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(
                      logo,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.centerLeft,
                    ),
                  )
                else
                  pw.SizedBox(height: _letterheadHeight * 0.85),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      draft.estimateTypeHeading,
                      style: pw.TextStyle(color: _teal, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
                    ),
                    pw.SizedBox(height: 8),
                    _headingDetail('CLIENT', pdfSafe(draft.client.toUpperCase())),
                    if (draft.project.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      _headingDetail('PROJECT', pdfSafe(draft.project.toUpperCase())),
                    ],
                    pw.SizedBox(height: 4),
                    _headingDetail('DATE', quotationDate(draft.date)),
                  ],
                ),
              ],
            ),
          ),
          pw.Positioned(
            left: 16,
            right: 16,
            bottom: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  pdfSafe(address),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF555555),
                    fontSize: 9,
                    lineSpacing: 1.2,
                  ),
                  maxLines: 2,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  pdfSafe(companyContactLine(phone)),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF555555),
                    fontSize: 9,
                    lineSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _headingDetail(String label, String value) {
    return pw.RichText(
      textAlign: pw.TextAlign.right,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(color: _teal, fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value, style: const pw.TextStyle(color: _ink, fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _sidebar(
    EstimateDraft draft,
    List<QuotationSection> sections,
    EstimateTotals totals,
  ) {
    return pw.Container(
      width: _sidebarWidth,
      color: _black,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 10, 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ESTIMATE',
            style: pw.TextStyle(color: _teal, fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 1.0),
          ),
          pw.SizedBox(height: 10),
          for (var i = 0; i < sections.length; i++) ...[
            pw.Text(
              sections[i].workType.toUpperCase(),
              style: const pw.TextStyle(color: _muted, fontSize: 6.5),
            ),
            _totalLine('TOTAL (${sections[i].serialNo})', sections[i].total),
            pw.SizedBox(height: 4),
          ],
          pw.Container(
            height: 0.6,
            color: PdfColor.fromInt(0xFF333333),
            margin: const pw.EdgeInsets.symmetric(vertical: 5),
          ),
          _totalLine('GRAND TOTAL', totals.subtotal, emphasize: true),
          pw.SizedBox(height: 3),
          _totalLine('GST ${draft.gstPercent.toStringAsFixed(0)}%', totals.gst18),
          if (totals.hvacTaxable > 0) ...[
            pw.SizedBox(height: 3),
            _totalLine('GST ${draft.hvacGstPercent.toStringAsFixed(0)}% ON HVAC', totals.gst28),
          ],
          pw.SizedBox(height: 3),
          _totalLine('TOTAL PROJECT COST WITH GST', totals.grandTotal, emphasize: true, accent: true),
          pw.SizedBox(height: 3),
          _totalLine(
            'TOTAL (1 TO ${sections.isEmpty ? 0 : sections.last.serialNo})',
            totals.grandTotal,
            emphasize: true,
          ),
          pw.Spacer(),
        ],
      ),
    );
  }

  pw.Widget _totalLine(String label, double value, {bool emphasize = false, bool accent = false}) {
    final color = accent ? _teal : PdfColors.white;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(color: color, fontSize: emphasize ? 8 : 7.5, fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
        pw.Text(
          indianGrouped(value, decimals: 2),
          style: pw.TextStyle(color: color, fontSize: emphasize ? 8.5 : 8, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  List<pw.Widget> _termsBelowTable(EstimateDraft draft) {
    final terms = draft.effectiveTerms;
    if (terms.isEmpty) return const [];
    return [
      pw.SizedBox(height: 50),
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'OTHER TERMS AND CONDITIONS-',
              style: pw.TextStyle(color: _teal, fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            for (var i = 0; i < terms.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  '${i + 1}. ${pdfSafe(terms[i])}',
                  style: const pw.TextStyle(color: _ink, fontSize: 8, lineSpacing: 1.25),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Future<Map<String, pw.MemoryImage>> _lineImages(EstimateDraft draft) async {
    final storage = StorageRepositoryImpl();
    final images = <String, pw.MemoryImage>{};
    for (final line in draft.lines) {
      final fileId = line.imageFileId?.trim();
      if (fileId == null || fileId.isEmpty) continue;
      try {
        final url = storage.getFileViewUrl(Env.portfolioImagesBucket, fileId);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          images[line.id] = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }
    return images;
  }

  pw.Widget _table(List<QuotationSection> sections, Map<String, pw.MemoryImage> lineImages) {
    final rows = <pw.TableRow>[
      _headerRow(),
    ];
    var stripe = false;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final no = section.serialNo;
      rows.add(_spanRow('$no', section.workType.toUpperCase(), fill: _type, bold: true));
      for (final block in section.blocks) {
        if (block.area != null && block.area!.trim().isNotEmpty) {
          rows.add(_spanRow(block.areaCode ?? '', block.area!.toUpperCase(), fill: const PdfColor.fromInt(0xFFEEEEEE), bold: true));
        }
        for (final line in block.lines) {
          rows.add(_lineRow(line, stripe: stripe, image: lineImages[line.id]));
          stripe = !stripe;
        }
      }
      rows.add(_totalRow('TOTAL ($no)', section.total));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.4),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FixedColumnWidth(36),
        4: pw.FixedColumnWidth(36),
        5: pw.FixedColumnWidth(34),
        6: pw.FixedColumnWidth(50),
        7: pw.FixedColumnWidth(50),
        8: pw.FixedColumnWidth(36),
        9: pw.FixedColumnWidth(56),
      },
      children: rows,
    );
  }

  pw.TableRow _headerRow() {
    const labels = [
      'S.NO.',
      'WORK TYPE',
      'DESCRIPTION',
      'PICTURE',
      'UNIT',
      'QTY',
      'UNIT RATE',
      'PRICE',
      'DISC %',
      'NET PRICE',
    ];
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        for (var i = 0; i < labels.length; i++)
          _cell(labels[i], header: true, align: i >= 4 ? pw.TextAlign.right : pw.TextAlign.left),
      ],
    );
  }

  pw.TableRow _spanRow(String code, String title, {required PdfColor fill, bool bold = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: fill),
      children: [
        _cell(code, bold: bold),
        _cell(title, bold: bold),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
      ],
    );
  }

  pw.TableRow _lineRow(EstimateLine line, {required bool stripe, pw.MemoryImage? image}) {
    final lumpsum = line.unit.toLowerCase().contains('sum');
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: stripe ? _row : PdfColors.white),
      children: [
        _cell((line.workScopeCode ?? '').toUpperCase()),
        _cell(scopeTitle(line)),
        _cell(scopeDetails(line)),
        _pictureCell(image),
        _cell(unitLabel(line.unit), align: pw.TextAlign.right),
        _cell(lumpsum && (line.effectiveQuantity == null || line.effectiveQuantity == 1) ? 'lumsum' : formatQty(line.effectiveQuantity), align: pw.TextAlign.right),
        _cell(line.unitRate == null ? '' : indianGrouped(line.unitRate), align: pw.TextAlign.right),
        _cell(line.price == 0 ? '' : indianGrouped(line.price), align: pw.TextAlign.right),
        _cell(line.discountPercent == 0 ? '' : formatQty(line.discountPercent), align: pw.TextAlign.right),
        _cell(line.netPrice == 0 ? '' : indianGrouped(line.netPrice), align: pw.TextAlign.right, bold: true),
      ],
    );
  }

  pw.Widget _pictureCell(pw.MemoryImage? image) {
    if (image == null) {
      return _cell('');
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Container(
        height: 28,
        alignment: pw.Alignment.center,
        child: pw.Image(image, fit: pw.BoxFit.cover),
      ),
    );
  }

  pw.TableRow _totalRow(String label, double value) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A1A1A)),
      children: [
        _cell(''),
        _cell(label, header: true, bold: true),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(indianGrouped(value, decimals: 2), header: true, bold: true, align: pw.TextAlign.right),
      ],
    );
  }

  pw.Widget _cell(
    String text, {
    bool header = false,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        pdfSafe(text),
        style: pw.TextStyle(
          color: header ? PdfColors.white : _ink,
          fontSize: header ? 6.8 : 6.5,
          fontWeight: bold || header ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 1.15,
        ),
        textAlign: align,
      ),
    );
  }
}
