import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/bank_signals_controller.dart';
import '../providers/investments_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/user_profile.dart';
import '../services/security_service.dart';
import '../services/currency_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_utils.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Consumer<UserProfileProvider>(
        builder: (context, provider, _) {
          final profile = provider.profile;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        _buildAvatar(profile, provider, context),
                        const SizedBox(height: 16),
                        Text(
                          profile?.name ?? 'Пользователь',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (profile?.email != null && profile!.email.isNotEmpty)
                          Text(
                            profile.email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBalanceOverview(context),
                      const SizedBox(height: 32),
                      
                      _buildSectionLabel('ОСНОВНЫЕ НАСТРОЙКИ'),
                      _buildSettingsGroup(context, [
                        _SettingsItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Личные данные',
                          subtitle: 'Имя, Email, Бюджет',
                          onTap: () => _showEditProfileDialog(context, provider),
                        ),
                        _SettingsItem(
                          icon: Icons.security_rounded,
                          title: 'Безопасность',
                          subtitle: provider.enablePinLock ? 'PIN-код включен' : 'Защита отключена',
                          onTap: () => _togglePinLock(context, provider),
                        ),
                        _SettingsItem(
                          icon: Icons.dark_mode_outlined,
                          title: 'Темная тема',
                          trailing: Switch.adaptive(
                            value: provider.isDarkTheme,
                            onChanged: (_) => provider.toggleDarkTheme(),
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.palette_outlined,
                          title: 'Material You',
                          subtitle: provider.useDynamicColor
                              ? 'Динамические цвета из обоев' : 'Классическая тема',
                          trailing: Switch.adaptive(
                            value: provider.useDynamicColor,
                            onChanged: (_) => provider.toggleDynamicColor(),
                            activeThumbColor: AppColors.primary,
                          ),
                        ),
                        _SettingsItem(
                          icon: Icons.currency_exchange,
                          title: 'Валюта отображения',
                          subtitle: provider.displayCurrency,
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                          onTap: () => _showCurrencyPicker(context, provider),
                        ),
                      ]),
                      
                      const SizedBox(height: 32),
                      _buildSectionLabel('БАНКИ И ИМПОРТ'),
                      _buildSettingsGroup(context, [
                        _SettingsItem(
                          icon: Icons.account_balance_rounded,
                          title: 'Агрегатор банков',
                          subtitle: 'Синхронизация через API',
                          onTap: () => Navigator.pushNamed(context, '/bank-aggregator'),
                        ),
                        _SettingsItem(
                          icon: Icons.file_upload_outlined,
                          title: 'Импорт выписок',
                          subtitle: 'Загрузка из файлов CSV/Excel',
                          onTap: () => Navigator.pushNamed(context, '/bank-import'),
                        ),
                        const _BankSignalsTiles(),
                      ]),
                      
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          'Монетка v1.0.0',
                          style: TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile, UserProfileProvider provider, BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              )
            ],
          ),
          child: ClipOval(
            child: profile?.avatarPath != null && File(profile!.avatarPath!).existsSync()
                ? Image.file(File(profile.avatarPath!), fit: BoxFit.cover)
                : Container(
                    color: Colors.white24,
                    child: const Icon(Icons.person_rounded, size: 60, color: Colors.white),
                  ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _showAvatarOptions(context, provider),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.primary),
            ),
          ),
        ),
      ],
    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack);
  }

  Widget _buildBalanceOverview(BuildContext context) {
    final accountsProvider = context.watch<AccountsProvider>();
    final investmentsProvider = context.watch<InvestmentsProvider>();
    final profileProv = context.watch<UserProfileProvider>();
    final displayCurrency = profileProv.displayCurrency;
    final cs = CurrencyService();
    final budgetConverted = cs.convertSync(profileProv.profile?.monthlyBudget ?? 0, 'RUB', displayCurrency) ?? (profileProv.profile?.monthlyBudget ?? 0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat('Счета', '${accountsProvider.activeAccounts.length}', AppColors.primary),
          Container(width: 1, height: 40, color: Colors.black.withValues(alpha: 0.05)),
          _buildQuickStat('Бюджет', AppUtils.formatCurrency(budgetConverted, currency: displayCurrency), AppColors.secondary),
          Container(width: 1, height: 40, color: Colors.black.withValues(alpha: 0.05)),
          _buildQuickStat('Активы', '${investmentsProvider.investments.length}', AppColors.success),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: items,
      ),
    );
  }

  void _showAvatarOptions(BuildContext context, UserProfileProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, UserProfileProvider provider) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
        await provider.updateProfile(avatarPath: savedImage.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _togglePinLock(BuildContext context, UserProfileProvider provider) async {
    if (!provider.enablePinLock) {
      final pin = await _showSetPinDialog(context);
      if (pin != null && pin.length == 4) {
        final securityService = SecurityService();
        await securityService.setPinCode(pin);
        await provider.updateProfile(enablePinLock: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN-код успешно установлен')),
          );
        }
      }
    } else {
      await provider.updateProfile(enablePinLock: false);
      final securityService = SecurityService();
      await securityService.clearAllSecureData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN-код отключен')),
        );
      }
    }
  }

  Future<String?> _showSetPinDialog(BuildContext context) async {
    String pin = '';
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Установите PIN-код'),
        content: TextField(
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: '4 цифры'),
          onChanged: (value) => pin = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (pin.length == 4) Navigator.pop(context, pin);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProfileProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _EditProfileDialog(provider: provider),
    );
  }

  void _showCurrencyPicker(BuildContext context, UserProfileProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Валюта отображения',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Все суммы будут сконвертированы в выбранную валюту',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              ...CurrencyService.supportedCurrencies.map((c) => ListTile(
                leading: Text(CurrencyService.getFlag(c), style: const TextStyle(fontSize: 28)),
                title: Text(c),
                subtitle: Text(_currencyName(c)),
                trailing: provider.displayCurrency == c
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  provider.setDisplayCurrency(c);
                  Navigator.pop(ctx);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _currencyName(String code) {
    const names = {
      'RUB': 'Российский рубль', 'USD': 'Доллар США', 'EUR': 'Евро',
      'GBP': 'Фунт стерлингов', 'CNY': 'Китайский юань', 'JPY': 'Японская иена',
      'CHF': 'Швейцарский франк', 'KZT': 'Казахстанский тенге',
      'BYN': 'Белорусский рубль', 'AMD': 'Армянский драм',
    };
    return names[code] ?? code;
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.provider});

  final UserProfileProvider provider;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _budgetController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = widget.provider.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _budgetController = TextEditingController(
      text: p != null && p.monthlyBudget > 0 ? p.monthlyBudget.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.provider.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      monthlyBudget: double.tryParse(_budgetController.text.replaceAll(',', '.')) ?? 0,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Редактировать профиль',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _FieldLabel('Имя'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Как к вам обращаться',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите имя' : null,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return null;
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                    return ok ? null : 'Некорректный email';
                  },
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Месячный бюджет'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: '50 000',
                    prefixIcon: Icon(Icons.payments_rounded),
                    suffixText: '₽',
                  ),
                  validator: (v) {
                    final value = v?.replaceAll(',', '.').trim() ?? '';
                    if (value.isEmpty) return null;
                    return double.tryParse(value) == null ? 'Введите число' : null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
    );
  }
}

