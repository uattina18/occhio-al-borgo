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
  List<String> _blockedUsers = [];
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadMe();
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

  // —————————————————— CREAZIONE POST ——————————————————
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
      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? 'Anonimo';

      await _firestore.collection('posts').add({
        'uid': uid,
        'username': username,
        'title': titleController.text.trim(),
        'imageUrl': imageUrl,
        'likes': 0,
        'likedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Errore upload: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // —————————————————— LIKE / UNLIKE ——————————————————
  Future<void> _toggleLike(DocumentSnapshot post) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = post.data() as Map<String, dynamic>;
    final List likedBy = List.from(data['likedBy'] ?? []);
    final bool already = likedBy.contains(uid);

    final postRef = _firestore.collection('posts').doc(post.id);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(postRef);
      final d = snap.data() as Map<String, dynamic>? ?? {};
      final int likes = (d['likes'] ?? 0) as int;
      final List lb = List.from(d['likedBy'] ?? []);
      if (already) {
        lb.remove(uid);
        txn.update(postRef, {
          'likes': (likes - 1).clamp(0, 1 << 31),
          'likedBy': lb,
        });
      } else {
        lb.add(uid);
        txn.update(postRef, {'likes': likes + 1, 'likedBy': lb});
      }
    });
  }

  // —————————————————— MODALE: LISTA LIKE ——————————————————
  Future<void> _showLikesModal(List likedBy) async {
    if (likedBy.isEmpty) return;

    // Fetch usernames (batch)
    final futures = likedBy.map(
      (uid) => _firestore.collection('users').doc(uid).get(),
    );
    final docs = await Future.wait(futures);
    final users = docs.map((d) {
      final data = d.data() ?? {};
      return data['username'] ?? 'Utente';
    }).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Piace a',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(
                      users[i],
                      style: const TextStyle(fontFamily: 'Cormorant'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // —————————————————— COMMENTI: BOTTOM SHEET ——————————————————
  void _openComments(String postId) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Commenti',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('posts')
                          .doc(postId)
                          .collection('comments')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items = snap.data?.docs ?? [];
                        if (items.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Ancora nessun commento.\nScrivi il primo!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cormorant',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final d = items[i].data() as Map<String, dynamic>;
                            final who = d['username'] ?? 'Anonimo';
                            final text = d['text'] ?? '';
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.account_circle),
                              title: Text(
                                who,
                                style: const TextStyle(
                                  fontFamily: 'Cinzel',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                text,
                                style: const TextStyle(
                                  fontFamily: 'Cormorant',
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Aggiungi un commento…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () async {
                            final uid = _auth.currentUser?.uid;
                            if (uid == null) return;
                            final txt = controller.text.trim();
                            if (txt.isEmpty) return;

                            await _firestore
                                .collection('posts')
                                .doc(postId)
                                .collection('comments')
                                .add({
                                  'userId': uid,
                                  'username': _myUsername ?? 'Anonimo',
                                  'text': txt,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                            controller.clear();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // —————————————————— AMICI / BLOCCO ——————————————————
  Future<void> _sendFriendRequest(String targetUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == targetUserId) return;
    try {
      await _firestore.collection('users').doc(targetUserId).set({
        'pendingRequests': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Richiesta d’amicizia inviata!')),
        );
      }
    } catch (e) {
      debugPrint('❌ Errore invio richiesta: $e');
    }
  }

  Future<void> _blockUser(String targetUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      });
      setState(() => _blockedUsers.add(targetUserId));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utente bloccato.')));
    } catch (e) {
      debugPrint('❌ Errore blocco utente: $e');
    }
  }

  Future<void> _unblockUser(String targetUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUserId]),
      });
      setState(() => _blockedUsers.remove(targetUserId));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utente sbloccato.')));
    } catch (e) {
      debugPrint('❌ Errore sblocco utente: $e');
    }
  }

  // —————————————————— DEMO FALLBACK ——————————————————
  Widget _demoList() {
    final demos = [
      {
        'asset': 'assets/images/demo1.jpg',
        'title': 'Tramonto su Borgo Antico',
        'username': 'marta',
      },
      {
        'asset': 'assets/images/demo2.jpg',
        'title': 'Scorcio sul mare',
        'username': 'giulia',
      },
      {
        'asset': 'assets/images/demo3.jpg',
        'title': 'Piazzetta fiorita',
        'username': 'luca',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: demos.length,
      itemBuilder: (_, i) {
        final d = demos[i];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: Image.asset(
                  d['asset']!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'di ${d['username']}',
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
                        const Text(
                          '0 like',
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.favorite_border),
                              onPressed: () {},
                              tooltip: 'Mi piace (demo)',
                            ),
                            IconButton(
                              icon: const Icon(Icons.mode_comment_outlined),
                              onPressed: () {},
                              tooltip: 'Commenta (demo)',
                            ),
                            PopupMenuButton<String>(
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'amico',
                                  child: Text('Aggiungi amico'),
                                ),
                              ],
                            ),
                          ],
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
  }

  // —————————————————— BUILD ——————————————————
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

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
          // Se non ci sono post reali, mostra solo la DEMO
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _demoList();
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final post = posts[i];
              final data = post.data() as Map<String, dynamic>;
              final postOwnerId = data['uid'];
              final isMine = postOwnerId == uid;
              final likes = (data['likes'] ?? 0) as int;
              final List likedBy = List.from(data['likedBy'] ?? []);
              final youLike = uid != null && likedBy.contains(uid);

              // Filtra utenti bloccati
              if (_blockedUsers.contains(postOwnerId)) {
                return const SizedBox.shrink();
              }

              // testo “Piace a …”
              Widget likesSummary() {
                if (likes == 0) {
                  return const Text(
                    '0 like',
                    style: TextStyle(fontFamily: 'Cormorant', fontSize: 14),
                  );
                }

                // Mostra fino a 2 nomi, poi “altri”
                final shownUids = likedBy.take(2).toList();
                return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    shownUids.map(
                      (id) => _firestore.collection('users').doc(id).get(),
                    ),
                  ),
                  builder: (_, snap) {
                    String label = '$likes like';
                    if (snap.hasData && snap.data!.isNotEmpty) {
                      final names = snap.data!
                          .map(
                            (d) =>
                                (d.data()
                                    as Map<String, dynamic>?)?['username'] ??
                                'Utente',
                          )
                          .cast<String>()
                          .toList();
                      if (names.length == 1) {
                        label = 'Piace a ${names[0]}';
                      } else if (names.length >= 2) {
                        final others = likes - 2;
                        label = others > 0
                            ? 'Piace a ${names[0]}, ${names[1]} e altri $others'
                            : 'Piace a ${names[0]} e ${names[1]}';
                      }
                    }
                    return InkWell(
                      onTap: () => _showLikesModal(likedBy),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Cormorant',
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    );
                  },
                );
              }

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
                      padding: const EdgeInsets.all(12),
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
                          const SizedBox(height: 4),
                          Text(
                            'di ${data['username'] ?? 'Anonimo'}',
                            style: TextStyle(
                              fontFamily: 'Cormorant',
                              fontSize: 14,
                              color: AppColors.subtext(context),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Riga azioni + like summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              likesSummary(),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      youLike
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: youLike ? Colors.redAccent : null,
                                    ),
                                    onPressed: () => _toggleLike(post),
                                    tooltip: youLike
                                        ? 'Togli Mi piace'
                                        : 'Mi piace',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.mode_comment_outlined,
                                    ),
                                    onPressed: () => _openComments(post.id),
                                    tooltip: 'Commenti',
                                  ),
                                  if (!isMine)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'amico') {
                                          _sendFriendRequest(postOwnerId);
                                        } else if (value == 'blocca') {
                                          _blockUser(postOwnerId);
                                        } else if (value == 'sblocca') {
                                          _unblockUser(postOwnerId);
                                        }
                                      },
                                      itemBuilder: (context) {
                                        final isBlocked = _blockedUsers
                                            .contains(postOwnerId);
                                        return [
                                          const PopupMenuItem(
                                            value: 'amico',
                                            child: Text('Aggiungi amico'),
                                          ),
                                          PopupMenuItem(
                                            value: isBlocked
                                                ? 'sblocca'
                                                : 'blocca',
                                            child: Text(
                                              isBlocked
                                                  ? 'Sblocca utente'
                                                  : 'Blocca utente',
                                            ),
                                          ),
                                        ];
                                      },
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                ],
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
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
    );
  }
}
