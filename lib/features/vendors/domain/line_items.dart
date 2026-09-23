import 'dart:convert';

class CatalogLine {
  const CatalogLine({
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.description,
  });

  final String itemName;
  final double quantity;
  final String unit;
  final String? description;

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'description': ?description,
      };

  factory CatalogLine.fromJson(Map<String, dynamic> data) => CatalogLine(
        itemName: data['itemName']?.toString() ?? '',
        quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
        unit: data['unit']?.toString() ?? 'nos',
        description: data['description']?.toString(),
      );
}

class PricedLine {
  const PricedLine({
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.total,
    this.description,
  });

  final String itemName;
  final double quantity;
  final String unit;
  final double rate;
  final double total;
  final String? description;

  factory PricedLine.fromCatalog(CatalogLine item, double rate) => PricedLine(
        itemName: item.itemName,
        quantity: item.quantity,
        unit: item.unit,
        rate: rate,
        total: item.quantity * rate,
        description: item.description,
      );

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'total': total,
        'description': ?description,
      };

  factory PricedLine.fromJson(Map<String, dynamic> data) {
    final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
    final rate = (data['rate'] as num?)?.toDouble() ?? 0;
    return PricedLine(
      itemName: data['itemName']?.toString() ?? '',
      quantity: quantity,
      unit: data['unit']?.toString() ?? 'nos',
      rate: rate,
      total: (data['total'] as num?)?.toDouble() ?? quantity * rate,
      description: data['description']?.toString(),
    );
  }
}

List<CatalogLine> catalogLinesFrom(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) CatalogLine.fromJson(Map<String, dynamic>.from(item)),
  ];
}

List<PricedLine> pricedLinesFrom(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) PricedLine.fromJson(Map<String, dynamic>.from(item)),
  ];
}

Object? decodeJsonList(Object? raw) {
  if (raw is List) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return const [];
}

String encodeJsonList(Iterable<Map<String, dynamic>> items) => jsonEncode(items.toList());
