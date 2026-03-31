import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<String> _blockedUsers = [];
  String? _myUsername;
  String? _selectedBorgo;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadMe();
    _loadSelectedBorgo();
  }

  Future<void> _loadSelectedBorgo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBorgo = prefs.getString("last_borgo_name");
    });
  }

  Future<void> _loadMe() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final me = await _firestore.collection('users').doc(uid).get();
    setState(() {
      _myUsername = (me.data() ?? {})['username'] ?? 'Anonimo';
    });
  }

  Future<void> _loadBlockedUsers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    setState(() {
      _blockedUsers = List<String>.from(doc.data()?['blockedUsers'] ?? []);
    });
  }

  /* ===================== POST ===================== */

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

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final username = userDoc.data()?['username'] ?? 'Anonimo';

      final prefs = await SharedPreferences.getInstance();

      await _firestore.collection('posts').add({
        'uid': uid,
        'username': username,
        'title': titleController.text.trim(),
        'imageUrl': imageUrl,
        'likes': 0,
        'likedBy': <String>[],

        'borgo': prefs.getString("last_borgo_name"),
        'lat': prefs.getDouble("last_borgo_lat"),
        'lng': prefs.getDouble("last_borgo_lng"),

        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ Errore: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /* ===================== DEMO ===================== */

  Widget _demoList() {
    final demos = [
      {
        'asset': 'assets/images/demo1.jpg',
        'title': 'Tramonto a Tellaro',
        'username': 'marta',
      },
      {
        'asset': 'assets/images/demo2.jpg',
        'title': 'Vista su Vernazza',
        'username': 'giulia',
      },
      {
        'asset': 'assets/images/demo3.jpg',
        'title': 'Centro storico',
        'username': 'luca',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: demos.map((d) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                d['asset']!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['title']!,
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("di ${d['username']}"),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /* ===================== BUILD ===================== */

  @override
  Widget build(BuildContext context) {
    final stream = (_selectedBorgo != null)
        ? _firestore
              .collection('posts')
              .where('borgo', isEqualTo: _selectedBorgo)
              .orderBy('createdAt', descending: true)
              .snapshots()
        : _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _demoList(); // 🔥 DEMO ATTIVO
          }

          final posts = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_selectedBorgo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "📍 $_selectedBorgo",
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ...posts.map((post) {
                final data = post.data() as Map<String, dynamic>;

                if (_blockedUsers.contains(data['uid'])) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        data['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'],
                              style: const TextStyle(
                                fontFamily: 'Cinzel',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text("di ${data['username']}"),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _addPost,
        backgroundColor: const Color(0xFF91be7e),
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
    );
  }
}
