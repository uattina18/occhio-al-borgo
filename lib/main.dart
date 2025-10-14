import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scatta_screen.dart';

void main() {
  runApp(const OcchioAlBorgoApp());
}

class OcchioAlBorgoApp extends StatelessWidget {
  const OcchioAlBorgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Occhio al Borgo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),

      // 👇 schermata iniziale
      initialRoute: '/login',

      // 👇 tutte le rotte dell’app
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scatta': (context) => ScattaScreen(),
      },
    );
  }
}
