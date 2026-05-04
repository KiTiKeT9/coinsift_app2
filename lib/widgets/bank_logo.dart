import 'package:flutter/material.dart';

import 'cached_logo_image.dart';

/// Логотип банка.
///
/// Сначала пытается подтянуть лого с Clearbit Logo API по
/// известному домену; результат персистится в Hive
/// через [LogoCacheService], чтобы следующие запуски
/// рендерили лого без сети. Если банк неизвестен или URL
/// вернул не-картинку — показывается яркий placeholder с
/// первой буквой названия банка.
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
    final fallbackColor = _parseHexColor(fallbackColorHex);
    final placeholder = _BankLogoPlaceholder(
      bankName: bankName,
      color: fallbackColor,
      size: size,
      radius: radius,
    );

    final domain = _domainFor(bankName);
    if (domain == null) return placeholder;

    return CachedLogoImage(
      url: 'https://logo.clearbit.com/$domain',
      placeholder: placeholder,
      size: size,
      radius: radius,
    );
  }

  static Color _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF6B7280);
    return Color(0xFF000000 | value);
  }
}

class _BankLogoPlaceholder extends StatelessWidget {
  const _BankLogoPlaceholder({
    required this.bankName,
    required this.color,
    required this.size,
    required this.radius,
  });

  final String bankName;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        bankName.isNotEmpty ? bankName.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
