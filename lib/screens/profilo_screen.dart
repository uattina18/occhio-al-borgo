import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import 'package:occhio_al_borgo/services/user_sync_service.dart';
import 'package:occhio_al_borgo/l10n/app_localizations.dart'; // 🌍 Localizzazioni

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  String _username = 'Utente';
  String _email = '';
  String? _photoUrl;
  File? _avatarFile;
  bool _loading = true;
  bool _syncing = false;

  List<Map<String, String>> _unlockedBadges = [];
  Map<String, dynamic> _badgeData = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBadgesData();
  }

  Future<void> _loadBadgesData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/badges.json');
      final data = json.decode(jsonString);
      final List<dynamic> list = data['badges'] ?? [];
      setState(() {
        _badgeData = {for (var b in list) b['id']: b};
      });
    } catch (e) {
      debugPrint('Errore caricamento badges.json: $e');
    }

    setState(() {
      _unlockedBadges = [
        {
          'id': 'fotografa-locale',
          'title': 'Fotografa Locale',
          'icon': 'camera',
        },
        {'id': 'borgo-lover', 'title': 'Borgo Lover', 'icon': 'heart'},
        {
          'id': 'viaggiatrice-liguria',
          'title': 'Viaggiatrice Liguria',
          'icon': 'map-pin',
        },
        {'id': 'curiosona', 'title': 'Curiosona', 'icon': 'search'},
      ];
    });
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      _username = data['username'] ?? prefs.getString('username') ?? 'Utente';
      _email = data['email'] ?? prefs.getString('email') ?? 'utente@email.com';
      _photoUrl = data['photoUrl'] ?? prefs.getString('photoUrl');

      final avatarPath = prefs.getString('profile_avatar');
      if (avatarPath != null && File(avatarPath).existsSync()) {
        _avatarFile = File(avatarPath);
      }

      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Errore caricamento profilo: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _updatePhoto() async {
    final loc = AppLocalizations.of(context);
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final File imageFile = File(img.path);
    final uid = user.uid;

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(imageFile);
      final newUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).set({
        'photoUrl': newUrl,
      }, SetOptions(merge: true));

      await user.updatePhotoURL(newUrl);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photoUrl', newUrl);
      await prefs.setString('profile_avatar', img.path);

      setState(() {
        _photoUrl = newUrl;
        _avatarFile = imageFile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.profileUpdated ?? '✅ Foto aggiornata con successo!',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Errore caricamento immagine: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc?.uploadError ?? 'Errore durante l’upload')),
      );
    }
  }

  Future<void> _syncFromCloud() async {
    final loc = AppLocalizations.of(context);
    setState(() => _syncing = true);
    final data = await UserSyncService.syncUserData();
    if (data != null) {
      setState(() {
        _username = data['username'] ?? _username;
        _email = data['email'] ?? _email;
        _photoUrl = data['photoUrl'] ?? _photoUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.profileSync ?? '✅ Dati aggiornati dal cloud'),
        ),
      );
    }
    setState(() => _syncing = false);
  }

  void _onNavTap(int i) {
    switch (i) {
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
        Navigator.pushReplacementNamed(context, '/notifiche');
        break;
    }
  }

  Widget _button(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: AppColors.accent(context)),
        label: Text(label),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent(context),
          side: BorderSide(color: AppColors.accent(context), width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final topBar = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3a602a)
        : const Color(0xFF91be7e);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc?.profileTitle ?? 'Profilo',
          style: const TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: topBar,
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 4,
        onTap: _onNavTap,
        backgroundColor: topBar,
      ),
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _updatePhoto,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: AppColors.primary(context),
                      backgroundImage: _photoUrl != null
                          ? NetworkImage(_photoUrl!)
                          : _avatarFile != null
                          ? FileImage(_avatarFile!) as ImageProvider
                          : null,
                      child: _photoUrl == null && _avatarFile == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _username.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(
                      fontFamily: 'Cormorant',
                      fontSize: 15,
                      color: AppColors.subtext(context),
                    ),
                  ),
                  const SizedBox(height: 25),

                  _button(
                    Icons.edit,
                    loc?.editProfile ?? 'MODIFICA PROFILO',
                    () => Navigator.pushNamed(context, '/modifica_dati'),
                  ),
                  const SizedBox(height: 12),
                  _button(
                    Icons.person_add_alt_1,
                    loc?.addFriend ?? 'AGGIUNGI UN AMICO',
                    () {},
                  ),
                  const SizedBox(height: 12),
                  _button(
                    Icons.photo_album_outlined,
                    loc?.recognizedBorghi ?? 'BORGHІ RICONOSCIUTI',
                    () => Navigator.pushNamed(context, '/borghi_riconosciuti'),
                  ),
                  const SizedBox(height: 12),
                  _button(
                    Icons.people,
                    loc?.goToCommunity ?? 'VAI ALLA COMMUNITY',
                    () => Navigator.pushNamed(context, '/community'),
                  ),
                  const SizedBox(height: 12),
                  _button(
                    Icons.sync,
                    loc?.syncCloud ?? 'AGGIORNA DATI DA CLOUD',
                    _syncFromCloud,
                  ),
                  const SizedBox(height: 36),

                  Text(
                    loc?.earnedBadges ?? 'BADGE OTTENUTI',
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 16,
                    children: _unlockedBadges.map((b) {
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: AppColors.primary(context),
                            child: const Icon(Icons.star, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 90,
                            child: Text(
                              b['title'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Cormorant'),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
