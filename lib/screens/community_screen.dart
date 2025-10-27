import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  bool _isUploading = false;

  // 📸 Funzione per aggiungere un nuovo post
  Future<void> _addPost() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Titolo del post'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Scrivi un titolo...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pubblica'),
          ),
        ],
      ),
    );

    if (confirmed != true || titleController.text.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance.ref().child(
        'community/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(file);
      final imageUrl = await ref.getDownloadURL();

      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // 🔹 Recupera dati utente da Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      final username = userData['username'] ?? userData['nome'] ?? 'Anonimo';
      final nomeCompleto =
          '${userData['nome'] ?? ''} ${userData['cognome'] ?? ''}'.trim();

      await _firestore.collection('posts').add({
        'uid': uid,
        'username': username,
        'nomeCompleto': nomeCompleto,
        'title': titleController.text,
        'imageUrl': imageUrl,
        'likes': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Errore upload: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ❤️ Aumenta i like
  Future<void> _likePost(String postId, int currentLikes) async {
    await _firestore.collection('posts').doc(postId).update({
      'likes': currentLikes + 1,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFe8e9ea),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nessun post ancora. Pubblica la tua prima foto!',
                style: TextStyle(fontFamily: 'Cormorant', fontSize: 16),
              ),
            );
          }

          final posts = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final post = posts[i];
              final data = post.data() as Map<String, dynamic>;
              final likes = data['likes'] ?? 0;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['imageUrl'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: Image.network(
                          data['imageUrl'],
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'Senza titolo',
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'di ${data['username'] ?? 'Anonimo'}',
                            style: TextStyle(
                              fontFamily: 'Cormorant',
                              fontSize: 14,
                              color: AppColors.subtext(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$likes like',
                                style: const TextStyle(
                                  fontFamily: 'Cormorant',
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite_border),
                                onPressed: () => _likePost(post.id, likes),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _addPost,
        backgroundColor: const Color(0xFF91be7e),
        child: _isUploading
            ? CircularProgressIndicator(color: AppColors.foreground(context))
            : const Icon(Icons.add),
      ),
    );
  }
}
