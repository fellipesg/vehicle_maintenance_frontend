import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthTokenStorage {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(),
            );

  final FlutterSecureStorage _storage;

  static const String tokenKey = 'auth_token';

  /// Keychain on unsigned macOS builds fails with OSStatus 13 without throwing.
  static bool get _useSecureStorage {
    if (kIsWeb) {
      return false;
    }

    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_useSecureStorage) {
      return prefs.getString(tokenKey);
    }

    try {
      final secureToken = await _storage.read(key: tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (error, stackTrace) {
      debugPrint('Secure token read failed, using fallback: $error');
      debugPrint('$stackTrace');
    }

    return prefs.getString(tokenKey);
  }

  @override
  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    if (!_useSecureStorage) {
      await prefs.setString(tokenKey, token);
      return;
    }

    try {
      await _storage.write(key: tokenKey, value: token);
      final readBack = await _storage.read(key: tokenKey);
      if (readBack == token) {
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('Secure token write failed, using fallback: $error');
      debugPrint('$stackTrace');
    }

    await prefs.setString(tokenKey, token);
  }

  @override
  Future<void> deleteToken() async {
    if (_useSecureStorage) {
      try {
        await _storage.delete(key: tokenKey);
      } catch (_) {
        // Fallback cleanup below.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }
}
