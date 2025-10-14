import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cognomeController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String _errorMessage = "";
  String _error = "";

  Future<void> _onRegister() async {
    final nome = _nomeController.text.trim();
    final cognome = _cognomeController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if ([nome, cognome, username, email, password, confirm].contains("")) {
      setState(() {
        _errorMessage = "Compila tutti i campi!";
        _error = "";
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _error = "Le password non coincidono";
        _errorMessage = "";
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("nome", nome);
    await prefs.setString("cognome", cognome);
    await prefs.setString("username", username);
    await prefs.setString("email", email);
    await prefs.setString("password", password);

    debugPrint("Registrazione completata!");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registrazione completata!")),
      );
      Navigator.pop(context); // Torna al login
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con logo e titolo
            Padding(
              padding: EdgeInsets.only(top: height * 0.1, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo_pages.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    'Occhio al Borgo',
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'Cinzel',
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // Campi form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildInputBox(_nomeController, 'Nome'),
                  _buildInputBox(_cognomeController, 'Cognome'),
                  _buildInputBox(_usernameController, 'Username'),
                  _buildInputBox(
                    _emailController,
                    'Email',
                    keyboard: TextInputType.emailAddress,
                  ),
                  _buildPasswordBox(
                    _passwordController,
                    'Password',
                    _showPassword,
                    () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                  _buildPasswordBox(
                    _confirmController,
                    'Conferma Password',
                    _showConfirmPassword,
                    () {
                      setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      );
                    },
                  ),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Cormorant',
                      ),
                    ),
                  if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Cormorant',
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _onRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 30,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Registrati',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Cinzel',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Hai già un account?',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Cormorant',
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Accedi',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Cormorant',
                            color: Color(0xFF007AFF),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(
    TextEditingController controller,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontFamily: 'Cormorant',
        ),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildPasswordBox(
    TextEditingController controller,
    String hint,
    bool showPassword,
    VoidCallback onToggle,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: !showPassword,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontFamily: 'Cormorant',
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.black54),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              showPassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
              color: Colors.black,
              size: 16,
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}
