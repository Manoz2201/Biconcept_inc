/// Clauses copied from Excel quotations under "OTHER TERMS AND CONDITIONS-".
const standardInteriorTerms = [
  'Payment needed to be done in phases - 30% Advance, 20% after delivery of material on site (within initial 20 days), Remaining 15% - 15% - 15% progressively every 20 days, 5% at the time of finishing.',
  'Excluding items or works from our estimate and scope of works (i.e. TV, Decor items, Projector, IT Server, paintings, planters, Wall Art, Ceiling and wall Fans, Signage, Logo, Wall Graphics, Decorative lights, kitchen\'s Appliances, Electrical fixtures like chandelier, decorative lights, geyser, fans, curtains, WIFI internet routers).',
  'Extra items from our estimate or scope of work will be charged separately (after approval).',
  'Estimated project completion time 3 to 4 months.',
  '18% GST will be extra on bill and 28% GST on AHU Unit + Split AC.',
  'Above estimate is based on your shared layout. If design, layouts and quantity will change then the cost will be revised as per 3D or layouts.',
];

const shortFinishingTerms = [
  'Payment needed to be done in phases - 30% Advance, 30% after delivery of material on site (within initial 10 days), Remaining 20% + 20% will be done progressively every 10 days.',
  'Estimated project completion time 30 days.',
  '18% GST will be extra on bill.',
];

const fastInteriorTerms = [
  'Payment needed to be done in phases - 30% Advance, 20% after delivery of material on site (within initial 20 days), Remaining 15% - 15% - 15% progressively every 20 days, 5% at the time of finishing.',
  'Excluding items or works from our estimate and scope of works (i.e. TV, Decor items, Projector, IT Server, paintings, planters, Wall Art, Ceiling and wall Fans, Signage, Logo, Wall Graphics, Decorative lights, kitchen\'s Appliances, Electrical fixtures like chandelier, decorative lights, geyser, fans, curtains, WIFI internet routers).',
  'Extra items from our estimate or scope of work will be charged separately (after approval).',
  'Estimated project completion time 30 to 45 days.',
  '18% GST will be extra on bill and 28% GST on AHU Unit + Split AC.',
  'Above estimate is based on your shared layout. If design, layouts and quantity will change then the cost will be revised as per 3D or layouts.',
];

class TermsTemplate {
  const TermsTemplate({
    required this.id,
    required this.name,
    required this.termsAndConditions,
  });

  final String id;
  final String name;
  final List<String> termsAndConditions;

  factory TermsTemplate.fromJson(Map<String, dynamic> json) {
    final terms = [
      for (final item in json['termsAndConditions'] as List? ?? const []) item.toString().trim(),
    ].where((item) => item.isNotEmpty).toList();
    return TermsTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Template',
      termsAndConditions: terms.isNotEmpty ? terms : standardInteriorTerms,
    );
  }
}

const builtInTermsTemplates = [
  TermsTemplate(
    id: 'standard_interior',
    name: 'Standard interior (3–4 months)',
    termsAndConditions: standardInteriorTerms,
  ),
  TermsTemplate(
    id: 'short_finishing',
    name: 'Short finishing (30 days)',
    termsAndConditions: shortFinishingTerms,
  ),
  TermsTemplate(
    id: 'fast_interior',
    name: 'Fast interior (30–45 days)',
    termsAndConditions: fastInteriorTerms,
  ),
];

List<String> sanitizeTerms(Iterable<String> terms) => [
      for (final term in terms)
        if (term.trim().isNotEmpty) term.trim(),
    ];

/// Rebuild numbered T&C from older split payment / exclusion / notes fields.
List<String> composeLegacyTerms({
  List<String> paymentTerms = const [],
  List<String> exclusions = const [],
  List<String> notes = const [],
}) {
  final items = <String>[];
  if (paymentTerms.isNotEmpty) {
    items.add('Payment needed to be done in phases - ${paymentTerms.join(', ')}.');
  }
  items.addAll(sanitizeTerms(notes));
  if (exclusions.isNotEmpty) {
    items.add(
      'Excluding items or works from our estimate and scope of works (i.e. ${exclusions.join(', ')}).',
    );
  }
  return items;
}

List<String> effectiveTermsAndConditions({
  List<String> termsAndConditions = const [],
  List<String> paymentTerms = const [],
  List<String> exclusions = const [],
  List<String> notes = const [],
}) {
  final direct = sanitizeTerms(termsAndConditions);
  if (direct.isNotEmpty) return direct;
  final legacy = composeLegacyTerms(
    paymentTerms: paymentTerms,
    exclusions: exclusions,
    notes: notes,
  );
  if (legacy.isNotEmpty) return legacy;
  return List<String>.from(standardInteriorTerms);
}
