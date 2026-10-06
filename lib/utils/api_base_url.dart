class ApiBaseUrl {
  static const production = 'https://revisalog.com.br/api/v1';
  static const androidEmulator = 'http://10.0.2.2:8080/api/v1';

  static String resolve({
    required String fromEnvironment,
    required bool isRelease,
  }) {
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }

    return isRelease ? production : androidEmulator;
  }
}
