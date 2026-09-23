class Currency {
  const Currency({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
    this.decimalPlaces = 2,
    this.isActive = true,
    this.isBaseCurrency = false,
    required this.exchangeRate,
    required this.lastUpdated,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final bool isActive;
  final bool isBaseCurrency;
  final double exchangeRate;
  final DateTime lastUpdated;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'symbol': symbol,
        'decimalPlaces': decimalPlaces,
        'isActive': isActive,
        'isBaseCurrency': isBaseCurrency,
        'exchangeRate': exchangeRate,
        'lastUpdated': lastUpdated.toUtc().toIso8601String(),
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
        'updatedAt': ?updatedAt?.toUtc().toIso8601String(),
      };

  factory Currency.fromJson(Map<String, dynamic> data) => Currency(
        id: data['id']?.toString() ?? '',
        code: (data['code']?.toString() ?? '').toUpperCase(),
        name: data['name']?.toString() ?? '',
        symbol: data['symbol']?.toString() ?? '',
        decimalPlaces: (data['decimalPlaces'] as num?)?.toInt() ?? 2,
        isActive: data['isActive'] != false,
        isBaseCurrency: data['isBaseCurrency'] == true,
        exchangeRate: (data['exchangeRate'] as num?)?.toDouble() ?? 1,
        lastUpdated: DateTime.tryParse(data['lastUpdated']?.toString() ?? '') ?? DateTime.now().toUtc(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      );

  Currency copyWith({
    bool? isActive,
    bool? isBaseCurrency,
    double? exchangeRate,
    DateTime? lastUpdated,
    DateTime? updatedAt,
  }) =>
      Currency(
        id: id,
        code: code,
        name: name,
        symbol: symbol,
        decimalPlaces: decimalPlaces,
        isActive: isActive ?? this.isActive,
        isBaseCurrency: isBaseCurrency ?? this.isBaseCurrency,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.currencyCode,
    required this.rate,
    required this.effectiveDate,
    this.source,
    this.createdAt,
  });

  final String id;
  final String currencyCode;
  final double rate;
  final DateTime effectiveDate;
  final String? source;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'currencyCode': currencyCode,
        'rate': rate,
        'effectiveDate': effectiveDate.toUtc().toIso8601String(),
        'source': ?source,
        'createdAt': ?createdAt?.toUtc().toIso8601String(),
      };

  factory ExchangeRate.fromJson(Map<String, dynamic> data) => ExchangeRate(
        id: data['id']?.toString() ?? '',
        currencyCode: (data['currencyCode']?.toString() ?? '').toUpperCase(),
        rate: (data['rate'] as num?)?.toDouble() ?? 0,
        effectiveDate: DateTime.tryParse(data['effectiveDate']?.toString() ?? '') ?? DateTime.now().toUtc(),
        source: data['source']?.toString(),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      );
}

List<Currency> defaultCurrencies(DateTime now) => [
      Currency(
        id: 'inr',
        code: 'INR',
        name: 'Indian Rupee',
        symbol: '₹',
        isBaseCurrency: true,
        exchangeRate: 1,
        lastUpdated: now,
        createdAt: now,
        updatedAt: now,
      ),
      Currency(id: 'usd', code: 'USD', name: 'US Dollar', symbol: r'$', exchangeRate: 83.5, lastUpdated: now, createdAt: now, updatedAt: now),
      Currency(id: 'eur', code: 'EUR', name: 'Euro', symbol: '€', exchangeRate: 90, lastUpdated: now, createdAt: now, updatedAt: now),
      Currency(id: 'gbp', code: 'GBP', name: 'British Pound', symbol: '£', exchangeRate: 106, lastUpdated: now, createdAt: now, updatedAt: now),
      Currency(id: 'aed', code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', exchangeRate: 22.7, lastUpdated: now, createdAt: now, updatedAt: now),
    ];
