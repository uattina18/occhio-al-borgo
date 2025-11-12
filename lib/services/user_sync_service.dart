import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // ✅ serve per kDebugMode

class UserSyncService {
  /// Sincronizza i dati utente da Firestore a SharedPreferences
  /// Restituisce i dati aggiornati o null se non trovati.
  static Future<Map<String, dynamic>?> syncUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('⚠️ Sync: nessun utente autenticato');
        return null;
      }

      final uid = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        if (kDebugMode)
          print('⚠️ Sync: documento Firestore non trovato per $uid');
        return null;
      }

      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();

      // 🔄 Aggiorna i dati base e stampa log se cambia qualcosa
      final oldUsername = prefs.getString('username');
      final oldEmail = prefs.getString('email');
      final oldPhoto = prefs.getString('photoUrl');

      final newUsername = data['username'] ?? '';
      final newEmail = data['email'] ?? user.email ?? '';
      final newPhoto = data['photoUrl'];

      await prefs.setString('username', newUsername);
      await prefs.setString('email', newEmail);

      if (newPhoto != null && newPhoto.toString().isNotEmpty) {
        await prefs.setString('photoUrl', newPhoto);
      } else {
        await prefs.remove('photoUrl');
      }

      if (kDebugMode) {
        if (oldUsername != newUsername) {
          print('🔁 Sync: username aggiornato → $newUsername');
        }
        if (oldEmail != newEmail) {
          print('🔁 Sync: email aggiornata → $newEmail');
        }
        if (oldPhoto != newPhoto) {
          print('🔁 Sync: photoUrl aggiornato → $newPhoto');
        }
        if (oldUsername == newUsername &&
            oldEmail == newEmail &&
            oldPhoto == newPhoto) {
          print('✅ Sync: nessuna modifica rilevata');
        }
      }

      return data;
    } catch (e) {
      if (kDebugMode) print('❌ Errore durante la sincronizzazione utente: $e');
      return null;
    }
  }
}
