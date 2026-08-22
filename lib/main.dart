import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'firebase_messaging_background.dart';
import 'services/push_notification_setup.dart';
import 'services/notification_navigation.dart';
import 'views/home_page.dart';
import 'views/auth/login_hub_page.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ApiService _apiService = ApiService(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api/v1',
    ),
  );
  late final AuthService _authService;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(_apiService);
    _initializeApp();
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
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.blue.shade700,
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<AuthService>.value(value: _authService),
      ],
      child: MaterialApp(
        navigatorKey: NotificationNavigation.navigatorKey,
        title: 'Vehicle Maintenance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Colors.blue.shade700,
            secondary: Colors.orange.shade600,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home:
            _authService.isAuthenticated
                ? const HomePage()
                : const LoginHubPage(),
      ),
    );
  }
}
