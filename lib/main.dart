// main.dart

import 'package:filq/providers/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/upload_service.dart';
import 'services/notification_service.dart';
// FIX: import PlayerService for audio background init
import 'services/player_service.dart';
import 'providers/wallet_provider.dart';
import 'providers/earn_provider.dart';
import 'providers/task_provider.dart';
import 'providers/support_provider.dart';
import 'providers/app_config_provider.dart';
import 'providers/media_provider.dart';
// FIX: PlayerProvider added
import 'providers/player_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/support_screen.dart';
import 'screens/withdraw_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/earn_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/history_screen.dart';

import 'screens/leaderboard_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // FIX: Removed Workmanager().initialize() — workmanager is NOT in pubspec.yaml
  // and campaignTrackingDispatcher is undefined. Remove or add the package if needed.

  // FIX: Init audio background for just_audio_background
  await initAudioBackground();

  final apiService = ApiService();
  final authService = AuthService(apiService);
  await authService.init();

  runApp(MultiProvider(
    providers: [
      Provider<ApiService>.value(value: apiService),
      Provider<AuthService>.value(value: authService),
      Provider<UploadService>(create: (_) => UploadService(apiService)),
      ChangeNotifierProvider(create: (_) => AppConfigProvider(apiService)),
      ChangeNotifierProvider(create: (_) => WalletProvider(apiService)),
      ChangeNotifierProvider(create: (_) => EarnProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider(apiService)),
      ChangeNotifierProvider(create: (_) => SupportProvider(apiService)),
      ChangeNotifierProvider(create: (_) => LeaderboardProvider(apiService)),
      ChangeNotifierProvider(create: (_) => MediaProvider(apiService)),
      // FIX: PlayerProvider was missing — player features won't work without this
      ChangeNotifierProvider(create: (_) => PlayerProvider()),
    ],
    child: const FilqApp(),
  ));
}

class FilqApp extends StatefulWidget {
  const FilqApp({Key? key}) : super(key: key);
  @override
  State<FilqApp> createState() => _FilqAppState();
}

class _FilqAppState extends State<FilqApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Filq',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C853),
          secondary: Color(0xFF00C853),
          surface: Color(0xFF0A0E1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        fontFamily: 'Roboto',
        useMaterial3: false,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/referral': (_) => const ReferEarnScreen(),
        '/support': (_) => const SupportScreen(),
        '/withdraw': (_) => const WithdrawScreen(),
        '/tasks': (_) => const TasksScreen(),
        '/earn': (_) => const EarnScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/history': (_) => const HistoryScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
      },
    );
  }
}
