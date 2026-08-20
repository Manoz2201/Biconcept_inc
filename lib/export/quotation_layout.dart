import '../models/estimate_document.dart';

class QuotationAreaBlock {
  const QuotationAreaBlock({this.areaCode, this.area, required this.lines});

  final String? areaCode;
  final String? area;
  final List<EstimateLine> lines;

  double get total => lines.fold(0, (sum, line) => sum + line.amount);
}

class QuotationSection {
  const QuotationSection({
    required this.serialNo,
    required this.workType,
    required this.blocks,
  });

  final int serialNo;
  final String workType;
  final List<QuotationAreaBlock> blocks;

  double get total => blocks.fold(0, (sum, block) => sum + block.total);

  List<EstimateLine> get lines => [for (final block in blocks) ...block.lines];
}

List<QuotationSection> groupQuotation(EstimateDraft draft) {
  final order = <String>[];
  final grouped = <String, List<EstimateLine>>{};
  for (final line in draft.lines) {
    final key = line.workTypeId.isNotEmpty ? line.workTypeId : 'name:${line.workType}';
    if (!grouped.containsKey(key)) {
      order.add(key);
      grouped[key] = [];
    }
    grouped[key]!.add(line);
  }
  final ranked = [for (final key in order) _sectionFromLines(grouped[key]!)]
    ..sort((a, b) {
      final bySerial = a.serialNo.compareTo(b.serialNo);
      if (bySerial != 0) return bySerial;
      return a.workType.toLowerCase().compareTo(b.workType.toLowerCase());
    });
  return [
    for (var i = 0; i < ranked.length; i++)
      QuotationSection(
        serialNo: i + 1,
        workType: ranked[i].workType,
        blocks: ranked[i].blocks,
      ),
  ];
}

QuotationSection _sectionFromLines(List<EstimateLine> typeLines) {
  final ordered = [...typeLines]..sort(compareEstimateLines);
  final blocks = <QuotationAreaBlock>[];
  var currentLines = <EstimateLine>[];
  String? lastArea;
  String? currentArea;
  String? currentCode;

  void flushArea() {
    if (currentLines.isEmpty && currentArea == null) return;
    blocks.add(
      QuotationAreaBlock(areaCode: currentCode, area: currentArea, lines: [...currentLines]),
    );
    currentLines = [];
  }

  for (final line in ordered) {
    if (line.area != lastArea) {
      flushArea();
      lastArea = line.area;
      currentArea = line.area;
      currentCode = line.areaCode;
    }
    currentLines.add(line);
  }
  flushArea();
  final first = typeLines.first;
  return QuotationSection(
    serialNo: first.serialNo,
    workType: first.workType,
    blocks: blocks,
  );
}

String quotationDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

String pdfSafe(String text) {
  return text
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('₹', 'Rs ');
}

String unitLabel(String unit) {
  final value = unit.trim().toLowerCase();
  if (value == 'lumpsum' || value == 'lumsum' || value == 'ls') return 'lumsum';
  if (value.isEmpty) return '';
  if (value.startsWith('per ')) return unit.trim();
  return 'per $unit';
}

String lineDescription(EstimateLine line) {
  final name = line.name.trim();
  final description = line.description.trim();
  if (name.isEmpty) return description;
  if (description.isEmpty || description == name) return name;
  return '$name — $description';
}

String scopeTitle(EstimateLine line) {
  final name = line.name.trim();
  if (name.isNotEmpty) return name;
  return line.description.trim();
}

String scopeDetails(EstimateLine line) {
  final name = line.name.trim();
  final description = line.description.trim();
  if (description.isEmpty || description == name) return '';
  return description;
}
