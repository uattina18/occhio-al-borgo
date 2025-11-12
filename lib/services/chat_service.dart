import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 🔹 Crea o recupera una chat esistente
  static Future<String> getOrCreateChat(String otherUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Utente non autenticato");

    final chatId = _generateChatId(uid, otherUid);
    final chatRef = _firestore.collection('chats').doc(chatId);

    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'chatId': chatId,
        'participants': [uid, otherUid],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  static String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  /// 💬 Invia un messaggio
  static Future<void> sendMessage(String chatId, String text) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final message = {
      'senderId': uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.collection('messages').add(message);
    await chatRef.update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 📡 Stream messaggi in tempo reale
  static Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
