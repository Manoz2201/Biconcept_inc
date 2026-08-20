import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

const kAgentDocMaxBytes = 12 * 1024 * 1024;
const kAgentDocMaxChars = 24000;

/// Extracted PDF / Word / Excel text for the agent.
class DocumentExtract {
  const DocumentExtract({
    required this.name,
    required this.kind,
    required this.text,
    this.bytes = 0,
  });

  final String name;
  final String kind;
  final String text;
  final int bytes;

  bool get isEmpty => text.trim().isEmpty;
}

class DocumentReadException implements Exception {
  DocumentReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DocumentReader {
  static const kinds = ['pdf', 'word', 'excel'];

  static String kindForName(String name) {
    final ext = extensionOf(name);
    return switch (ext) {
      'pdf' => 'pdf',
      'doc' || 'docx' => 'word',
      'xls' || 'xlsx' || 'xlsm' || 'csv' => 'excel',
      _ => '',
    };
  }

  static String extensionOf(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    if (dot < 0 || dot == base.length - 1) return '';
    return base.substring(dot + 1).toLowerCase();
  }

  static Future<DocumentExtract> fromFile(File file, {String? name}) async {
    final label = name ?? file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    return fromBytes(bytes, label);
  }

  static DocumentExtract fromBytes(List<int> bytes, String name) {
    if (bytes.length > kAgentDocMaxBytes) {
      throw DocumentReadException(
        '“$name” is larger than ${kAgentDocMaxBytes ~/ (1024 * 1024)} MB.',
      );
    }
    final kind = kindForName(name);
    if (kind.isEmpty) {
      throw DocumentReadException('Attach a PDF, Word (.docx), or Excel (.xlsx) file.');
    }
    final ext = extensionOf(name);
    if (ext == 'doc') {
      throw DocumentReadException('Old .doc files are not supported. Save as .docx and attach again.');
    }
    if (ext == 'xls') {
      throw DocumentReadException('Old .xls files are not supported. Save as .xlsx and attach again.');
    }

    final raw = switch (kind) {
      'pdf' => extractPdf(bytes),
      'word' => extractDocx(bytes),
      'excel' => ext == 'csv' ? extractCsv(bytes) : extractXlsx(bytes),
      _ => '',
    };
    final text = _cap(raw.trim());
    if (text.isEmpty) {
      throw DocumentReadException(
        kind == 'pdf'
            ? 'Could not read text from “$name”. If it is a scanned image PDF, export it as a text PDF, Word, or Excel and attach that.'
            : 'Could not read text from “$name”. Empty sheets cannot be summarized.',
      );
    }
    return DocumentExtract(name: name, kind: kind, text: text, bytes: bytes.length);
  }

  static String extractPdf(List<int> bytes) {
    return _PdfExtractor(Uint8List.fromList(bytes)).extract();
  }

  static String extractDocx(List<int> bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      throw DocumentReadException('That Word file could not be opened. Use a .docx file.');
    }
    final parts = <String>[];
    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/').toLowerCase();
      if (!file.isFile) continue;
      if (name == 'word/document.xml' ||
          name.startsWith('word/header') && name.endsWith('.xml') ||
          name.startsWith('word/footer') && name.endsWith('.xml')) {
        final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
        parts.add(_xmlToText(xml));
      }
    }
    return _clean(_joinKeepLines(parts));
  }

  static String extractXlsx(List<int> bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw DocumentReadException('That Excel file could not be opened. Use a .xlsx file.');
    }
    final lines = <String>[];
    for (final name in excel.tables.keys) {
      final sheet = excel.tables[name];
      if (sheet == null) continue;
      lines.add('Sheet: $name');
      for (final row in sheet.rows) {
        final cells = [
          for (final cell in row)
            if (cell != null && cell.value != null) _cellText(cell.value),
        ].where((item) => item.isNotEmpty).toList();
        if (cells.isNotEmpty) lines.add(cells.join('\t'));
      }
    }
    return _clean(lines.join('\n'));
  }

  static String extractCsv(List<int> bytes) {
    return _clean(utf8.decode(bytes, allowMalformed: true));
  }

  static String _cellText(Object? value) {
    if (value == null) return '';
    if (value is TextCellValue) {
      final span = value.value;
      return [
        if (span.text != null) span.text!,
        for (final child in span.children ?? const <TextSpan>[])
          if (child.text != null) child.text!,
      ].join();
    }
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();
    if (value is DateCellValue) return value.toString();
    if (value is FormulaCellValue) return value.formula;
    return value.toString();
  }

  static String _xmlToText(String xml) {
    var text = xml.replaceAll(RegExp(r'</w:p>'), '\n');
    text = text.replaceAll(RegExp(r'<w:tab[^/]*/>'), '\t');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code == null) return '';
      return String.fromCharCode(code);
    });
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code == null) return '';
      return String.fromCharCode(code);
    });
    return text;
  }

  static String _joinKeepLines(List<String> parts) {
    return parts.where((item) => item.trim().isNotEmpty).join('\n');
  }

  static String _clean(String text) {
    var value = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    value = value.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    value = value.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    value = value.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return value.trim();
  }

  static String _cap(String text) {
    if (text.length <= kAgentDocMaxChars) return text;
    return '${text.substring(0, kAgentDocMaxChars)}\n…[truncated]';
  }
}

