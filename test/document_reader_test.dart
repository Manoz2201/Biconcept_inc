import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:biconcept/agent/document_reader.dart';
import 'package:biconcept/data/agent_session_store.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('extracts text from an uncompressed PDF stream', () {
    const raw = '''
%PDF-1.1
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
endobj
4 0 obj
<< /Length 48 >>
stream
BT /F1 12 Tf 10 100 Td (Gypsum partition) Tj ET
endstream
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
trailer
<< /Root 1 0 R >>
%%EOF
''';
    final text = DocumentReader.extractPdf(ascii.encode(raw));
    expect(text.toLowerCase(), contains('gypsum'));
  });

  test('extracts text from a package:pdf Helvetica document', () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Text('DEV X ESTIMATE gypsum partition'),
      ),
    );
    final bytes = await doc.save();
    final text = DocumentReader.extractPdf(bytes);
    expect(text.toLowerCase(), contains('estimate'));
    expect(text.toLowerCase(), contains('gypsum'));
  });

  test('extracts text from a docx zip', () {
    final xml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body><w:p><w:r><w:t>Site visit notes for OM CRE</w:t></w:r></w:p></w:body>
</w:document>
''';
    final archive = Archive()
      ..addFile(
        ArchiveFile('word/document.xml', xml.length, utf8.encode(xml)),
      );
    final bytes = ZipEncoder().encode(archive)!;
    final text = DocumentReader.extractDocx(bytes);
    expect(text, contains('OM CRE'));
  });

  test('extracts text from xlsx', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Client');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('ABC Interiors');
    final bytes = excel.encode()!;
    final text = DocumentReader.extractXlsx(bytes);
    expect(text, contains('ABC Interiors'));
  });

  test('session cache keeps chat and attachments locally', () async {
    final dir = Directory.systemTemp.createTempSync('agent_session_');
    final store = AgentSessionStore.instance;
    store.overrideDirectory = dir;
    store.loaded = false;
    addTearDown(() {
      store.overrideDirectory = null;
      store.loaded = false;
      store.messages.clear();
      store.documents.clear();
      store.pending.clear();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await store.ensureLoaded();
    await store.attachExtract(
      const DocumentExtract(name: 'notes.docx', kind: 'word', text: 'Follow up Tuesday'),
    );
    final pending = store.takePending();
    await store.addTurn(AgentChatTurn(text: 'Summarize this', user: true, attachments: pending));
    await store.addTurn(AgentChatTurn(text: 'Follow up is Tuesday.', user: false));
    store.saveSummary(store.documents.first.id, 'Follow up Tuesday');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final store2 = AgentSessionStore.instance;
    store2.loaded = false;
    store2.messages.clear();
    store2.documents.clear();
    await store2.ensureLoaded();
    expect(store2.messages.length, 2);
    expect(store2.messages.first.text, 'Summarize this');
    expect(store2.documents.single.text, contains('Tuesday'));
    expect(store2.documents.single.summary, contains('Tuesday'));
    expect(store2.llmHistory(), isNotEmpty);
  });
}
