import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../home_page.dart';
import 'dart:convert';

class OAuthWebViewPage extends StatefulWidget {
  final String provider;
  final String redirectUrl;

  const OAuthWebViewPage({
    super.key,
    required this.provider,
    required this.redirectUrl,
  });

  @override
  State<OAuthWebViewPage> createState() => _OAuthWebViewPageState();
}

class _OAuthWebViewPageState extends State<OAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        // Use a real browser User-Agent to bypass Google's restrictions
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Check if this is the callback URL with the code parameter
            // Only process once when page finishes loading
            if (url.contains('/auth/${widget.provider}/callback') &&
                !_isProcessing) {
              final uri = Uri.parse(url);
              // Only process if we have the 'code' parameter (OAuth success)
              // or 'error' parameter (OAuth failure)
              if (uri.queryParameters.containsKey('code') ||
                  uri.queryParameters.containsKey('error')) {
                _handleCallback(url);
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Intercept navigation to callback URL
            if (request.url.contains('/auth/${widget.provider}/callback') &&
                !_isProcessing) {
              final uri = Uri.parse(request.url);
              if (uri.queryParameters.containsKey('code') ||
                  uri.queryParameters.containsKey('error')) {
                // Prevent navigation and handle callback
                _handleCallback(request.url);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted && !_isProcessing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Erro ao carregar página: ${error.description}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  Future<void> _handleCallback(String url) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Extract query parameters from the callback URL
      final uri = Uri.parse(url);
      final queryParams = uri.queryParameters;

      // Check if we have an error from OAuth
      if (queryParams.containsKey('error')) {
        throw Exception(
            'Erro no OAuth: ${queryParams['error']} - ${queryParams['error_description'] ?? ''}');
      }

      // Verify we have the code parameter
      if (!queryParams.containsKey('code')) {
        // If we don't have code yet, wait a bit and check again
        // This might be an intermediate redirect
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }

      // Process the OAuth callback
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.processOAuthCallback(widget.provider, queryParams);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar login: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Wait a bit before going back
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login com ${widget.provider.toUpperCase()}'),
        leading: _isProcessing
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || _isProcessing)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _isProcessing ? 'Processando login...' : 'Carregando...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
