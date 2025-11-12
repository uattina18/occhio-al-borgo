import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class ModificaDatiScreen extends StatefulWidget {
  const ModificaDatiScreen({super.key});

  @override
  State<ModificaDatiScreen> createState() => _ModificaDatiScreenState();
}

class _ModificaDatiScreenState extends State<ModificaDatiScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _usernameController.text = data['username'] ?? '';
      _emailController.text = data['email'] ?? '';
    } else {
      _usernameController.text = prefs.getString('username') ?? '';
      _emailController.text = prefs.getString('email') ?? '';
    }
  }

  Future<void> _salvaModifiche() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome utente ed email sono obbligatori')),
      );
      return;
    }

    if (newPassword.isNotEmpty && newPassword.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La password deve avere almeno 6 caratteri'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 🔹 Aggiorna Firestore (crea se non esiste)
      await _firestore.collection('users').doc(uid).set({
        'username': username,
        'email': email,
      }, SetOptions(merge: true));

      // 🔹 Aggiorna email in Firebase Auth (con verifica)
      await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(email);

      // 🔹 Aggiorna password se compilata
      if (newPassword.isNotEmpty) {
        await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      }

      // 🔹 Aggiorna cache locale
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('email', email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Dati aggiornati. Controlla la tua email per confermare il nuovo indirizzo.',
          ),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final currentPwd = await _chiediPasswordCorrente();
        if (currentPwd != null && currentPwd.isNotEmpty) {
          try {
            final emailAttuale = user!.email!;
            final cred = EmailAuthProvider.credential(
              email: emailAttuale,
              password: currentPwd,
            );
            await user.reauthenticateWithCredential(cred);

            await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(
              email,
            );
            if (newPassword.isNotEmpty) {
              await FirebaseAuth.instance.currentUser!.updatePassword(
                newPassword,
              );
            }

            // 🔹 Aggiorna Firestore (crea se non esiste)
            await _firestore.collection('users').doc(uid).set({
              'username': username,
              'email': email,
            }, SetOptions(merge: true));

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('username', username);
            await prefs.setString('email', email);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✅ Dati aggiornati. Controlla la tua email per confermare il nuovo indirizzo.',
                ),
              ),
            );
            Navigator.pop(context);
          } on FirebaseAuthException catch (e2) {
            if (!mounted) return;
            String msg = 'Errore durante l’aggiornamento';
            if (e2.code == 'wrong-password') msg = 'Password attuale errata.';
            if (e2.code == 'invalid-email') msg = 'Email non valida.';
            if (e2.code == 'email-already-in-use') {
              msg = 'Email già in uso da un altro account.';
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Operazione annullata')));
        }
      } else {
        if (!mounted) return;
        String msg = 'Errore durante l’aggiornamento';
        if (e.code == 'invalid-email') msg = 'Email non valida.';
        if (e.code == 'email-already-in-use') msg = 'Email già in uso.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Errore sconosciuto')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _chiediPasswordCorrente() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Conferma identità',
          style: TextStyle(
            color: AppColors.foreground(context),
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Password attuale',
            filled: true,
            fillColor: AppColors.background(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(color: AppColors.foreground(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent(context),
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color topBarColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Modifica dati',
          style: TextStyle(
            color: AppColors.foreground(context),
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Aggiorna le tue informazioni',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 👤 Nome utente
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nome utente',
                      filled: true,
                      fillColor: AppColors.card(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: AppColors.foreground(context)),
                  ),
                  const SizedBox(height: 14),

                  // 📧 Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: AppColors.card(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: AppColors.foreground(context)),
                  ),
                  const SizedBox(height: 14),

                  // 🔒 Nuova password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Nuova password (facoltativa)',
                      filled: true,
                      fillColor: AppColors.card(context),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.subtext(context),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: AppColors.foreground(context)),
                  ),
                  const SizedBox(height: 30),

                  // 🔘 Bottone Salva
                  ElevatedButton(
                    onPressed: _loading ? null : _salvaModifiche,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent(context),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 30,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'SALVA MODIFICHE',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
