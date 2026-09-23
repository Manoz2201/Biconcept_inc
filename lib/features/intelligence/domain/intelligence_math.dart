import '../../ai_assistant/domain/ai_models.dart';
import '../../enquiries/domain/enquiry.dart';
import '../../predictive/domain/predictive_models.dart';
import '../../projects/domain/project.dart';
import '../../projects/domain/project_status.dart';

final invoiceNumberPattern = RegExp(r'Invoice\s*(?:No|Number|#)?[:\s]*([A-Z0-9\-/]+)', caseSensitive: false);
final datedPattern = RegExp(r'(?:Date|Dated)[:\s]*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})', caseSensitive: false);
final gstinPattern = RegExp(r'GSTIN[:\s]*([0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{1}Z[0-9A-Z]{1})', caseSensitive: false);
final totalPattern = RegExp(r'(?:Grand\s*Total|Total)[:\s]*[₹Rs.]*\s*([\d,]+\.?\d*)', caseSensitive: false);

Map<String, dynamic> parseInvoiceText(String text) {
  final total = totalPattern.firstMatch(text)?.group(1);
  return {
    'invoiceNumber': invoiceNumberPattern.firstMatch(text)?.group(1),
    'invoiceDate': datedPattern.firstMatch(text)?.group(1),
    'vendorGstin': gstinPattern.firstMatch(text)?.group(1),
    'grandTotal': double.tryParse((total ?? '0').replaceAll(',', '')),
  };
}

Map<String, dynamic> parseReceiptText(String text) {
  return {
    'merchantName': RegExp(r'(?:Merchant|Store|From)[:\s]*(.+)', caseSensitive: false).firstMatch(text)?.group(1)?.trim(),
    'date': datedPattern.firstMatch(text)?.group(1),
    'amount': double.tryParse((totalPattern.firstMatch(text)?.group(1) ?? '0').replaceAll(',', '')),
    'gstin': gstinPattern.firstMatch(text)?.group(1),
  };
}

