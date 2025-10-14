import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    await prefs.setString('password', _passwordController.text);

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📏 Verifica se la tastiera è aperta
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ evita che il layout si blocchi
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Sfondo
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.35)),

          // 📜 Contenuto principale
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Titolo sopra il logo
                  const Text(
                    'OCCHIO AL BORGO',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Spazio dinamico sopra il logo
                  SizedBox(height: isKeyboardVisible ? 10 : 20),

                  // Logo adattivo
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    width: isKeyboardVisible ? 70 : 100,
                    height: isKeyboardVisible ? 70 : 100,
                    child: Image.asset(
                      'assets/images/logo_pages.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: isKeyboardVisible ? 20 : 40),

                  // Username
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.75),
                      hintText: 'Username',
                      hintStyle: const TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Cormorant',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.75),
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Cormorant',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: isKeyboardVisible ? 20 : 40),

                  // Pulsante Login
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3a602a),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 60,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'ACCEDI',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cinzel',
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
