import 'package:flutter/material.dart';

/// Логотип банка: подгружается с Clearbit Logo API по доменy,
/// с fallback на цветной круг с первой буквой названия.
///
/// Маппинг бренда → домен ведётся локально для популярных РФ-банков.
/// Для незнакомых банков сразу показывается цветной плейсхолдер.
class BankLogo extends StatelessWidget {
  const BankLogo({
    super.key,
    required this.bankName,
    required this.fallbackColorHex,
    this.size = 40,
    this.radius = 8,
  });

  final String bankName;
  final String fallbackColorHex;
  final double size;
  final double radius;

  static const Map<String, String> _domainByBrand = {
    'тинькофф': 'tinkoff.ru',
    'tinkoff': 'tinkoff.ru',
    'т-банк': 'tbank.ru',
    'tbank': 'tbank.ru',
    'сбер': 'sberbank.ru',
    'сбербанк': 'sberbank.ru',
    'sber': 'sberbank.ru',
    'sberbank': 'sberbank.ru',
    'альфа': 'alfabank.ru',
    'альфа-банк': 'alfabank.ru',
    'alfa': 'alfabank.ru',
    'alfabank': 'alfabank.ru',
    'втб': 'vtb.ru',
    'vtb': 'vtb.ru',
    'газпромбанк': 'gazprombank.ru',
    'газпром': 'gazprombank.ru',
    'gazprombank': 'gazprombank.ru',
    'росбанк': 'rosbank.ru',
    'rosbank': 'rosbank.ru',
    'открытие': 'open.ru',
    'open': 'open.ru',
    'райффайзен': 'raiffeisen.ru',
    'райффайзенбанк': 'raiffeisen.ru',
    'райффайзен банк': 'raiffeisen.ru',
    'raiffeisen': 'raiffeisen.ru',
    'почта банк': 'pochtabank.ru',
    'почтабанк': 'pochtabank.ru',
    'мкб': 'mkb.ru',
    'московский кредитный банк': 'mkb.ru',
    'россельхозбанк': 'rshb.ru',
    'рсхб': 'rshb.ru',
    'совкомбанк': 'sovcombank.ru',
    'юникредит': 'unicredit.ru',
    'росгосстрах банк': 'rgsbank.ru',
    'home credit': 'homecredit.ru',
    'хоум кредит': 'homecredit.ru',
  };

  String? _domainFor(String name) {
    final n = name.toLowerCase().trim();
    final direct = _domainByBrand[n];
    if (direct != null) return direct;
    for (final entry in _domainByBrand.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackColor = Color(
      int.parse('FF${fallbackColorHex.replaceFirst('#', '')}', radix: 16),
    );

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Text(
              bankName.isNotEmpty ? bankName.characters.first.toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.42,
              ),
            ),
          ),
        );

    final domain = _domainFor(bankName);
    if (domain == null) return placeholder();

    final url = 'https://logo.clearbit.com/$domain';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder();
          },
        ),
      ),
    );
  }
}