Set<String> tokenize(String text) {
  return {
    for (final part in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
      if (part.length > 2) part,
  };
}

double overlapScore(String query, String document) {
  final left = tokenize(query);
  final right = tokenize(document);
  if (left.isEmpty || right.isEmpty) return 0;
  final hit = left.where(right.contains).length;
  return hit / left.length;
}

List<SemanticSearchResult> rankDocuments(String query, List<VectorDocument> docs, {String? sourceType, int limit = 20}) {
  final ranked = [
    for (final doc in docs)
      if (sourceType == null || doc.sourceType == sourceType)
        SemanticSearchResult(sourceType: doc.sourceType, sourceId: doc.sourceId, text: doc.text, similarity: overlapScore(query, doc.text)),
  ]..sort((a, b) => b.similarity.compareTo(a.similarity));
  return ranked.where((item) => item.similarity > 0).take(limit).toList();
}

NlpQueryResult parseNaturalLanguage(String query, {required List<Map<String, String>> invoices, required List<Map<String, String>> projects}) {
  final lower = query.toLowerCase();
  final unpaid = lower.contains('unpaid') || lower.contains('outstanding');
  final amountMatch = RegExp(r'(?:over|above|greater than)\s*₹?\s*([\d,]+)').firstMatch(lower);
  final minAmount = double.tryParse((amountMatch?.group(1) ?? '').replaceAll(',', ''));
  if (lower.contains('invoice') || lower.contains('bill') || unpaid) {
    final rows = invoices.where((row) {
      if (unpaid && (row['status'] == 'paid' || row['status'] == 'void')) return false;
      if (minAmount != null && (double.tryParse(row['amount'] ?? '0') ?? 0) < minAmount) return false;
      return true;
    }).toList();
    return NlpQueryResult(
      interpreted: 'Invoices${unpaid ? ' that are unpaid' : ''}${minAmount != null ? ' over $minAmount' : ''}',
      entity: 'invoice',
      filters: {'unpaid': unpaid, 'minAmount': minAmount},
      rows: rows,
    );
  }
  return NlpQueryResult(interpreted: 'Projects matching "$query"', entity: 'project', filters: const {}, rows: projects);
}

Map<String, int> scoreLead(Enquiry enquiry) {
  var budget = enquiry.message.toLowerCase().contains('budget') || enquiry.message.contains('₹') ? 20 : 10;
  var timeline = enquiry.message.toLowerCase().contains('urgent') || enquiry.message.toLowerCase().contains('month') ? 20 : 12;
  var location = enquiry.message.toLowerCase().contains('chennai') || enquiry.message.toLowerCase().contains('tamil') ? 15 : 8;
  var service = enquiry.serviceId != null && enquiry.serviceId!.isNotEmpty ? 18 : 8;
  var engagement = enquiry.message.length > 80 ? 15 : enquiry.message.length > 20 ? 10 : 5;
  if (enquiry.status == EnquiryStatus.qualified) engagement += 5;
  if (enquiry.status == EnquiryStatus.converted) engagement = 15;
  budget = budget.clamp(0, 25);
  timeline = timeline.clamp(0, 25);
  location = location.clamp(0, 15);
  service = service.clamp(0, 20);
  engagement = engagement.clamp(0, 15);
  return {
    'budget': budget,
    'timeline': timeline,
    'location': location,
    'service': service,
    'engagement': engagement,
    'total': budget + timeline + location + service + engagement,
  };
}

String leadPriority(int total) {
  if (total > 70) return 'high';
  if (total >= 40) return 'medium';
  return 'low';
}

ImageLabels analyzeCaption(String caption) {
  final lower = caption.toLowerCase();
  final labels = <String>[
    if (lower.contains('concrete') || lower.contains('foundation')) 'foundation',
    if (lower.contains('beam') || lower.contains('column') || lower.contains('slab')) 'structure',
    if (lower.contains('paint') || lower.contains('tile') || lower.contains('floor')) 'finishing',
    if (lower.contains('furniture') || lower.contains('light')) 'completion',
    if (lower.contains('steel')) 'steel',
    if (lower.contains('brick')) 'brick',
  ];
  if (labels.isEmpty) labels.add('site');
  final progress = switch (labels.first) {
    'foundation' => 25.0,
    'structure' => 50.0,
    'finishing' => 75.0,
    'completion' => 100.0,
    _ => 10.0,
  };
  final safety = <String>[
    if (!lower.contains('helmet')) 'No safety helmet noted',
    if (!lower.contains('vest')) 'No safety vest noted',
    if (lower.contains('fire')) 'Potential fire hazard',
  ];
  final materials = [
    if (lower.contains('concrete')) 'concrete',
    if (lower.contains('steel')) 'steel',
    if (lower.contains('brick')) 'brick',
    if (lower.contains('tile')) 'tile',
  ];
  return ImageLabels(labels: labels, progress: progress, safety: safety, materials: materials);
}

class ImageLabels {
  const ImageLabels({required this.labels, required this.progress, required this.safety, required this.materials});
  final List<String> labels;
  final double progress;
  final List<String> safety;
  final List<String> materials;
}

RiskPrediction projectRisk(Project project) {
  final overdue = project.endDate.isBefore(DateTime.now()) && project.status != ProjectStatus.completed;
  final burn = project.budget == null || project.budget == 0 ? 0.0 : project.spent / project.budget!;
  var score = 20.0;
  final factors = <String>[];
  final recs = <String>[];
  if (overdue) {
    score += 30;
    factors.add('Planned end date has passed');
    recs.add('Re-baseline the schedule');
  }
  if (burn > 0.9) {
    score += 25;
    factors.add('Budget burn above 90%');
    recs.add('Review remaining scope');
  } else if (burn > 0.7) {
    score += 10;
    factors.add('Budget burn above 70%');
  }
  if (project.progress < 40 && project.status == ProjectStatus.inProgress) {
    score += 15;
    factors.add('Low progress while in progress');
    recs.add('Unblock overdue tasks');
  }
  if (factors.isEmpty) recs.add('On track — keep weekly reviews');
  final level = score >= 70 ? 'high' : score >= 40 ? 'medium' : 'low';
  return RiskPrediction(
    projectId: project.id,
    riskScore: score.clamp(0, 100),
    riskLevel: level,
    factors: factors,
    recommendations: recs,
    predictedDelayDays: overdue ? 14 : (score > 50 ? 7 : 0),
    confidence: 0.72,
  );
}

ProjectHealth projectHealth(Project project) {
  final schedule = project.endDate.isBefore(DateTime.now()) && !project.status.isTerminal ? 40.0 : 80.0 + (project.progress / 5);
  final budget = project.budget == null || project.budget == 0 ? 70.0 : (100 - ((project.spent / project.budget!) * 80)).clamp(0, 100);
  final client = project.status == ProjectStatus.onHold ? 40.0 : 75.0;
  final team = project.assignedArchitect == null ? 55.0 : 80.0;
  final score = (schedule + budget + client + team) / 4;
  return ProjectHealth(
    projectId: project.id,
    score: score,
    schedule: schedule,
    budget: budget.toDouble(),
    client: client,
    team: team,
    recommendations: [
      if (schedule < 60) 'Recover the schedule',
      if (budget < 60) 'Control remaining spend',
      if (team < 60) 'Assign an architect',
    ],
  );
}

List<double> linearForecast(List<double> history, int periods) {
  if (history.isEmpty) return List.filled(periods, 0);
  if (history.length == 1) return List.filled(periods, history.first);
  final n = history.length;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXY = 0.0;
  var sumXX = 0.0;
  for (var i = 0; i < n; i++) {
    sumX += i;
    sumY += history[i];
    sumXY += i * history[i];
    sumXX += i * i;
  }
  final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  final intercept = (sumY - slope * sumX) / n;
  return [for (var i = 0; i < periods; i++) intercept + slope * (n + i)];
}

String assistantReply(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invoice') || lower.contains('unpaid')) {
    return 'I can list unpaid invoices. Try: “Show unpaid invoices over ₹50,000”.';
  }
  if (lower.contains('quotation') || lower.contains('quote')) {
    return 'Open Quotation suggest with a service request to draft line items from similar work.';
  }
  if (lower.contains('risk') || lower.contains('timeline')) {
    return 'Use Timeline predict or the risk dashboard to see delay and budget burn.';
  }
  if (lower.contains('lead')) {
    return 'Lead score ranks enquiries by budget, timeline, location, service, and engagement.';
  }
  return 'I can help with quotations, cost estimates, lead scores, OCR, WhatsApp drafts, and search. Ask in plain language or use the chips below.';
}
