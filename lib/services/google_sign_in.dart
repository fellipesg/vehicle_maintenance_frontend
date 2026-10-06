import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

/// Clientes OAuth do projeto Firebase vehicle-maintenance-a9e32. Não são segredos: o backend
/// confere o ID token com o cliente Web como audiência (services.google.token_audiences).
const googleWebClientId =
    '61844221484-b7jtd51c4apn6m9dauah8p7mqhis37e6.apps.googleusercontent.com';
const googleIosClientId =
    '61844221484-rsrsid3h95u8ndjliogu4m0t37he45ao.apps.googleusercontent.com';

/// Devolve o ID token do Google, ou null se a pessoa cancelar.
typedef GoogleIdTokenLoader = Future<String?> Function();

bool _googleSignInInitialized = false;

Future<String?> loadGoogleIdToken() async {
  final signIn = GoogleSignIn.instance;

  if (!_googleSignInInitialized) {
    await signIn.initialize(
      clientId: Platform.isIOS ? googleIosClientId : null,
      serverClientId: googleWebClientId,
    );
    _googleSignInInitialized = true;
  }

  try {
    final account = await signIn.authenticate(scopeHint: const ['email']);
    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to authenticate with Google.');
    }

    return idToken;
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return null;
    }

    throw Exception('Unable to authenticate with Google.');
  }
}
