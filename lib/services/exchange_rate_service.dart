import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ConversionRateInfo {
  final double rate;
  final DateTime effectiveRateDate;
  final bool isRateStale;

  ConversionRateInfo({
    required this.rate,
    required this.effectiveRateDate,
    this.isRateStale = false,
  });
}

class ExchangeRateService {
  final String _nbuApiUrl = 'https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange';
  static final Map<String, Map<String, ConversionRateInfo>> _cache = {};
  
  Future<Map<String, double>> getRatesForCurrencies(List<String> codes, {DateTime? date}) async {
    final DateTime targetDate = date ?? DateTime.now();
    final Map<String, double> rates = {};
    final nbuRates = await _fetchRatesForDate(targetDate);
    
    for (String code in codes) {
      if (code == 'UAH') {
        rates[code] = 1.0;
      } else {
        rates[code] = nbuRates[code] ?? 1.0;
      }
    }
    return rates;
  }

  String _getCacheKey(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  Future<Map<String, double>> _fetchRatesForDate(DateTime date) async {
    final String dateString = DateFormat('yyyyMMdd').format(date);
    final String cacheKey = _getCacheKey(date);

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.map((key, value) => MapEntry(key, value.rate));
    }

    final url = '$_nbuApiUrl?date=$dateString&json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final Map<String, double> rates = {
        'UAH': 1.0,
      };
      for (var item in data) {
        rates[item['cc']] = (item['rate'] as num).toDouble();
      }
      
      _cache[cacheKey] = rates.map((key, value) => MapEntry(key, ConversionRateInfo(rate: value, effectiveRateDate: date, isRateStale: false)));
      
      if (_cache.length > 30) {
        _cache.remove(_cache.keys.first);
      }

      return rates;
    } else {
      throw Exception('Failed to load exchange rates for $dateString. Status code: ${response.statusCode}');
    }
  }

  Future<ConversionRateInfo> getConversionRate(String fromCurrency, String toCurrency, {DateTime? date}) async {
    final DateTime targetDate = date ?? DateTime.now();
    
    if (fromCurrency == toCurrency) {
      return ConversionRateInfo(rate: 1.0, effectiveRateDate: targetDate);
    }
    
    try {
      final rates = await _fetchRatesForDate(targetDate);
      final double? fromRate = rates[fromCurrency];
      final double? toRate = rates[toCurrency];
      if (fromRate != null && toRate != null) {
        return ConversionRateInfo(rate: fromRate / toRate, effectiveRateDate: targetDate);
      } else {
        throw Exception('One of the currencies ($fromCurrency or $toCurrency) not found in NBU data.');
      }
    } catch (e) {
      if (targetDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        return await getConversionRate(fromCurrency, toCurrency, date: targetDate.add(const Duration(days: 1)));
      } else {
        final ratesNow = await _fetchRatesForDate(DateTime.now());
        final double? fromRateNow = ratesNow[fromCurrency];
        final double? toRateNow = ratesNow[toCurrency];
        if (fromRateNow != null && toRateNow != null) {
          return ConversionRateInfo(rate: fromRateNow / toRateNow, effectiveRateDate: DateTime.now(), isRateStale: true);
        } else {
          throw Exception('Failed to get exchange rate even for the current date.');
        }
      }
    }
  }
}