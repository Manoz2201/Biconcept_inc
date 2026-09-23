import '../../../core/result/app_result.dart';
import 'currency.dart';
import 'money.dart';

abstract class CurrencyRepository {
  Future<AppResult<List<Currency>>> getCurrencies({bool? isActive});
  Future<AppResult<Currency>> getCurrencyByCode(String code);
  Future<AppResult<Currency>> getBaseCurrency();
  Future<AppResult<Currency>> createCurrency({
    required String code,
    required String name,
    required String symbol,
    required double exchangeRate,
    int decimalPlaces = 2,
  });
  Future<AppResult<Currency>> updateCurrency(String id, Map<String, dynamic> data);
  Future<AppResult<Currency>> setBaseCurrency(String id);
  Future<AppResult<Currency>> deactivateCurrency(String id);
  Future<AppResult<List<ExchangeRate>>> getExchangeRateHistory(String currencyCode, {DateTime? from, DateTime? to});
  Future<AppResult<Currency>> updateExchangeRate(String currencyCode, double rate, String source);
  Future<AppResult<Money>> convert(Money amount, String targetCurrencyCode);
  Future<AppResult<String>> formatMoney(Money money, {String? locale});
}
