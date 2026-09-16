import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_maintenance/services/auth_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureAuthTokenStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores and reads token via SharedPreferences on desktop', () async {
      final storage = SecureAuthTokenStorage();

      await storage.writeToken('desktop-token');
      final token = await storage.readToken();

      expect(token, 'desktop-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureAuthTokenStorage.tokenKey), 'desktop-token');
    });

    test('deleteToken clears SharedPreferences token', () async {
      final storage = SecureAuthTokenStorage();

      await storage.writeToken('to-delete');
      await storage.deleteToken();

      expect(await storage.readToken(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SecureAuthTokenStorage.tokenKey), isNull);
    });
  });
}
