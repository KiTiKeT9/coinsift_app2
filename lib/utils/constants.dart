class TransactionCategories {
  static const List<Map<String, dynamic>> incomeCategories = [
    {'name': 'Зарплата', 'icon': '💰', 'color': '#10B981'},
    {'name': 'Подработка', 'icon': '💼', 'color': '#3B82F6'},
    {'name': 'Инвестиции', 'icon': '📈', 'color': '#6366F1'},
    {'name': 'Подарки', 'icon': '🎁', 'color': '#EC4899'},
    {'name': 'Возврат', 'icon': '↩️', 'color': '#14B8A6'},
    {'name': 'Другое', 'icon': '📝', 'color': '#94A3B8'},
  ];

  static const List<Map<String, dynamic>> expenseCategories = [
    {'name': 'Продукты', 'icon': '🛒', 'color': '#F59E0B'},
    {'name': 'Рестораны', 'icon': '🍔', 'color': '#EF4444'},
    {'name': 'Транспорт', 'icon': '🚗', 'color': '#3B82F6'},
    {'name': 'Такси', 'icon': '🚕', 'color': '#FBBF24'},
    {'name': 'Бензин', 'icon': '⛽', 'color': '#10B981'},
    {'name': 'Развлечения', 'icon': '🎬', 'color': '#8B5CF6'},
    {'name': 'Здоровье', 'icon': '🏥', 'color': '#EF4444'},
    {'name': 'Аптека', 'icon': '💊', 'color': '#EC4899'},
    {'name': 'Одежда', 'icon': '👕', 'color': '#6366F1'},
    {'name': 'Шоппинг', 'icon': '🛍️', 'color': '#F472B6'},
    {'name': 'Дом', 'icon': '🏠', 'color': '#94A3B8'},
    {'name': 'Коммуналка', 'icon': '💡', 'color': '#FBBF24'},
    {'name': 'Связь', 'icon': '📱', 'color': '#06B6D4'},
    {'name': 'Интернет', 'icon': '📶', 'color': '#8B5CF6'},
    {'name': 'Образование', 'icon': '📚', 'color': '#10B981'},
    {'name': 'Курсы', 'icon': '🎓', 'color': '#6366F1'},
    {'name': 'Путешествия', 'icon': '✈️', 'color': '#0EA5E9'},
    {'name': 'Отель', 'icon': '🏨', 'color': '#F59E0B'},
    {'name': 'Красота', 'icon': '💅', 'color': '#EC4899'},
    {'name': 'Спорт', 'icon': '🏋️', 'color': '#10B981'},
    {'name': 'Животные', 'icon': '🐕', 'color': '#D97706'},
    {'name': 'Дети', 'icon': '🧸', 'color': '#F472B6'},
    {'name': 'Налоги', 'icon': '📋', 'color': '#64748B'},
    {'name': 'Страховка', 'icon': '🛡️', 'color': '#3B82F6'},
    {'name': 'Кредит', 'icon': '💳', 'color': '#EF4444'},
    {'name': 'Ипотека', 'icon': '🏦', 'color': '#1E40AF'},
    {'name': 'Другое', 'icon': '📝', 'color': '#94A3B8'},
  ];

  static Map<String, dynamic> getCategoryByName(String name) {
    final allCategories = [...incomeCategories, ...expenseCategories];
    for (var category in allCategories) {
      if (category['name'] == name) {
        return category;
      }
    }
    return {'name': name, 'icon': '📝', 'color': '#94A3B8'};
  }
}

class RussianBanks {
  // Статические данные теперь загружаются из BanksApiService
  // Этот класс оставлен для обратной совместимости
  
  static const List<Map<String, dynamic>> banks = [
    {
      'name': 'СберБанк',
      'shortName': 'Сбер',
      'color': '#21A038',
      'logo': 'sber',
      'mortgageRate': 17.5,
      'loanRate': 18.5,
      'depositRate': 16.0,
    },
    {
      'name': 'Тинькофф Банк',
      'shortName': 'Тинькофф',
      'color': '#FFDD2D',
      'logo': 'tinkoff',
      'mortgageRate': 17.0,
      'loanRate': 19.0,
      'depositRate': 15.5,
    },
    {
      'name': 'Альфа-Банк',
      'shortName': 'Альфа',
      'color': '#EF3124',
      'logo': 'alfa',
      'mortgageRate': 17.3,
      'loanRate': 18.0,
      'depositRate': 16.5,
    },
    {
      'name': 'ВТБ',
      'shortName': 'ВТБ',
      'color': '#002882',
      'logo': 'vtb',
      'mortgageRate': 17.8,
      'loanRate': 19.5,
      'depositRate': 15.8,
    },
    {
      'name': 'Газпромбанк',
      'shortName': 'ГПБ',
      'color': '#0055A5',
      'logo': 'gpb',
      'mortgageRate': 17.6,
      'loanRate': 18.8,
      'depositRate': 15.7,
    },
    {
      'name': 'Райффайзен Банк',
      'shortName': 'Райффайзен',
      'color': '#E30613',
      'logo': 'raiffeisen',
      'mortgageRate': 17.9,
      'loanRate': 19.2,
      'depositRate': 15.3,
    },
  ];

  static Map<String, dynamic>? getBankByName(String name) {
    for (var bank in banks) {
      if (bank['name'] == name || bank['shortName'] == name) {
        return bank;
      }
    }
    return null;
  }
}