class _PdfExtractor {
  _PdfExtractor(this.data);

  final Uint8List data;
  final Map<int, String> _cmap = {};

  String extract() {
    final inflated = <String>[];
    var cursor = 0;
    while (true) {
      final start = _keywordIndex('stream', cursor);
      if (start < 0) break;
      if (!_hasDictBefore(start)) {
        cursor = start + 6;
        continue;
      }
      final dict = _dictBefore(start);
      var payloadStart = start + 6;
      if (payloadStart < data.length && data[payloadStart] == 13) payloadStart++;
      if (payloadStart < data.length && data[payloadStart] == 10) payloadStart++;
      final end = _keywordIndex('endstream', payloadStart);
      if (end < 0) break;
      var payloadEnd = end;
      if (payloadEnd > payloadStart && data[payloadEnd - 1] == 10) payloadEnd--;
      if (payloadEnd > payloadStart && data[payloadEnd - 1] == 13) payloadEnd--;
      if (payloadEnd < payloadStart) {
        cursor = end + 9;
        continue;
      }
      if (dict.contains('/DCTDecode') ||
          dict.contains('/JPXDecode') ||
          dict.contains('/CCITTFaxDecode') ||
          dict.contains('/JBIG2Decode')) {
        cursor = end + 9;
        continue;
      }
      var payload = data.sublist(payloadStart, payloadEnd);
      if (_isFlate(dict)) {
        payload = _inflate(payload) ?? payload;
      }
      final content = latin1.decode(payload, allowInvalid: true);
      _ingestCmap(content);
      inflated.add(content);
      cursor = end + 9;
    }

    final texts = <String>[
      for (final content in inflated) _stringsFromContent(content),
    ];
    var result = DocumentReader._clean(DocumentReader._joinKeepLines(texts));
    if (result.trim().isEmpty) {
      result = DocumentReader._clean(_printableRuns(inflated));
    }
    if (result.trim().isEmpty) {
      result = DocumentReader._clean(_stringsFromContent(latin1.decode(data, allowInvalid: true)));
    }
    return result;
  }

  bool _isFlate(String dict) => dict.contains('FlateDecode');

  Uint8List? _inflate(Uint8List payload) {
    try {
      return Uint8List.fromList(ZLibCodec().decode(payload));
    } catch (_) {}
    try {
      return Uint8List.fromList(ZLibCodec(raw: true).decode(payload));
    } catch (_) {}
    try {
      return Uint8List.fromList(Inflate(payload).getBytes());
    } catch (_) {}
    return null;
  }

  void _ingestCmap(String content) {
    if (!content.contains('beginbfchar') && !content.contains('beginbfrange')) return;
    for (final match in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>').allMatches(content)) {
      final src = int.tryParse(match.group(1) ?? '', radix: 16);
      final dst = match.group(2) ?? '';
      if (src == null || dst.isEmpty) continue;
      _cmap[src] = _utfFromHex(dst);
    }
  }

  String _stringsFromContent(String content) {
    final out = StringBuffer();
    void add(String piece) {
      final text = piece.trimRight();
      if (text.isEmpty) return;
      if (out.isNotEmpty) out.write(' ');
      out.write(text);
    }

    for (final match in RegExp(r'\((?:\\.|[^\\)])*\)').allMatches(content)) {
      final raw = match.group(0) ?? '';
      if (raw.length < 3) continue;
      add(_decodeLiteral(raw.substring(1, raw.length - 1)));
    }
    for (final match in RegExp(r'<([0-9A-Fa-f \t\r\n]+)>').allMatches(content)) {
      add(_decodeHex(match.group(1) ?? ''));
    }
    return out.toString();
  }

