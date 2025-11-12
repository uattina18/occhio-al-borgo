import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/l10n/app_localizations.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class NotificheScreen extends StatefulWidget {
  const NotificheScreen({super.key});

  @override
  State<NotificheScreen> createState() => _NotificheScreenState();
}

class _NotificheScreenState extends State<NotificheScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _notifications = [
    {
      'title_it': 'Benvenuta in Occhio al Borgo!',
      'title_en': 'Welcome to Watch the Village!',
      'body_it': 'Inizia a esplorare i borghi e guadagna i tuoi primi badge!',
      'body_en': 'Start exploring villages and earn your first badges!',
      'time': '1h',
      'read': false,
    },
    {
      'title_it': 'Nuovo evento disponibile',
      'title_en': 'New event available',
      'body_it': 'Scopri gli eventi in arrivo nei borghi vicini.',
      'body_en': 'Discover upcoming events in nearby villages.',
      'time': '2h',
      'read': true,
    },
    {
      'title_it': 'Hai sbloccato un nuovo badge!',
      'title_en': 'You unlocked a new badge!',
      'body_it': 'Congratulazioni, hai visitato 5 borghi!',
      'body_en': 'Congrats, you visited 5 villages!',
      'time': 'Yesterday',
      'read': true,
    },
  ];

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/explore');
        break;
      case 2:
        Navigator.pushNamed(context, '/scatta');
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profilo');
        break;
    }
  }

  Future<void> _acceptFriend(String requesterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userRef = _firestore.collection('users').doc(uid);
    final requesterRef = _firestore.collection('users').doc(requesterId);

    await _firestore.runTransaction((txn) async {
      final userDoc = await txn.get(userRef);
      final requesterDoc = await txn.get(requesterRef);

      final userData = userDoc.data() ?? {};
      final requesterData = requesterDoc.data() ?? {};

      final List friends = List.from(userData['friends'] ?? []);
      final List pending = List.from(userData['pendingRequests'] ?? []);

      friends.add(requesterId);
      pending.remove(requesterId);
      txn.update(userRef, {'friends': friends, 'pendingRequests': pending});

      final List requesterFriends = List.from(requesterData['friends'] ?? []);
      requesterFriends.add(uid);
      txn.update(requesterRef, {'friends': requesterFriends});
    });
  }

  Future<void> _rejectFriend(String requesterId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userRef = _firestore.collection('users').doc(uid);
    await userRef.update({
      'pendingRequests': FieldValue.arrayRemove([requesterId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topBarColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          loc.notificationsTitle,
          style: const TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 3,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: uid != null
              ? _firestore.collection('users').doc(uid).snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Firestore error.',
                  style: TextStyle(color: AppColors.subtext(context)),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final pendingRequests = List<String>.from(
              userData['pendingRequests'] ?? [],
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (pendingRequests.isNotEmpty) ...[
                  Text(
                    loc.friendRequests,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...pendingRequests.map((reqId) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(reqId).get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const SizedBox.shrink();
                        }
                        final ud =
                            userSnap.data!.data() as Map<String, dynamic>? ??
                            {};
                        final username = ud['username'] ?? 'User';
                        final photoUrl = ud['photoUrl'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black45 : Colors.black12,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                backgroundColor: const Color(0xFF91be7e),
                                child: photoUrl == null
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loc.userSentRequest(username),
                                  style: TextStyle(
                                    fontFamily: 'Cormorant',
                                    fontSize: 15,
                                    color: AppColors.foreground(context),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    tooltip: loc.accept,
                                    onPressed: () => _acceptFriend(reqId),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: loc.reject,
                                    onPressed: () => _rejectFriend(reqId),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                  const Divider(height: 30, thickness: 1),
                ],

                Text(
                  loc.notificationsTitle,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.foreground(context),
                  ),
                ),
                const SizedBox(height: 10),
                ..._notifications.map((n) {
                  final isRead = n['read'] as bool;
                  final title =
                      Localizations.localeOf(context).languageCode == 'en'
                      ? n['title_en'] as String
                      : n['title_it'] as String;
                  final body =
                      Localizations.localeOf(context).languageCode == 'en'
                      ? n['body_en'] as String
                      : n['body_it'] as String;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRead
                            ? (isDark ? Colors.white10 : Colors.black12)
                            : const Color(0xFF91be7e),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black45 : Colors.black12,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: isRead
                              ? AppColors.subtext(context)
                              : const Color(0xFF3a602a),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.foreground(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontFamily: 'Cormorant',
                                  fontSize: 13,
                                  color: AppColors.subtext(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          n['time'],
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 11,
                            color: AppColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
