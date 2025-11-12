import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 🔹 Invia una richiesta d’amicizia
  static Future<String> sendRequest(String receiverId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == receiverId) return 'Utente non valido';

    final userRef = _firestore.collection('users').doc(uid);
    final receiverRef = _firestore.collection('users').doc(receiverId);

    try {
      await _firestore.runTransaction((txn) async {
        final userDoc = await txn.get(userRef);
        final receiverDoc = await txn.get(receiverRef);

        final userData = userDoc.data() ?? {};
        final receiverData = receiverDoc.data() ?? {};

        final List sent = List.from(userData['sentRequests'] ?? []);
        final List pending = List.from(receiverData['pendingRequests'] ?? []);
        final List friends = List.from(userData['friends'] ?? []);

        if (friends.contains(receiverId)) {
          throw Exception('Siete già amici');
        }
        if (sent.contains(receiverId)) {
          throw Exception('Richiesta già inviata');
        }

        sent.add(receiverId);
        pending.add(uid);

        txn.update(userRef, {'sentRequests': sent});
        txn.update(receiverRef, {'pendingRequests': pending});
      });

      return 'Richiesta inviata con successo!';
    } catch (e) {
      return 'Errore: ${e.toString()}';
    }
  }

  /// 🔹 Accetta una richiesta
  static Future<void> acceptRequest(String requesterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userRef = _firestore.collection('users').doc(uid);
    final requesterRef = _firestore.collection('users').doc(requesterId);

    await _firestore.runTransaction((txn) async {
      final userDoc = await txn.get(userRef);
      final requesterDoc = await txn.get(requesterRef);

      final userData = userDoc.data() ?? {};
      final requesterData = requesterDoc.data() ?? {};

      final List userFriends = List.from(userData['friends'] ?? []);
      final List requesterFriends = List.from(requesterData['friends'] ?? []);
      final List pending = List.from(userData['pendingRequests'] ?? []);
      final List sent = List.from(requesterData['sentRequests'] ?? []);

      userFriends.add(requesterId);
      requesterFriends.add(uid);

      pending.remove(requesterId);
      sent.remove(uid);

      txn.update(userRef, {
        'friends': userFriends,
        'pendingRequests': pending,
      });
      txn.update(requesterRef, {
        'friends': requesterFriends,
        'sentRequests': sent,
      });
    });
  }

  /// 🔹 Rifiuta una richiesta
  static Future<void> rejectRequest(String requesterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userRef = _firestore.collection('users').doc(uid);
    final requesterRef = _firestore.collection('users').doc(requesterId);

    await _firestore.runTransaction((txn) async {
      final userDoc = await txn.get(userRef);
      final requesterDoc = await txn.get(requesterRef);

      final userData = userDoc.data() ?? {};
      final requesterData = requesterDoc.data() ?? {};

      final List pending = List.from(userData['pendingRequests'] ?? []);
      final List sent = List.from(requesterData['sentRequests'] ?? []);

      pending.remove(requesterId);
      sent.remove(uid);

      txn.update(userRef, {'pendingRequests': pending});
      txn.update(requesterRef, {'sentRequests': sent});
    });
  }

  /// 🔹 Controlla stato relazione
  static Future<String> getRelationshipStatus(String otherId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'non_loggato';

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};

    if ((data['friends'] ?? []).contains(otherId)) return 'amici';
    if ((data['pendingRequests'] ?? []).contains(otherId)) return 'in_attesa_tua';
    if ((data['sentRequests'] ?? []).contains(otherId)) return 'richiesta_inviata';
    return 'nessuna';
  }
}
