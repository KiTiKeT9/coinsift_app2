import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/security_service.dart';
import '../utils/app_colors.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const PinLockScreen({super.key, required this.onSuccess});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final SecurityService _securityService = SecurityService();
  String _enteredPin = '';
  bool _isError = false;
  bool _isLoading = true;
  Duration _lockout = Duration.zero;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await _securityService.hasPinCode();
    final lockout = await _securityService.remainingLockout();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _lockout = lockout;
      });
      if (lockout > Duration.zero) _startLockoutTimer();
    }
    if (!hasPin) {
      widget.onSuccess();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final remaining = await _securityService.remainingLockout();
      if (!mounted) return;
      if (remaining <= Duration.zero) {
        t.cancel();
        setState(() => _lockout = Duration.zero);
      } else {
        setState(() => _lockout = remaining);
      }
    });
  }

  bool get _locked => _lockout > Duration.zero;

  String _formatLockout(Duration d) {
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${d.inSeconds} с';
  }

  void _onNumberPressed(String number) {
    if (_locked) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _isError = false;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_locked) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await _securityService.verifyPinCode(_enteredPin);
    if (isValid) {
      HapticFeedback.mediumImpact();
      widget.onSuccess();
    } else {
      HapticFeedback.heavyImpact();
      final lockout = await _securityService.remainingLockout();
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _isError = true;
        _lockout = lockout;
      });
      if (lockout > Duration.zero) _startLockoutTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkGradient : AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Logo or Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 24),
              
              Text(
                _locked ? 'Временно заблокировано' : 'Введите PIN-код',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 200.ms),

              if (_locked) ...[
                const SizedBox(height: 12),
                Text(
                  'Повторите через ${_formatLockout(_lockout)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 48),
              
              // PIN Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError 
                        ? Colors.redAccent 
                        : (isFilled ? Colors.white : Colors.white.withValues(alpha: 0.25)),
                      boxShadow: isFilled ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 10,
                        )
                      ] : [],
                    ),
                  );
                }),
              ).animate(target: _isError ? 1 : 0)
               .shake(hz: 6, curve: Curves.easeInOut),
              
              const Spacer(flex: 1),
              
              // Keyboard
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 1,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox.shrink();
                    if (index == 10) return _buildKeyboardButton('0');
                    if (index == 11) return _buildDeleteButton();
                    return _buildKeyboardButton('${index + 1}');
                  },
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () => _showRecoveryOptions(context),
                child: Text(
                  'Забыли PIN-код?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardButton(String label) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _onNumberPressed(label);
        },
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _onDeletePressed();
        },
        customBorder: const CircleBorder(),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _showRecoveryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Восстановление доступа',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildRecoveryTile(
              icon: Icons.vpn_key_outlined,
              title: 'Кодовое слово',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            _buildRecoveryTile(
              icon: Icons.phone_android_outlined,
              title: 'Номер телефона',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.black.withValues(alpha: 0.03),
    );
  }
}
