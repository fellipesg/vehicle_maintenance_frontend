import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_error.dart';
import '../../services/api_service.dart';

typedef InviteUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _defaultOpener(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Card "Avisar o cliente" da OS sem dono (`owner_status == pending`).
///
/// WhatsApp: o servidor devolve a URL `wa.me` e a oficina envia do próprio
/// celular; o número não é guardado. E-mail: um por OS, com limite diário.
class CustomerInviteCard extends StatefulWidget {
  const CustomerInviteCard({
    super.key,
    required this.maintenanceId,
    this.whatsappInvitedAt,
    this.emailInvitedAt,
    this.openUrl = _defaultOpener,
  });

  final int maintenanceId;
  final DateTime? whatsappInvitedAt;
  final DateTime? emailInvitedAt;
  final InviteUrlOpener openUrl;

  @override
  State<CustomerInviteCard> createState() => _CustomerInviteCardState();
}

class _CustomerInviteCardState extends State<CustomerInviteCard> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _whatsappAt;
  DateTime? _emailAt;
  bool _sendingWhatsapp = false;
  bool _sendingEmail = false;
  String? _whatsappError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _whatsappAt = widget.whatsappInvitedAt;
    _emailAt = widget.emailInvitedAt;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  static DateTime? _parse(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static dynamic _data(dynamic body) => body is Map ? body['data'] : null;

  Future<void> _sendWhatsapp() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 13) {
      setState(() => _whatsappError = 'Informe o telefone com DDD.');
      return;
    }

    setState(() {
      _sendingWhatsapp = true;
      _whatsappError = null;
    });

    try {
      final response = await context
          .read<ApiService>()
          .sendWhatsappInvite(widget.maintenanceId, digits);
      final data = _data(response.data);
      final url = data is Map ? data['url']?.toString() : null;

      if (url == null || url.isEmpty) {
        throw const ApiException('Não foi possível gerar o link do WhatsApp.');
      }

      final opened = await widget.openUrl(Uri.parse(url));

      if (!mounted) {
        return;
      }

      setState(() {
        _sendingWhatsapp = false;
        _whatsappAt =
            _parse(data is Map ? data['whatsapp_invited_at'] : null) ??
                DateTime.now();
        if (!opened) {
          _whatsappError = 'Não foi possível abrir o WhatsApp neste aparelho.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingWhatsapp = false;
          _whatsappError = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = 'Informe um e-mail válido.');
      return;
    }

    setState(() {
      _sendingEmail = true;
      _emailError = null;
    });

    try {
      final response = await context
          .read<ApiService>()
          .sendEmailInvite(widget.maintenanceId, email);
      final data = _data(response.data);

      if (!mounted) {
        return;
      }

      setState(() {
        _sendingEmail = false;
        _emailAt = _parse(data is Map ? data['email_invited_at'] : null) ??
            DateTime.now();
        _emailController.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingEmail = false;
          // 409, 429 e 422 trazem a mensagem pronta do servidor.
          _emailError = apiErrorMessage(
            e,
            fallback: 'Não foi possível enviar para este e-mail.',
          );
        });
      }
    }
  }

  String _sentAt(DateTime at) =>
      'Enviado em ${DateFormat('dd/MM/yyyy HH:mm').format(at.toLocal())}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('customer_invite_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Avisar o cliente',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Convide o cliente para criar a conta e assumir o carro. O '
              'telefone não é guardado; do e-mail guardamos só um código '
              'irreversível.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('invite_phone_field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'WhatsApp do cliente (com DDD)',
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
                errorText: _whatsappError,
                helperText: _whatsappAt != null ? _sentAt(_whatsappAt!) : null,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('invite_whatsapp_button'),
              onPressed: _sendingWhatsapp ? null : _sendWhatsapp,
              icon: const Icon(Icons.chat),
              label: Text(
                _sendingWhatsapp ? 'Gerando...' : 'Enviar pelo WhatsApp',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('invite_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-mail do cliente',
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
                errorText: _emailError,
                helperText: _emailAt != null ? _sentAt(_emailAt!) : null,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('invite_email_button'),
              onPressed: _sendingEmail ? null : _sendEmail,
              icon: const Icon(Icons.send),
              label: Text(_sendingEmail ? 'Enviando...' : 'Enviar por e-mail'),
            ),
          ],
        ),
      ),
    );
  }
}
