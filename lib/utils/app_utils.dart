import 'package:intl/intl.dart';

class AppUtils {
  static NumberFormat _currencyFormat(String symbol) => NumberFormat.currency(
    locale: 'ru_RU',
    symbol: symbol,
    decimalDigits: 2,
  );

  static NumberFormat _compactCurrencyFormat(String symbol) => NumberFormat.compactCurrency(
    locale: 'ru_RU',
    symbol: symbol,
    decimalDigits: 1,
  );

  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy', 'ru_RU');
  static final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'ru_RU');
  static final DateFormat _shortMonthFormat = DateFormat('MMM', 'ru_RU');

  static String formatCurrency(double amount, {String currency = 'RUB'}) {
    final symbol = getCurrencySymbol(currency);
    return _currencyFormat(symbol).format(amount);
  }

  static String formatCompactCurrency(double amount, {String currency = 'RUB'}) {
    final symbol = getCurrencySymbol(currency);
    return _compactCurrencyFormat(symbol).format(amount);
  }

  static double convertAmount(double amount, String from, String to, List<dynamic>? rates) {
    if (from == to || rates == null || rates.isEmpty) return amount;
    final fromRate = _findRate(from, rates);
    final toRate = _findRate(to, rates);
    if (fromRate == null || toRate == null) return amount;
    return amount / fromRate * toRate;
  }

  static double? _findRate(String currency, List<dynamic> rates) {
    if (currency == 'USD') return 1.0;
    for (final r in rates) {
      if (r is Map<String, dynamic> && r['currency'] == currency) return (r['rate'] as num).toDouble();
    }
    return null;
  }

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  static String formatShortMonth(DateTime date) {
    return _shortMonthFormat.format(date);
  }

  static String getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'CNY':
        return '¥';
      case 'RUB':
      default:
        return '₽';
    }
  }

  static String getBankLogoAsset(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'сбер':
      case 'sber':
      case 'sberbank':
        return 'assets/icons/sber.svg';
      case 'тинькофф':
      case 'tinkoff':
        return 'assets/icons/tinkoff.svg';
      case 'альфа':
      case 'alfa':
        return 'assets/icons/alfa.svg';
      case 'втб':
      case 'vtb':
        return 'assets/icons/vtb.svg';
      default:
        return 'assets/icons/bank.svg';
    }
  }

  static String truncateCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    return '•••• ${cardNumber.substring(cardNumber.length - 4)}';
  }

  static String getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'еда':
      case 'продукты':
      case 'рестораны':
        return '🍔';
      case 'транспорт':
      case 'такси':
      case 'бензин':
        return '🚗';
      case 'развлечения':
      case 'кино':
        return '🎬';
      case 'здоровье':
      case 'аптека':
      case 'медицина':
        return '🏥';
      case 'одежда':
      case 'шоппинг':
        return '👕';
      case 'дом':
      case 'коммуналка':
        return '🏠';
      case 'связь':
      case 'интернет':
      case 'телефон':
        return '📱';
      case 'образование':
      case 'курсы':
        return '📚';
      case 'путешествия':
      case 'отель':
      case 'авиа':
        return '✈️';
      case 'зарплата':
      case 'доход':
        return '💰';
      case 'инвестиции':
        return '📈';
      default:
        return '📝';
    }
  }

  static double parseCurrency(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^\d.,-]'), '').replaceAll(',', '.')) ?? 0;
  }

  static String getGreeting() {
    final (text, emoji) = _greetingForHour(DateTime.now().hour);
    return '$text $emoji';
  }

  /// Персонализированное приветствие с именем и эмоджи времени суток.
  ///
  /// Деление по часам:
  ///  * 0–4   — ночь
  ///  * 5–11  — утро
  ///  * 12–17 — день
  ///  * 18–22 — вечер
  ///  * 23    — ночь
  static String getPersonalizedGreeting(String? name) {
    final hour = DateTime.now().hour;
    final (greeting, emoji) = _greetingForHour(hour);
    final userName = name != null && name.trim().isNotEmpty ? name.trim() : 'друг';
    return '$greeting, $userName! $emoji';
  }

  static (String, String) _greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return ('Доброе утро', '☀️');
    if (hour >= 12 && hour < 18) return ('Добрый день', '🌤️');
    if (hour >= 18 && hour < 23) return ('Добрый вечер', '🌆');
    return ('Доброй ночи', '🌙');
  }

  /// Мотивационная цитата для главной страницы
  static String getMotivationalQuote() {
    final quotes = [
      'Деньги — хороший слуга, но плохой хозяин 💰',
      'Не откладывай на завтра то, что можно инвестировать сегодня 📈',
      'Финансовая свобода начинается с контроля расходов 💡',
      'Инвестиции в знания платят лучшие дивиденды 📚',
      'Будущее принадлежит тем, кто готов к нему сегодня 🚀',
      'Маленькие шаги ведут к большим достижениям 🎯',
      'Успех — это сумма маленьких усилий, повторяющихся изо дня в день ⭐',
    ];
    
    // Выбираем цитату на основе дня месяца, чтобы они менялись
    final dayOfMonth = DateTime.now().day;
    return quotes[dayOfMonth % quotes.length];
  }
}
