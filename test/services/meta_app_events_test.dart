import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_maintenance/services/meta_app_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('br.com.revisalog.app/meta_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends only the event name, with no parameters', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final events = MetaAppEvents(isSupported: () => true);

    await events.logCompleteRegistration();
    await events.logVehicleAdded();

    expect(calls.map((c) => c.method), ['log', 'log']);
    expect(calls.map((c) => c.arguments), [
      'complete_registration',
      'vehicle_added',
    ]);
  });

  test('does nothing outside iOS', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });

    await MetaAppEvents(isSupported: () => false).logVehicleAdded();

    expect(called, isFalse);
  });

  test('swallows a missing native channel', () async {
    messenger.setMockMethodCallHandler(channel, null);

    await MetaAppEvents(isSupported: () => true).logCompleteRegistration();
  });

  test('swallows a platform error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    await MetaAppEvents(isSupported: () => true).logVehicleAdded();
  });
}
