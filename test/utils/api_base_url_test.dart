import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/utils/api_base_url.dart';

void main() {
  group('ApiBaseUrl.resolve', () {
    test('uses dart-define when provided, even in debug', () {
      expect(
        ApiBaseUrl.resolve(
          fromEnvironment: 'https://revisalog.com.br/api/v1',
          isRelease: false,
        ),
        ApiBaseUrl.production,
      );
    });

    test('defaults to production in release without dart-define', () {
      expect(
        ApiBaseUrl.resolve(fromEnvironment: '', isRelease: true),
        ApiBaseUrl.production,
      );
    });

    test('defaults to the Android emulator in debug without dart-define', () {
      expect(
        ApiBaseUrl.resolve(fromEnvironment: '', isRelease: false),
        ApiBaseUrl.androidEmulator,
      );
    });
  });
}
