import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_home.dart';
import 'services/auth.dart';
import 'services/ble_service.dart';
import 'services/db.dart';
import 'services/emergency_service.dart';
import 'services/location_service.dart';
import 'services/mock_db.dart';
import 'widgets/phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    final opts = DefaultFirebaseOptions.currentPlatform;
    if (opts != null) {
      await Firebase.initializeApp(options: opts);
      firebaseReady = true;
    }
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final db = firebaseReady ? Db() : MockDb();
  final auth = firebaseReady ? AuthService(db) : AuthService(db, null);
  final location = LocationService();
  final emergency = EmergencyService(db, location);
  final session = SessionController(auth, db);
  final ble = BleService(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController(prefs)),
        Provider<Db>.value(value: db),
        ChangeNotifierProvider<LocationService>.value(value: location),
        Provider<EmergencyService>.value(value: emergency),
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<BleService>.value(value: ble),
      ],
      child: const SolveXApp(),
    ),
  );
}

class SolveXApp extends StatelessWidget {
  const SolveXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lc = context.watch<LocaleController>();
    return MaterialApp(
      title: 'SolveX Alert',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: lc.locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => PhoneFrameWrapper(child: child!),
      home: const AuthGate(),
    );
  }
}

/// Routes to login, user home or admin panel depending on the session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionController>();
    if (s.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final u = s.user;
    if (u == null) return const LoginScreen();
    if (u.isAdmin) return const AdminPanel();
    return const UserHome();
  }
}
