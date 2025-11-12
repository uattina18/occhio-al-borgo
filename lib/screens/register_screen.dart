import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();

  File? _avatarFile;
  bool _loading = false;

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Controlla se username esiste già
      final existing = await firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username già in uso.')));
        setState(() => _loading = false);
        return;
      }

      // 2️⃣ Crea utente in Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = credential.user!.uid;
      String? photoUrl;

      // 3️⃣ Se ha scelto un avatar, caricalo su Firebase Storage
      if (_avatarFile != null) {
        final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
        await ref.putFile(_avatarFile!);
        photoUrl = await ref.getDownloadURL();
      }

      // 4️⃣ Crea documento utente su Firestore (sempre)
      await firestore.collection('users').doc(uid).set({
        'uid': uid,
        'nome': _nomeController.text.trim(),
        'cognome': _cognomeController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // ✅ merge: true per sicurezza

      // 5️⃣ Aggiorna profilo Firebase Auth
      await credential.user!.updateDisplayName(_usernameController.text.trim());
      if (photoUrl != null) {
        await credential.user!.updatePhotoURL(photoUrl);
      }

      // 6️⃣ Invia email di verifica
      await credential.user!.sendEmailVerification();

      // 7️⃣ Salva dati base localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('username', _usernameController.text.trim());
      await prefs.setString('email', _emailController.text.trim());
      if (photoUrl != null) await prefs.setString('photoUrl', photoUrl);

      // 8️⃣ Conferma e redirect
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
      switch (e.code) {
        case 'weak-password':
          msg = 'La password è troppo debole.';
          break;
        case 'email-already-in-use':
          msg = 'Questa email è già registrata.';
          break;
        case 'invalid-email':
          msg = 'Email non valida.';
          break;
        default:
          msg = e.message ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore imprevisto: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.foreground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Scegli dalla galleria'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta una foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Rimuovi foto',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _avatarFile = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Registrati', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: AppColors.primary(context),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 👤 Anteprima immagine profilo
              GestureDetector(
                onTap: _showAvatarOptions,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary(context),
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!)
                      : null,
                  child: _avatarFile == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.foreground(context),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
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
                  if (v == null || v.trim().isEmpty) {
                    return 'Campo obbligatorio';
                  }
                  if (v.contains(' ')) {
                    return 'Lo username non può contenere spazi';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Campo obbligatorio';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Email non valida';
                  }
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
                    ? CircularProgressIndicator(
                        color: AppColors.foreground(context),
                      )
                    : Text(
                        'Crea account',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: AppColors.foreground(context),
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: Text(
                  'Hai già un account? Accedi',
                  style: TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 15,
                    color: AppColors.foreground(context),
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
