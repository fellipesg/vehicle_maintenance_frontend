import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Clientes OAuth do projeto Firebase vehicle-maintenance-a9e32. Não são segredos: o backend
/// confere o ID token com o cliente Web como audiência (services.google.token_audiences).
const googleWebClientId =
    '61844221484-b7jtd51c4apn6m9dauah8p7mqhis37e6.apps.googleusercontent.com';
const googleIosClientId =
    '61844221484-rsrsid3h95u8ndjliogu4m0t37he45ao.apps.googleusercontent.com';

/// Devolve o ID token do Google, ou null se a pessoa cancelar.
typedef GoogleIdTokenLoader = Future<String?> Function();

/// google_sign_in fica na 6.x: a 7.x exige GoogleSignIn 8+ no iOS, incompatível com o Firebase 10.
final _googleSignIn = GoogleSignIn(
  clientId: Platform.isIOS ? googleIosClientId : null,
  serverClientId: googleWebClientId,
  scopes: const ['email'],
);

Future<String?> loadGoogleIdToken() async {
  try {
    // Sai da sessão anterior para a pessoa sempre poder escolher a conta.
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();

    if (account == null) {
      return null;
    }

    final idToken = (await account.authentication).idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to authenticate with Google.');
    }

    return idToken;
  } on PlatformException catch (error) {
    if (error.code == GoogleSignIn.kSignInCanceledError) {
      return null;
    }

    throw Exception('Unable to authenticate with Google.');
  }
}
