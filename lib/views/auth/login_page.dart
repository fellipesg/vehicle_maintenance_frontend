import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple_ui;
import 'package:url_launcher/url_launcher.dart';
import '../home_page.dart';
import '../../models/login_portal.dart';
import '../../models/login_result.dart';
import '../../services/apple_sign_in.dart';
import '../../services/google_sign_in.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'oauth_webview_page.dart';
import 'register_page.dart';
import 'two_factor_challenge_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.portal = LoginPortal.usuario,
    this.appleSignInEnabled,
    this.loadAppleCredential = loadAppleSignInCredential,
    this.loadGoogleToken = loadGoogleIdToken,
    this.browserSocialLoginEnabled = false,
  });

  final LoginPortal portal;

  /// When null, Sign in with Apple is offered only on iOS.
  final bool? appleSignInEnabled;

  final AppleCredentialLoader loadAppleCredential;

  /// Login nativo com Google (google_sign_in): devolve o ID token ou null se cancelar.
  final GoogleIdTokenLoader loadGoogleToken;

  /// Facebook e X pelo navegador: o login não volta ao app e a API responde OAUTH_NOT_CONFIGURED.
  /// Ficam escondidos até ganharem login nativo, como o Google.
  final bool browserSocialLoginEnabled;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  LoginPortal get _portal => widget.portal;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        portal: _portal.apiValue,
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case LoginSuccess():
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        case LoginNeedsTwoFactor(:final challengeToken):
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TwoFactorChallengePage(
                challengeToken: challengeToken,
              ),
            ),
          );
        case LoginFailure():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao fazer login. Verifique suas credenciais.'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    if (raw.contains('Este portal') ||
        raw.contains('acesso a este portal') ||
        raw.contains('does not have access to this portal')) {
      return 'Esta conta não tem acesso a este portal.';
    }
    if (raw.contains('Unable to authenticate with Google')) {
      return 'Não foi possível entrar com o Google. Tente novamente.';
    }
    if (raw.contains('Unable to authenticate with Apple')) {
      return 'Não foi possível entrar com a Apple. Tente novamente.';
    }
    if (raw.contains('did not share an email')) {
      return 'A Apple não enviou um e-mail. Entre novamente e permita compartilhar o e-mail. O e-mail oculto da Apple também funciona.';
    }
    if (raw.contains('401') || raw.contains('Invalid login')) {
      return 'Credenciais inválidas.';
    }
    if (raw.contains('SecureStorage') ||
        raw.contains('Keychain') ||
        raw.contains('OSStatus')) {
      return 'Login ok na API, mas falhou ao salvar a sessão neste dispositivo. Tente novamente.';
    }
    return raw;
  }

  bool get _showAppleSignIn => widget.appleSignInEnabled ?? Platform.isIOS;

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await widget.loadAppleCredential();
      if (credential == null || !mounted) {
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.loginWithApple(
        identityToken: credential.identityToken,
        rawNonce: credential.rawNonce,
        name: credential.displayName,
        portal: _portal.apiValue,
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case LoginSuccess():
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        case LoginNeedsTwoFactor(:final challengeToken):
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TwoFactorChallengePage(
                challengeToken: challengeToken,
              ),
            ),
          );
        case LoginFailure():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Não foi possível entrar com a Apple. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final idToken = await widget.loadGoogleToken();
      if (idToken == null || !mounted) {
        return;
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.loginWithGoogle(
        idToken: idToken,
        portal: _portal.apiValue,
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case LoginSuccess():
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        case LoginNeedsTwoFactor(:final challengeToken):
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TwoFactorChallengePage(
                challengeToken: challengeToken,
              ),
            ),
          );
        case LoginFailure():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Não foi possível entrar com o Google. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSSOLogin(String provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final redirectUrl = await authService.getOAuthRedirectUrl(provider,
          forceAccountSelection: true);

      if (redirectUrl != null && mounted) {
        final uri = Uri.parse(redirectUrl);
        bool useNativeBrowser = false;

        if (await canLaunchUrl(uri)) {
          try {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            useNativeBrowser = true;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Por favor, complete o login no navegador. '
                    'Você será redirecionado de volta ao app após o login.',
                  ),
                  duration: Duration(seconds: 5),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          } catch (_) {
            useNativeBrowser = false;
          }
        }

        if (!useNativeBrowser && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OAuthWebViewPage(
                provider: provider,
                redirectUrl: redirectUrl,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer login com $provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _portal.accent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_portal.icon, size: 32, color: accent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _portal.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _portal.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Por favor, insira um e-mail válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira sua senha';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('login_submit_button'),
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Entrar'),
                ),
                TextButton(
                  key: const Key('login_forgot_password'),
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ForgotPasswordPage(
                                initialEmail: _emailController.text.trim(),
                              ),
                            ),
                          ),
                  child: const Text('Esqueci minha senha'),
                ),
                if (_portal.supportsSocialLogin) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OU',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_showAppleSignIn) ...[
                    apple_ui.SignInWithAppleButton(
                      key: const Key('login_apple_button'),
                      onPressed: _isLoading ? null : () => _handleAppleLogin(),
                      text: 'Continuar com a Apple',
                      height: 52,
                      style: Theme.of(context).brightness == Brightness.dark
                          ? apple_ui.SignInWithAppleButtonStyle.white
                          : apple_ui.SignInWithAppleButtonStyle.black,
                      iconAlignment: apple_ui.IconAlignment.left,
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _handleGoogleLogin(),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continuar com Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (widget.browserSocialLoginEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _handleSSOLogin('facebook'),
                      icon: const Icon(Icons.facebook, size: 28),
                      label: const Text('Continuar com Facebook'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _isLoading ? null : () => _handleSSOLogin('twitter'),
                      icon: const Icon(Icons.alternate_email, size: 28),
                      label: const Text('Continuar com Twitter/X'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('← Outros tipos de acesso'),
                ),
                if (_portal.canRegister)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(_portal.registerCta),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