  String _decodeLiteral(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch != r'\') {
        out.write(ch);
        continue;
      }
      if (i + 1 >= raw.length) break;
      final next = raw[i + 1];
      switch (next) {
        case 'n':
          out.write('\n');
          i++;
        case 'r':
          out.write('\r');
          i++;
        case 't':
          out.write('\t');
          i++;
        case '(':
        case ')':
        case r'\':
          out.write(next);
          i++;
        default:
          if (RegExp(r'[0-7]').hasMatch(next)) {
            final grab = StringBuffer();
            var j = i + 1;
            while (j < raw.length && grab.length < 3 && RegExp(r'[0-7]').hasMatch(raw[j])) {
              grab.write(raw[j]);
              j++;
            }
            out.writeCharCode(int.parse(grab.toString(), radix: 8));
            i = j - 1;
          } else {
            i++;
          }
      }
    }
    final bytes = latin1.encode(out.toString());
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2) (bytes[i] << 8) | bytes[i + 1],
      ]);
    }
    return out.toString();
  }

  String _decodeHex(String raw) {
    final hex = raw.replaceAll(RegExp(r'\s'), '');
    if (hex.isEmpty || hex.length.isOdd) {
      final padded = hex.length.isOdd ? '${hex}0' : hex;
      return _hexToText(padded);
    }
    return _hexToText(hex);
  }

  String _hexToText(String hex) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    if (_cmap.isNotEmpty) {
      final mapped = StringBuffer();
      var i = 0;
      while (i < bytes.length) {
        var code = bytes[i];
        var width = 1;
        if (i + 1 < bytes.length) {
          final two = (bytes[i] << 8) | bytes[i + 1];
          if (_cmap.containsKey(two)) {
            code = two;
            width = 2;
          }
        }
        mapped.write(_cmap[code] ?? '');
        i += width;
      }
      final text = mapped.toString();
      if (text.trim().isNotEmpty) return text;
    }
    if (bytes.length >= 2 && bytes.every((b) => b == 0 || b >= 0x20 || b == 0x0a)) {
      final asUtf16 = StringBuffer();
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        asUtf16.writeCharCode((bytes[i] << 8) | bytes[i + 1]);
      }
      final utf16 = asUtf16.toString();
      if (RegExp(r'[A-Za-z0-9]').hasMatch(utf16)) return utf16;
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  String _utfFromHex(String hex) {
    final padded = hex.length.isOdd ? '0$hex' : hex;
    if (padded.length <= 4) {
      final code = int.tryParse(padded, radix: 16);
      if (code == null || code == 0) return '';
      return String.fromCharCode(code);
    }
    final out = StringBuffer();
    for (var i = 0; i + 3 < padded.length; i += 4) {
      final code = int.tryParse(padded.substring(i, i + 4), radix: 16);
      if (code == null || code == 0) continue;
      out.writeCharCode(code);
    }
    return out.toString();
  }

  String _printableRuns(List<String> inflated) {
    final out = StringBuffer();
    final skip = {
      'stream', 'endstream', 'endobj', 'obj', 'BT', 'ET', 'Tf', 'Td', 'TD', 'Tm', 'Tj', 'TJ',
      'Filter', 'FlateDecode', 'Length', 'Type', 'Font', 'Page', 'Pages', 'Catalog',
    };
    for (final content in inflated) {
      for (final match in RegExp(r"[A-Za-z0-9₹./,&:%#+\-()]{4,}").allMatches(content)) {
        final piece = match.group(0) ?? '';
        if (skip.contains(piece)) continue;
        if (RegExp(r'^[A-Za-z]{1,2}$').hasMatch(piece)) continue;
        if (out.isNotEmpty) out.write(' ');
        out.write(piece);
      }
    }
    return out.toString();
  }

  bool _hasDictBefore(int streamAt) {
    var i = streamAt - 1;
    while (i >= 0 && (data[i] == 32 || data[i] == 9 || data[i] == 10 || data[i] == 13)) {
      i--;
    }
    return i >= 1 && data[i] == 0x3e && data[i - 1] == 0x3e;
  }

  String _dictBefore(int streamAt) {
    final start = _lastIndex('<<', streamAt);
    if (start < 0 || streamAt - start > 8000) return '';
    return latin1.decode(data.sublist(start, streamAt), allowInvalid: true);
  }

  int _keywordIndex(String word, int start) {
    final target = ascii.encode(word);
    outer:
    for (var i = start; i <= data.length - target.length; i++) {
      for (var j = 0; j < target.length; j++) {
        if (data[i + j] != target[j]) continue outer;
      }
      if (i > 0 && _isWord(data[i - 1])) continue;
      if (i + target.length < data.length && _isWord(data[i + target.length])) continue;
      return i;
    }
    return -1;
  }

  int _lastIndex(String needle, int end) {
    final target = ascii.encode(needle);
    outer:
    for (var i = end - target.length; i >= 0; i--) {
      for (var j = 0; j < target.length; j++) {
        if (data[i + j] != target[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  bool _isWord(int byte) =>
      (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122);
}

