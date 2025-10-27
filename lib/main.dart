import 'package:flutter/material.dart';
import 'package:occhio_al_borgo/screens/segnala_evento_screen.dart';
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
import 'screens/borghi_salvati_screen.dart';
import 'screens/borghi_visitati_screen.dart';
import 'screens/community_screen.dart';
import 'screens/galleria_screen.dart';
import 'screens/borghi_detail_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('⚠️ Firebase non inizializzato: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_theme') ?? false;
    runApp(OcchioAlBorgoApp(isDarkTheme: isDark));
  } catch (e) {
    debugPrint('⚠️ SharedPreferences non accessibili: $e');
    runApp(const OcchioAlBorgoApp(isDarkTheme: false));
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
    return MaterialApp(
      title: 'Occhio al Borgo',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scatta': (context) => ScattaScreen(),
        '/explore': (context) => const ExploreScreen(),
        '/notifiche': (context) => const NotificheScreen(),
        '/profilo': (context) => const ProfiloScreen(),
        '/community': (context) => const CommunityScreen(),
        '/galleria': (context) => const GalleriaScreen(),
        '/settings': (context) => SettingsScreen(
          currentMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          onThemeChanged: (mode) {
            final isDark = mode == ThemeMode.dark;
            _toggleTheme(isDark);
          },
        ),
        '/borghi_salvati': (context) => const BorghiSalvatiScreen(),
        '/borghi_visitati': (context) => const BorghiVisitatiScreen(),
        '/borghi_detail': (context) =>
            const BorgoDetailScreen(id: '', name: '', region: ''),
        '/segnala_evento_screen': (context) => const SegnalaEventoScreen(),
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
    seedColor: Color(0xFF91be7e),
    brightness: Brightness.light,
  ),
);

// 🌙 Tema scuro
final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF91be7e),
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),
  fontFamily: 'Cinzel',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF3A602A),
    titleTextStyle: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF91be7e),
    secondary: Color(0xFF3a602a),
    surface: Color(0xFF2C2C2E),
    onSurface: Colors.white,
    onBackground: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white),
    titleMedium: TextStyle(color: Colors.white70),
  ),
  cardColor: const Color(0xFF2C2C2E),
  dividerColor: Colors.white24,
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const Color(0xFF91be7e)
          : Colors.grey,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const Color(0xFF577C4C)
          : Colors.white30,
    ),
  ),
);
