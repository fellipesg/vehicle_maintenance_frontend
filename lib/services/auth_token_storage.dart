import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthTokenStorage {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String tokenKey = 'auth_token';

  @override
  Future<String?> readToken() => _storage.read(key: tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: tokenKey, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: tokenKey);
}
