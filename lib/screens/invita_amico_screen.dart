import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class InvitaAmicoScreen extends StatefulWidget {
  const InvitaAmicoScreen({super.key});

  @override
  State<InvitaAmicoScreen> createState() => _InvitaAmicoScreenState();
}

class _InvitaAmicoScreenState extends State<InvitaAmicoScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  // ricerca
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _meStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _meStream = _firestore.collection('users').doc(uid).snapshots();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- AZIONI FIRESTORE ----------

  Future<void> _sendFriendRequest(String targetUid) async {
    final me = _auth.currentUser;
    if (me == null || me.uid == targetUid) return;

    final meRef = _firestore.collection('users').doc(me.uid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meRef);
      final targetSnap = await tx.get(targetRef);
      if (!targetSnap.exists || !meSnap.exists) return;

      final meData = meSnap.data() as Map<String, dynamic>;
      final targetData = targetSnap.data() as Map<String, dynamic>;

      final meFriends = List<String>.from(meData['friends'] ?? []);
      final meSent = List<String>.from(meData['sentRequests'] ?? []);
      final targetFriends = List<String>.from(targetData['friends'] ?? []);
      final targetPending = List<String>.from(
        targetData['pendingRequests'] ?? [],
      );

      if (meFriends.contains(targetUid) ||
          meSent.contains(targetUid) ||
          targetPending.contains(me.uid)) {
        return;
      }

      meSent.add(targetUid);
      targetPending.add(me.uid);

      tx.set(meRef, {'sentRequests': meSent}, SetOptions(merge: true));
      tx.set(targetRef, {
        'pendingRequests': targetPending,
      }, SetOptions(merge: true));
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta inviata ✅')));
    }
  }

  Future<void> _acceptRequest(String fromUid) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final meRef = _firestore.collection('users').doc(me.uid);
    final fromRef = _firestore.collection('users').doc(fromUid);

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meRef);
      final fromSnap = await tx.get(fromRef);
      if (!meSnap.exists || !fromSnap.exists) return;

      final meData = meSnap.data() as Map<String, dynamic>;
      final fromData = fromSnap.data() as Map<String, dynamic>;

      final meFriends = List<String>.from(meData['friends'] ?? []);
      final mePending = List<String>.from(meData['pendingRequests'] ?? []);
      final fromFriends = List<String>.from(fromData['friends'] ?? []);
      final fromSent = List<String>.from(fromData['sentRequests'] ?? []);

      mePending.remove(fromUid);
      fromSent.remove(me.uid);

      if (!meFriends.contains(fromUid)) meFriends.add(fromUid);
      if (!fromFriends.contains(me.uid)) fromFriends.add(me.uid);

      tx.set(meRef, {
        'friends': meFriends,
        'pendingRequests': mePending,
      }, SetOptions(merge: true));

      tx.set(fromRef, {
        'friends': fromFriends,
        'sentRequests': fromSent,
      }, SetOptions(merge: true));
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta accettata 🎉')));
    }
  }

  Future<void> _declineRequest(String fromUid) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final meRef = _firestore.collection('users').doc(me.uid);
    final fromRef = _firestore.collection('users').doc(fromUid);

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meRef);
      final fromSnap = await tx.get(fromRef);
      if (!meSnap.exists || !fromSnap.exists) return;

      final meData = meSnap.data() as Map<String, dynamic>;
      final fromData = fromSnap.data() as Map<String, dynamic>;

      final mePending = List<String>.from(meData['pendingRequests'] ?? []);
      final fromSent = List<String>.from(fromData['sentRequests'] ?? []);

      mePending.remove(fromUid);
      fromSent.remove(me.uid);

      tx.set(meRef, {'pendingRequests': mePending}, SetOptions(merge: true));
      tx.set(fromRef, {'sentRequests': fromSent}, SetOptions(merge: true));
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta rifiutata')));
    }
  }

  Future<void> _cancelSent(String toUid) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final meRef = _firestore.collection('users').doc(me.uid);
    final toRef = _firestore.collection('users').doc(toUid);

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meRef);
      final toSnap = await tx.get(toRef);
      if (!meSnap.exists || !toSnap.exists) return;

      final meData = meSnap.data() as Map<String, dynamic>;
      final toData = toSnap.data() as Map<String, dynamic>;

      final meSent = List<String>.from(meData['sentRequests'] ?? []);
      final toPending = List<String>.from(toData['pendingRequests'] ?? []);

      meSent.remove(toUid);
      toPending.remove(me.uid);

      tx.set(meRef, {'sentRequests': meSent}, SetOptions(merge: true));
      tx.set(toRef, {'pendingRequests': toPending}, SetOptions(merge: true));
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Richiesta annullata')));
    }
  }

  Future<void> _removeFriend(String friendUid) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final meRef = _firestore.collection('users').doc(me.uid);
    final friendRef = _firestore.collection('users').doc(friendUid);

    await _firestore.runTransaction((tx) async {
      final meSnap = await tx.get(meRef);
      final friendSnap = await tx.get(friendRef);
      if (!meSnap.exists || !friendSnap.exists) return;

      final meData = meSnap.data() as Map<String, dynamic>;
      final frData = friendSnap.data() as Map<String, dynamic>;

      final meFriends = List<String>.from(meData['friends'] ?? []);
      final frFriends = List<String>.from(frData['friends'] ?? []);

      meFriends.remove(friendUid);
      frFriends.remove(me.uid);

      tx.set(meRef, {'friends': meFriends}, SetOptions(merge: true));
      tx.set(friendRef, {'friends': frFriends}, SetOptions(merge: true));
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Amico rimosso')));
    }
  }

  // ---------- RICERCA UTENTI ----------
  Future<void> _performSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);

    try {
      final usersCol = _firestore.collection('users');
      final byUsername = await usersCol
          .where('username', isEqualTo: q)
          .limit(10)
          .get();
      final byEmail = await usersCol
          .where('email', isEqualTo: q)
          .limit(10)
          .get();

      final merged = <String, Map<String, dynamic>>{};
      for (final d in byUsername.docs) {
        merged[d.id] = {'uid': d.id, ...d.data()};
      }
      for (final d in byEmail.docs) {
        merged[d.id] = {'uid': d.id, ...d.data()};
      }

      setState(() {
        _searchResults = merged.values.toList();
      });
    } catch (e) {
      debugPrint('Errore ricerca: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Errore nella ricerca')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final topBar = isDark ? const Color(0xFF3a602a) : const Color(0xFF91be7e);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Amici',
          style: TextStyle(
            color: AppColors.foreground(context),
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: topBar,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Amici'),
            Tab(text: 'Richieste'),
            Tab(text: 'Cerca'),
          ],
        ),
      ),
      backgroundColor: AppColors.background(context),
      body: _meStream == null
          ? const Center(child: Text('Devi essere loggato'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _meStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: Text('Profilo non trovato'));
                }

                final meData = snap.data!.data()!;
                final friends = List<String>.from(meData['friends'] ?? []);
                final pending = List<String>.from(
                  meData['pendingRequests'] ?? [],
                );
                final sent = List<String>.from(meData['sentRequests'] ?? []);

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _FriendsList(
                      uids: friends,
                      emptyText:
                          'Non hai ancora amici. Cerca qualcuno e invia una richiesta!',
                      trailingBuilder: (context, user) => IconButton(
                        icon: const Icon(Icons.person_remove),
                        tooltip: 'Rimuovi amico',
                        onPressed: () => _removeFriend(user['uid']),
                      ),
                    ),
                    _FriendsList(
                      uids: pending,
                      emptyText: 'Nessuna richiesta in arrivo.',
                      trailingBuilder: (context, user) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFFB00020),
                            ),
                            tooltip: 'Rifiuta',
                            onPressed: () => _declineRequest(user['uid']),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check,
                              color: Color(0xFF2E7D32),
                            ),
                            tooltip: 'Accetta',
                            onPressed: () => _acceptRequest(user['uid']),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _performSearch(),
                            decoration: InputDecoration(
                              labelText: 'Cerca per username o email',
                              filled: true,
                              fillColor: AppColors.card(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _performSearch,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_searching) const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _searchResults.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Nessun risultato',
                                      style: TextStyle(fontFamily: 'Cormorant'),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, i) {
                                      final u = _searchResults[i];
                                      final myUid = _auth.currentUser!.uid;
                                      if (u['uid'] == myUid) {
                                        return const SizedBox.shrink();
                                      }

                                      final friends = List<String>.from(
                                        snap.data!.data()!['friends'] ?? [],
                                      );
                                      final sent = List<String>.from(
                                        snap.data!.data()!['sentRequests'] ??
                                            [],
                                      );
                                      final pending = List<String>.from(
                                        snap.data!.data()!['pendingRequests'] ??
                                            [],
                                      );

                                      final alreadyFriend = friends.contains(
                                        u['uid'],
                                      );
                                      final alreadySent = sent.contains(
                                        u['uid'],
                                      );
                                      final alreadyPending = pending.contains(
                                        u['uid'],
                                      );

                                      return _UserTile(
                                        user: u,
                                        trailing: alreadyFriend
                                            ? const Text('Già amici')
                                            : alreadySent
                                            ? TextButton(
                                                onPressed: () =>
                                                    _cancelSent(u['uid']),
                                                child: const Text(
                                                  'Annulla invio',
                                                ),
                                              )
                                            : alreadyPending
                                            ? const Text('Ti ha già invitato')
                                            : ElevatedButton(
                                                onPressed: () =>
                                                    _sendFriendRequest(
                                                      u['uid'],
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.accent(context),
                                                ),
                                                child: const Text('Aggiungi'),
                                              ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ------------- WIDGETS DI SUPPORTO -------------

class _FriendsList extends StatelessWidget {
  final List<String> uids;
  final String emptyText;
  final Widget Function(BuildContext, Map<String, dynamic>) trailingBuilder;

  const _FriendsList({
    required this.uids,
    required this.emptyText,
    required this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (uids.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16),
        ),
      );
    }

    final firestore = FirebaseFirestore.instance;

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: uids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final uid = uids[i];
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: firestore.collection('users').doc(uid).get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const ListTile(title: Text('...'));
            }
            if (!snap.data!.exists) {
              return const ListTile(title: Text('Utente non trovato'));
            }
            final data = snap.data!.data()!;
            final user = {
              'uid': uid,
              'username': data['username'] ?? 'Utente',
              'email': data['email'] ?? '',
              'photoUrl': data['photoUrl'],
            };
            return _UserTile(
              user: user,
              trailing: trailingBuilder(context, user),
            );
          },
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final Widget trailing;

  const _UserTile({required this.user, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final photo = user['photoUrl'] as String?;
    return Card(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary(context),
          backgroundImage: (photo != null && photo.isNotEmpty)
              ? NetworkImage(photo)
              : null,
          child: (photo == null || photo.isEmpty)
              ? Icon(Icons.person, color: AppColors.foreground(context))
              : null,
        ),
        title: Text(
          user['username'] ?? 'Utente',
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          user['email'] ?? '',
          style: TextStyle(
            fontFamily: 'Cormorant',
            color: AppColors.subtext(context),
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
