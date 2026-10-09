import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'firebase_messaging_background.dart';
import 'utils/api_base_url.dart';
import 'services/push_notification_setup.dart';
import 'services/notification_navigation.dart';
import 'views/home_page.dart';
import 'views/auth/login_hub_page.dart';
import 'repositories/vehicle_repository.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_inbox.dart';
import 'services/workshop_records_inbox.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
  final themeController = ThemeController();
  await Future.wait([
    themeController.load(),
    _initializeFirebase(),
  ]);
  runApp(MyApp(themeController: themeController));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationSetup.configure();
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed (continuing): $e');
    debugPrint('$st');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ApiService _apiService = ApiService(
    baseUrl: ApiBaseUrl.resolve(
      fromEnvironment: const String.fromEnvironment('API_BASE_URL'),
      isRelease: kReleaseMode,
    ),
  );
  late final AuthService _authService;
  late final VehicleRepository _vehicleRepository;
  late final NotificationInbox _notificationInbox;
  late final WorkshopRecordsInbox _workshopRecordsInbox;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vehicleRepository = VehicleRepository(_apiService);
    _notificationInbox = NotificationInbox(_apiService);
    _workshopRecordsInbox = WorkshopRecordsInbox(_apiService);
    PushNotificationSetup.onPushReceived =
        _notificationInbox.refreshUnreadCount;
    _authService = AuthService(_apiService);
    _authService.vehicleRepository = _vehicleRepository;
    _apiService.onUnauthorized = _handleSessionExpired;
    _initializeApp();
  }

  /// Token expirado ou revogado: volta para o hub de login em vez de deixar o
  /// app "logado" errando em toda tela.
  Future<void> _handleSessionExpired() async {
    await _authService.handleUnauthorized();

    if (!mounted) {
      return;
    }

    // `home` troca para o LoginHubPage, mas as rotas empilhadas continuariam
    // em cima dele.
    NotificationNavigation.navigatorKey.currentState
        ?.popUntil((route) => route.isFirst);

    setState(() {});

    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sua sessão expirou. Entre novamente.'),
        ),
      );
  }

  Future<void> _initializeApp() async {
    await _authService.loadStoredAuth();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (_authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await PushNotificationSetup.handleInitialMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeController>.value(
      value: widget.themeController,
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          if (_isLoading) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeController.mode,
              debugShowCheckedModeBanner: false,
              home: const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          return MultiProvider(
            providers: [
              Provider<ApiService>.value(value: _apiService),
              Provider<AuthService>.value(value: _authService),
              ChangeNotifierProvider<VehicleRepository>.value(
                value: _vehicleRepository,
              ),
              ChangeNotifierProvider<NotificationInbox>.value(
                value: _notificationInbox,
              ),
              ChangeNotifierProvider<WorkshopRecordsInbox>.value(
                value: _workshopRecordsInbox,
              ),
            ],
            child: MaterialApp(
              key: const ValueKey('revisalog-app'),
              navigatorKey: NotificationNavigation.navigatorKey,
              scaffoldMessengerKey: _messengerKey,
              title: 'Revisalog',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeController.mode,
              home: _authService.isAuthenticated
                  ? const HomePage()
                  : const LoginHubPage(),
            ),
          );
        },
      ),
    );
  }
}
