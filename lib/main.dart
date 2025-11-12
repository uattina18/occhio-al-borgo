import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🌍 Localizzazione
import 'package:occhio_al_borgo/l10n/app_localizations.dart';

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
import 'screens/invita_amico_screen.dart';
import 'screens/modifica_dati_screen.dart';
import 'screens/segnala_evento_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/borghi_riconosciuti_screen.dart';
import 'screens/foto_borgo_screen.dart';
import 'screens/sos_screen.dart';
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

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_theme') ?? false;
  final savedLocale = prefs.getString('locale') ?? 'it';

  runApp(
    OcchioAlBorgoApp(isDarkTheme: isDark, initialLocale: Locale(savedLocale)),
  );
}

class OcchioAlBorgoApp extends StatefulWidget {
  final bool isDarkTheme;
  final Locale initialLocale;

  const OcchioAlBorgoApp({
    super.key,
    required this.isDarkTheme,
    required this.initialLocale,
  });

  @override
  State<OcchioAlBorgoApp> createState() => _OcchioAlBorgoAppState();
}

class _OcchioAlBorgoAppState extends State<OcchioAlBorgoApp> {
  late bool _isDarkTheme;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
    _locale = widget.initialLocale;
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', value);
    setState(() => _isDarkTheme = value);
  }

  void _changeLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Occhio al Borgo',
      debugShowCheckedModeBanner: false,

      // 🌍 Localizzazione
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale == null) return const Locale('it');
        for (final l in supported) {
          if (l.languageCode == deviceLocale.languageCode) return l;
        }
        return const Locale('it');
      },

      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scatta': (context) => const ScattaScreen(),
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
          onLanguageChanged: _changeLanguage,
          currentLocale: _locale,
        ),
        '/borghi_salvati': (context) => const BorghiSalvatiScreen(),
        '/borghi_visitati': (context) => const BorghiVisitatiScreen(),
        '/borghi_detail': (context) =>
            const BorgoDetailScreen(id: '', name: '', region: ''),
        '/segnala_evento': (context) => const SegnalaEventoScreen(),
        '/invita_amico': (context) => const InvitaAmicoScreen(),
        '/modifica_dati': (context) => const ModificaDatiScreen(),
        '/sos': (context) => const SosScreen(),
        '/borghi_riconosciuti': (context) => const BorghiRiconosciutiScreen(),
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ChatScreen(
            chatId: args['chatId'],
            otherUsername: args['username'],
          );
        },
        '/foto_borgo': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          String borgoName = 'Borgo';
          if (args is String) {
            borgoName = args;
          } else if (args is Map && args['borgoName'] is String) {
            borgoName = args['borgoName'];
          }
          return FotoBorgoScreen(borgoName: borgoName);
        },
      },
    );
  }
}

final ThemeData _lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF91be7e),
  scaffoldBackgroundColor: const Color(0xFFe8e9ea),
  fontFamily: 'Cinzel',
);

final ThemeData _darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF91be7e),
  scaffoldBackgroundColor: const Color(0xFF1C1C1E),
  fontFamily: 'Cinzel',
);
