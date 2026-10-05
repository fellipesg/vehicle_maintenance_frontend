import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInCredential {
  const AppleSignInCredential({
    required this.identityToken,
    required this.rawNonce,
    this.givenName,
    this.familyName,
  });

  final String identityToken;
  final String rawNonce;
  final String? givenName;
  final String? familyName;

  String? get displayName {
    final parts = [givenName, familyName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' ');
  }
}

typedef AppleCredentialLoader = Future<AppleSignInCredential?> Function();

Future<AppleSignInCredential?> loadAppleSignInCredential() async {
  final rawNonce = generateNonce();
  final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

  try {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final identityToken = credential.identityToken;

    if (identityToken == null || identityToken.isEmpty) {
      throw Exception('Unable to authenticate with Apple.');
    }

    return AppleSignInCredential(
      identityToken: identityToken,
      rawNonce: rawNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  } on SignInWithAppleAuthorizationException catch (error) {
    if (error.code == AuthorizationErrorCode.canceled) {
      return null;
    }

    throw Exception('Unable to authenticate with Apple.');
  }
}
