import 'currency.dart';

double moneyRound(double value, [int places = 2]) {
  var factor = 1.0;
  for (var i = 0; i < places; i++) {
    factor *= 10;
  }
  return (value * factor).roundToDouble() / factor;
}

class Money {
  const Money(this.amount, this.currency);

  final double amount;
  final Currency currency;

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(moneyRound(amount + other.amount, currency.decimalPlaces), currency);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(moneyRound(amount - other.amount, currency.decimalPlaces), currency);
  }

  Money operator *(double factor) => Money(moneyRound(amount * factor, currency.decimalPlaces), currency);

  Money operator /(double divisor) {
    if (divisor == 0) throw ArgumentError('Cannot divide by zero');
    return Money(moneyRound(amount / divisor, currency.decimalPlaces), currency);
  }

  String format({String? locale}) {
    final digits = currency.decimalPlaces;
    final raw = amount.abs().toStringAsFixed(digits);
    final parts = raw.split('.');
    final grouped = _indianGroup(parts.first);
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    final sign = amount < 0 ? '-' : '';
    return '$sign${currency.symbol}$grouped$fraction';
  }

  /// Amount in base-currency units (rate = units of base per 1 of this currency).
  double get baseAmount => moneyRound(amount * currency.exchangeRate);

  Money toBase(Currency base) {
    if (!base.isBaseCurrency) {
      throw ArgumentError('toBase requires the firm base currency');
    }
    return Money(baseAmount, base);
  }

  Money convertTo(Currency target) {
    if (target.exchangeRate == 0) {
      throw ArgumentError('Target exchange rate cannot be zero');
    }
    return Money(moneyRound(baseAmount / target.exchangeRate, target.decimalPlaces), target);
  }

  void _checkSameCurrency(Money other) {
    if (currency.code != other.currency.code) {
      throw ArgumentError('Cannot operate on ${currency.code} and ${other.currency.code}');
    }
  }

  static String _indianGroup(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    return '${chunks.join(',')},$last3';
  }
}
