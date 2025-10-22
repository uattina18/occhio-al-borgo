import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scatta_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/notifiche_screen.dart';
import 'screens/profilo_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🔹 Flutter binding inizializzato');

  try {
    if (Firebase.apps.isEmpty) {
      print('🔹 Avvio inizializzazione Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase inizializzato con successo');
    } else {
      print('⚠️ Firebase era già inizializzato');
    }
  } catch (e) {
    print('❌ Errore durante l’inizializzazione Firebase: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    print('✅ SharedPreferences inizializzate');
    final isDark = prefs.getBool('dark_theme') ?? false;
    runApp(OcchioAlBorgoApp(isDarkTheme: isDark));
    print('✅ Applicazione avviata');
  } catch (e) {
    print('❌ Errore in SharedPreferences o avvio app: $e');
  }
}

class OcchioAlBorgoApp extends StatefulWidget {
  final bool isDarkTheme;
  const OcchioAlBorgoApp({super.key, required this.isDarkTheme});

  @override
  State<OcchioAlBorgoApp> createState() => _OcchioAlBorgoAppState();
}

class _OcchioAlBorgoAppState extends State<OcchioAlBorgoApp> {
  late bool _isDarkTheme;

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    setState(() => _isDarkTheme = value);
  }

  @override
  Widget build(BuildContext context) {
    print('🔹 Costruzione MaterialApp');
    return MaterialApp(
      title: 'Occhio al Borgo',
      debugShowCheckedModeBanner: false,
      theme: _isDarkTheme ? _darkTheme : _lightTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scatta': (context) => ScattaScreen(),
        '/explore': (context) => const ExploreScreen(),
        '/notifiche': (context) => const NotificheScreen(),
        '/profilo': (context) => const ProfiloScreen(),
        '/settings': (context) => SettingsScreen(
          currentMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          onThemeChanged: (mode) {
            final isDark = mode == ThemeMode.dark;
            _toggleTheme(isDark);
          },
        ),
      },
    );
  }
}

// 🌤️ Tema chiaro
final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF91be7e),
  scaffoldBackgroundColor: const Color(0xFFe8e9ea),
  fontFamily: 'Cinzel',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF91be7e),
    titleTextStyle: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF91be7e),
    brightness: Brightness.light,
  ),
);

// 🌙 Tema scuro
final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF3a602a),
  scaffoldBackgroundColor: const Color(0xFF121212),
  fontFamily: 'Cinzel',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF3a602a),
    titleTextStyle: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3a602a),
    brightness: Brightness.dark,
  ),
);