/// Пара переключателей внутри группы «Банки и импорт»:
///   1. Импорт SMS — читает входящие SMS банков и делает из них черновики.
///   2. Доступ к push-уведомлениям — то же для шторки уведомлений.
///
/// На не-Android платформах ничего не показывает (no-op сервисы).
class _BankSignalsTiles extends StatelessWidget {
  const _BankSignalsTiles();

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return Consumer<BankSignalsController>(
      builder: (context, ctrl, _) {
        return Column(
          children: [
            _SettingsItem(
              icon: Icons.sms_outlined,
              title: 'Импорт SMS банков',
              subtitle: ctrl.smsEnabled
                  ? (ctrl.lastImportedDrafts > 0
                      ? 'Последний импорт: ${ctrl.lastImportedDrafts} сообщений'
                      : 'Включён — слушаем входящие SMS')
                  : 'Читать банковские SMS и создавать черновики',
              trailing: Switch.adaptive(
                value: ctrl.smsEnabled,
                onChanged: (v) async {
                  await ctrl.setSmsEnabled(v);
                  if (!context.mounted) return;
                  if (v && !ctrl.smsEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Разрешение на чтение SMS не выдано',
                        ),
                      ),
                    );
                  }
                },
                activeThumbColor: AppColors.primary,
              ),
            ),
            _SettingsItem(
              icon: Icons.notifications_active_outlined,
              title: 'Push-уведомления банков',
              subtitle: ctrl.pushEnabled
                  ? 'Включено — слушаем шторку уведомлений'
                  : ctrl.pushPermissionGranted
                      ? 'Доступ выдан, можно включить'
                      : 'Требуется доступ в настройках Android',
              trailing: Switch.adaptive(
                value: ctrl.pushEnabled,
                onChanged: (v) async {
                  await ctrl.setPushEnabled(v);
                  if (!context.mounted) return;
                  if (v && !ctrl.pushEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Доступ к уведомлениям не подтверждён',
                        ),
                      ),
                    );
                  }
                },
                activeThumbColor: AppColors.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}
