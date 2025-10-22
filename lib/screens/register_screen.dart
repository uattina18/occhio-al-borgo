// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 🔍 1️⃣ Controllo username duplicato su Firestore
      final check = await FirebaseFirestore.instance
          .collection('utenti')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (check.docs.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username già in uso.')));
        setState(() => _loading = false);
        return;
      }

      // 🔐 2️⃣ Crea utente su Firebase Authentication
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 🧠 3️⃣ Salva dati aggiuntivi su Firestore
      await FirebaseFirestore.instance
          .collection('utenti')
          .doc(credential.user!.uid)
          .set({
            'nome': _nomeController.text.trim(),
            'cognome': _cognomeController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'createdAt': DateTime.now(),
          });

      // 👤 4️⃣ Aggiorna nome profilo Firebase
      await credential.user!.updateDisplayName(_usernameController.text.trim());

      // ✉️ 5️⃣ Invia email di verifica
      await credential.user!.sendEmailVerification();

      // 💾 6️⃣ Salva localmente per uso rapido
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameController.text.trim());
      await prefs.setString('email', _emailController.text.trim());

      // ✅ 7️⃣ Mostra messaggio e reindirizza
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata! Verifica la tua email 📩'),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Errore durante la registrazione.';
      if (e.code == 'weak-password') msg = 'La password è troppo debole.';
      if (e.code == 'email-already-in-use') msg = 'Email già registrata.';
      if (e.code == 'invalid-email') msg = 'Email non valida.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore di connessione. Riprova.')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text('Registrati', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
              ),
              TextFormField(
                controller: _cognomeController,
                decoration: const InputDecoration(labelText: 'Cognome'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Campo obbligatorio' : null,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Campo obbligatorio';
                  if (v.contains(' '))
                    return 'Lo username non può contenere spazi';
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Campo obbligatorio';
                  if (!v.contains('@') || !v.contains('.'))
                    return 'Email non valida';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password *'),
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 6 ? 'Minimo 6 caratteri' : null,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Crea account',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text(
                  'Hai già un account? Accedi',
                  style: TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
