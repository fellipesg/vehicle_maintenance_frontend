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
import 'repositories/vehicle_repository.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

const Color _brandNavy = Color(0xFF0B1C2C);
const Color _brandTeal = Color(0xFF2EC4B6);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
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
      defaultValue: 'http://10.0.2.2:8081/api/v1',
    ),
  );
  late final AuthService _authService;
  late final VehicleRepository _vehicleRepository;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vehicleRepository = VehicleRepository(_apiService);
    _authService = AuthService(_apiService);
    _authService.vehicleRepository = _vehicleRepository;
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
        theme: _brandTheme,
        home: const Scaffold(
          backgroundColor: _brandNavy,
          body: Center(
            child: CircularProgressIndicator(
              color: _brandTeal,
            ),
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
      ],
      child: MaterialApp(
        navigatorKey: NotificationNavigation.navigatorKey,
        title: 'Revisalog',
        debugShowCheckedModeBanner: false,
        theme: _brandTheme,
        home: _authService.isAuthenticated
            ? const HomePage()
            : const LoginHubPage(),
      ),
    );
  }
}

final ThemeData _brandTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _brandNavy,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _brandTeal,
    onPrimary: _brandNavy,
    secondary: _brandTeal,
    onSecondary: _brandNavy,
    surface: _brandNavy,
    onSurface: Colors.white,
    error: Colors.redAccent,
    onError: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    backgroundColor: _brandNavy,
    foregroundColor: Colors.white,
  ),
);
