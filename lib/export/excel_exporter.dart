import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../models/company_profile.dart';
import '../models/estimate_document.dart';
import '../data/local_cache.dart';
import 'quotation_layout.dart';

class ExcelExporter {
  Future<File> export(EstimateDraft draft) async {
    final excel = Excel.createExcel();
    final sheet = excel['Estimate'];
    excel.delete('Sheet1');

    var row = 0;
    void write(int c, Object? value) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      if (value == null || value.toString().isEmpty) {
        cell.value = TextCellValue('');
      } else if (value is num) {
        cell.value = DoubleCellValue(value.toDouble());
      } else {
        cell.value = TextCellValue(value.toString());
      }
    }

    String? prefsAddress;
    String? prefsPhone;
    try {
      final prefs = await LocalCache.instance.loadPrefs();
      prefsAddress = prefs.companyAddress;
      prefsPhone = prefs.companyPhone;
    } catch (_) {}
    final address = resolveCompanyAddress(
      prefsAddress: prefsAddress,
      draftAddress: draft.companyAddress,
    );
    final phone = resolveCompanyPhone(
      prefsPhone: prefsPhone,
      draftPhone: draft.companyPhone,
    );

    write(0, address);
    write(4, draft.estimateTypeHeading);
    row += 1;
    write(0, companyContactLine(phone));
    write(4, 'CLIENT: ${draft.client.toUpperCase()}');
    row += 1;
    if (draft.project.isNotEmpty) {
      write(4, 'PROJECT: ${draft.project.toUpperCase()}');
      row += 1;
    }
    write(4, 'DATE: ${quotationDate(draft.date)}');
    row += 2;
    write(0, 'S.NO.');
    write(1, 'WORK TYPE');
    write(2, 'DESCRIPTION');
    write(3, 'UNIT');
    write(4, 'QUANTITY');
    write(5, 'UNIT RATE');
    write(6, 'AMOUNT');
    row += 1;

    final sections = groupQuotation(draft);
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      write(0, section.serialNo);
      write(1, section.workType.toUpperCase());
      row += 1;
      for (final block in section.blocks) {
        if (block.area != null && block.area!.trim().isNotEmpty) {
          write(0, block.areaCode ?? '');
          write(1, block.area);
          row += 1;
        }
        for (final line in block.lines) {
          write(0, line.workScopeCode ?? '');
          write(1, scopeTitle(line));
          write(2, scopeDetails(line));
          write(3, unitLabel(line.unit));
          write(4, line.effectiveQuantity);
          write(5, line.unitRate);
          write(6, line.amount == 0 ? null : line.amount);
          row += 1;
        }
      }
      write(1, 'TOTAL (${section.serialNo})');
      write(6, section.total);
      row += 1;
    }

    final totals = draft.totals;
    row += 1;
    write(0, 'GRAND TOTAL');
    write(6, totals.subtotal);
    row += 1;
    write(0, 'GST ${draft.gstPercent.toStringAsFixed(0)}%');
    write(6, totals.gst18);
    if (totals.hvacTaxable > 0) {
      row += 1;
      write(0, 'GST ${draft.hvacGstPercent.toStringAsFixed(0)}% ON HVAC / AHU');
      write(6, totals.gst28);
    }
    row += 1;
    write(0, 'TOTAL PROJECT COST WITH GST');
    write(6, totals.grandTotal);
    row += 1;
    write(0, 'TOTAL (1 TO ${sections.length})');
    write(6, totals.grandTotal);
    row += 2;
    write(0, 'OTHER TERMS AND CONDITIONS-');
    row += 1;
    var n = 1;
    for (final term in draft.effectiveTerms) {
      write(0, '$n. $term');
      n += 1;
      row += 1;
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Excel encode failed');
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/biconcept/exports');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final safeClient = draft.client.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final name = 'estimate_${safeClient.isEmpty ? draft.id : safeClient}_${quotationDate(draft.date).replaceAll('/', '-')}.xlsx';
    final file = File('${outDir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
