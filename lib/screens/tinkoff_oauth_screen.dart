import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tinkoff_api_service.dart';
import '../utils/app_colors.dart';

class TinkoffOAuthScreen extends StatefulWidget {
  final Function(bool success) onAuthComplete;
  
  const TinkoffOAuthScreen({
    super.key,
    required this.onAuthComplete,
  });

  @override
  State<TinkoffOAuthScreen> createState() => _TinkoffOAuthScreenState();
}

class _TinkoffOAuthScreenState extends State<TinkoffOAuthScreen> {
  late WebViewController _controller;
  bool _isLoading = true;

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
        ),
      )
      ..loadRequest(Uri.parse(TinkoffApiService.getOAuthUrl()));
  }

  void _checkForCallback(String url) {
    // Проверяем redirect URI после авторизации
    if (url.contains('monetka://tinkoff-callback')) {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final _ = uri.queryParameters['state'];

      if (code != null) {
        _handleAuthCode(code);
      }
    }
  }

  Future<void> _handleAuthCode(String code) async {
    final success = await TinkoffApiService.handleAuthCode(code);
    
    if (mounted) {
      Navigator.pop(context);
      widget.onAuthComplete(success);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Tinkoff успешно подключен!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подключение Tinkoff'),
        actions: [
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
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Загрузка страницы авторизации...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
