import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bank_aggregator_service.dart';
import '../config/api_config.dart';
import '../utils/app_colors.dart';
import '../models/bank_models.dart';

class BankOAuthScreen extends StatefulWidget {
  final BankConfig bankConfig;
  final Function(bool success) onAuthComplete;

  const BankOAuthScreen({
    super.key,
    required this.bankConfig,
    required this.onAuthComplete,
  });

  @override
  State<BankOAuthScreen> createState() => _BankOAuthScreenState();
}

class _BankOAuthScreenState extends State<BankOAuthScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _isLoading = progress < 100);
          },
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkForCallback(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            _checkForCallback(request.url);
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.bankConfig.authUrl));
  }

  void _checkForCallback(String url) {
    // Проверяем redirect URI после авторизации
    // Разные банки используют разные callback схемы
    final callbackPatterns = [
      'coinsift://${widget.bankConfig.id}-callback',
      '${widget.bankConfig.id}://callback',
      'coinsift://bank-callback',
    ];

    for (final pattern in callbackPatterns) {
      if (url.contains(pattern)) {
        final uri = Uri.parse(url);
        final code = uri.queryParameters['code'] ??
            uri.queryParameters['auth_code'];

        if (code != null && !_isConnecting) {
          _handleAuthCode(code);
        }
        break;
      }
    }
  }

  Future<void> _handleAuthCode(String code) async {
    setState(() => _isConnecting = true);

    // Сохраняем подключённый банк
    final connectedBank = ConnectedBankInfo(
      bankId: widget.bankConfig.id,
      bankName: widget.bankConfig.name,
      connectedAt: DateTime.now(),
    );

    await BankAggregatorService.saveConnectedBank(connectedBank);

    if (mounted) {
      setState(() => _isConnecting = false);
      Navigator.pop(context);
      widget.onAuthComplete(true);
    }
  }

  void _showDemoConnect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Подключить ${widget.bankConfig.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(widget.bankConfig.color).withValues(alpha: 0.1), // Используем Color()
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.bankConfig.icon,
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'В реальном режиме откроется страница авторизации ${widget.bankConfig.fullName}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ℹ️ Сейчас подключается демо-режим\nс тестовыми данными',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isConnecting = true);

              await Future.delayed(const Duration(milliseconds: 500));

              final connectedBank = ConnectedBankInfo(
                bankId: widget.bankConfig.id,
                bankName: widget.bankConfig.name,
                connectedAt: DateTime.now(),
              );

              await BankAggregatorService.saveConnectedBank(connectedBank);

              if (mounted) {
                setState(() => _isConnecting = false);
                widget.onAuthComplete(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(widget.bankConfig.color), // Используем Color()
              foregroundColor: widget.bankConfig.id == 'tinkoff'
                  ? Colors.black
                  : Colors.white,
            ),
            child: Text('Подключить ${widget.bankConfig.name}'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Подключение: ${widget.bankConfig.fullName}'),
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                widget.onAuthComplete(false);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(widget.bankConfig.color).withValues(alpha: 0.1), // Используем Color()
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        widget.bankConfig.icon,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Подключение к ${widget.bankConfig.name}...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Демо кнопка поверх WebView
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Демо режим',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Для демонстрации нажмите кнопку ниже',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDemoConnect,
                        icon: const Icon(Icons.check_circle),
                        label: Text('Подключить ${widget.bankConfig.name} (Демо)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(widget.bankConfig.color), // Используем Color()
                          foregroundColor: widget.bankConfig.id == 'tinkoff'
                              ? Colors.black
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}