import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class BloccatiScreen extends StatefulWidget {
  const BloccatiScreen({super.key});

  @override
  State<BloccatiScreen> createState() => _BloccatiScreenState();
}

class _BloccatiScreenState extends State<BloccatiScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final List blockedIds = doc.data()?['blockedUsers'] ?? [];

      final List<Map<String, dynamic>> users = [];
      for (final id in blockedIds) {
        final userDoc = await _firestore.collection('users').doc(id).get();
        if (userDoc.exists) {
          users.add({
            'id': id,
            'username': userDoc.data()?['username'] ?? 'Utente sconosciuto',
            'photoUrl': userDoc.data()?['photoUrl'],
          });
        }
      }

      setState(() {
        _blockedUsers = users;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Errore caricamento utenti bloccati: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _unblockUser(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      setState(() {
        _blockedUsers.removeWhere((u) => u['id'] == userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Utente sbloccato con successo')),
      );
    } catch (e) {
      debugPrint('❌ Errore sblocco utente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          'Utenti bloccati',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
          ? const Center(
              child: Text(
                'Nessun utente bloccato',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _blockedUsers.length,
              itemBuilder: (context, i) {
                final u = _blockedUsers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: u['photoUrl'] != null
                          ? NetworkImage(u['photoUrl'])
                          : null,
                      backgroundColor: const Color(0xFF91be7e),
                      child: u['photoUrl'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      u['username'],
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.lock_open, color: Colors.red),
                      tooltip: 'Sblocca utente',
                      onPressed: () => _unblockUser(u['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
