import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('email');

      // Attendi che Firebase sia pronto
      await Future.delayed(const Duration(milliseconds: 500));
      final user = _auth.currentUser;

      if (user != null && savedEmail != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } else {
        await prefs.remove('email');
      }
    } catch (e) {
      print('Errore _checkRememberedUser: $e');
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('email', _emailController.text.trim());
      } else {
        await prefs.remove('email');
      }

      if (credential.user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Errore di accesso.';
      if (e.code == 'user-not-found') msg = 'Utente non trovato.';
      if (e.code == 'wrong-password') msg = 'Password errata.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore imprevisto, riprova.')),
      );
      print('Errore generico login: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithBiometric() async {
    try {
      final canAuthenticate =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometria non supportata')),
        );
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Autenticati per accedere',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        final user = _auth.currentUser;
        if (user != null && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessun utente salvato, effettua prima un login.'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante l’autenticazione biometrica'),
        ),
      );
      print('Errore biometria: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  SizedBox(height: isKeyboardVisible ? 10 : 20),
                  SizedBox(
                    width: isKeyboardVisible ? 70 : 100,
                    height: isKeyboardVisible ? 70 : 100,
                    child: Image.asset(
                      'assets/images/logo_pages.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: isKeyboardVisible ? 20 : 40),

                  // Email
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.75),
                      hintText: 'Email',
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
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.75),
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        color: Colors.black54,
                        fontFamily: 'Cormorant',
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Ricordami
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        activeColor: const Color(0xFF91be7e),
                      ),
                      const Text(
                        'Rimani connesso',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cormorant',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Pulsanti
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                          children: [
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
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _loginWithBiometric,
                              icon: const Icon(
                                Icons.fingerprint,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Accedi con impronta',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Cinzel',
                                  fontSize: 16,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text(
                      'Non hai un account? Registrati',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cormorant',
                        fontSize: 16,
                        decoration: TextDecoration.underline,
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
