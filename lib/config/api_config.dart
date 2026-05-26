// ignore_for_file: constant_identifier_names

class ApiConfig {
  // ===== BELINK AGGREGATOR API =====
  
  /// Client ID из личного кабинета Belink
  static const String BELINK_CLIENT_ID = 'your_client_id_here'; // Заменить!
  
  /// Client Secret из личного кабинета Belink  
  static const String BELINK_CLIENT_SECRET = 'your_client_secret_here'; // Заменить!
  
  /// Base URL для Belink API
  /// Sandbox: https://sandbox-api.belink.ru/v1
  /// Production: https://api.belink.ru/v1
  static const String BELINK_API_URL = 'https://sandbox-api.belink.ru/v1';
  
  /// Redirect URI (должен совпадать с настройками в Belink)
  static const String BELINK_REDIRECT_URI = 'monetka://belink-callback';
  
  /// Режим sandbox (true для тестирования, false для production)
  static const bool BELINK_USE_SANDBOX = true;

  // ===== СПИСОК ПОДДЕРЖИВАЕМЫХ БАНКОВ =====
  
  static const Map<String, BankConfig> SUPPORTED_BANKS = {
    'tinkoff': BankConfig(
      id: 'tinkoff',
      name: 'Тинькофф',
      fullName: 'Тинькофф Банк',
      color: 0xFFFFDD2D,
      icon: '💛',
      belinkBankCode: 'tinkoff',
      authUrl: 'https://www.tinkoff.ru/banking/openapi/connect/',
      supported: true,
    ),
    'sber': BankConfig(
      id: 'sber',
      name: 'Сбербанк',
      fullName: 'Сбербанк Онлайн',
      color: 0xFF21A038,
      icon: '💚',
      belinkBankCode: 'sberbank',
      authUrl: 'https://online.sberbank.ru/authorize',
      supported: true,
    ),
    'alfa': BankConfig(
      id: 'alfa',
      name: 'Альфа',
      fullName: 'Альфа-Банк',
      color: 0xFFEF3124,
      icon: '❤️',
      belinkBankCode: 'alfabank',
      authUrl: 'https://alfa-auto-auth.ru/connect',
      supported: true,
    ),
    'vtb': BankConfig(
      id: 'vtb',
      name: 'ВТБ',
      fullName: 'ВТБ Онлайн',
      color: 0xFF002882,
      icon: '💙',
      belinkBankCode: 'vtb',
      authUrl: 'https://online.vtb.ru/authorize',
      supported: true,
    ),
    'raiffeisen': BankConfig(
      id: 'raiffeisen',
      name: 'Райффайзен',
      fullName: 'Райффайзенбанк',
      color: 0xFFE2001A,
      icon: '🏦',
      belinkBankCode: 'raiffeisen',
      authUrl: '',
      supported: false,
    ),
  };
}

/// Конфигурация банка
class BankConfig {
  final String id;
  final String name;
  final String fullName;
  final int color;
  final String icon;
  final String belinkBankCode;
  final String authUrl;
  final bool supported;

  const BankConfig({
    required this.id,
    required this.name,
    required this.fullName,
    required this.color,
    required this.icon,
    required this.belinkBankCode,
    required this.authUrl,
    required this.supported,
  });
}
