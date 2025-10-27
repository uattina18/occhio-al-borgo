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

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  String _username = 'Utente';
  String _email = '';
  String? _photoUrl;
  File? _avatarFile;
  bool _loading = true;

  int _borghiCount = 0;
  int _selfieCount = 0;
  int _eventiCount = 0;

  List<String> _unlockedBadges = [];
  Map<String, dynamic> _badgeData = {};
  String? _newBadgeTitle;

  late AnimationController _popupController;
  late Animation<double> _scaleAnim;

  String _getUserTitle() {
    if (_unlockedBadges.contains('collezionista')) return 'Collezionista 🏆';
    if (_unlockedBadges.contains('instancabile')) return 'Instancabile 🌍';
    if (_unlockedBadges.contains('esploratrice')) return 'Esploratore 🗺️';
    if (_unlockedBadges.contains('fotografa-locale'))
      return 'Fotografa locale 📸';
    if (_unlockedBadges.contains('borgo-lover')) return 'Borgo Lover ❤️';
    return 'Esploratore in erba 🌱';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _popupController,
      curve: Curves.easeOutBack,
    );
    _loadProfile();
    _loadBadgesData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _popupController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadProfile();
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
      debugPrint('❌ Errore caricamento badges.json: $e');
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _username = data['username'] ?? 'Utente';
          _email = data['email'] ?? '';
          _photoUrl = data['photoUrl'];
        });
        await prefs.setString('username', _username);
        await prefs.setString('email', _email);
        if (_photoUrl != null) await prefs.setString('photoUrl', _photoUrl!);
      } else {
        setState(() {
          _username = prefs.getString('username') ?? 'Utente';
          _email = prefs.getString('email') ?? '';
          _photoUrl = prefs.getString('photoUrl');
        });
      }

      final badgeList = prefs.getStringList('unlocked_badges') ?? [];
      final lastBadgeShown = prefs.getString('last_badge_shown');

      if (badgeList.isNotEmpty && badgeList.last != lastBadgeShown) {
        final lastBadge = badgeList.last;
        final badgeTitle = _badgeData[lastBadge]?['title'] ?? lastBadge;
        _showNewBadgePopup(badgeTitle);
        await prefs.setString('last_badge_shown', lastBadge);
      }

      setState(() => _unlockedBadges = badgeList);
    } catch (e) {
      debugPrint('Errore caricamento profilo: $e');
    }

    setState(() => _loading = false);
  }

  void _showNewBadgePopup(String title) async {
    setState(() => _newBadgeTitle = title);
    await _popupController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _newBadgeTitle = null);
  }

  Future<void> _updatePhoto(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(imageFile);
      final newUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).update({
        'photoUrl': newUrl,
      });
      await _auth.currentUser!.updatePhotoURL(newUrl);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photoUrl', newUrl);

      setState(() {
        _photoUrl = newUrl;
        _avatarFile = null;
      });
    } catch (e) {
      debugPrint('❌ Errore aggiornamento foto profilo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento dell’immagine')),
      );
    }
  }

  Future<void> _removePhoto() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({'photoUrl': null});
      await _auth.currentUser!.updatePhotoURL(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('photoUrl');

      setState(() {
        _photoUrl = null;
        _avatarFile = null;
      });
    } catch (e) {
      debugPrint('❌ Errore rimozione foto: $e');
    }
  }

  void _openAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Scegli dalla galleria'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) await _updatePhoto(File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta una foto'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (picked != null) await _updatePhoto(File(picked.path));
              },
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Rimuovi immagine',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

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
        Navigator.pushReplacementNamed(context, '/notifiche');
        break;
      case 4:
        break;
    }
  }

  IconData _iconForBadge(String iconName) {
    switch (iconName) {
      case 'camera':
        return Icons.camera_alt;
      case 'heart':
        return Icons.favorite;
      case 'map':
      case 'map-pin':
        return Icons.map;
      case 'award':
        return Icons.emoji_events;
      case 'globe':
        return Icons.public;
      case 'calendar':
        return Icons.event;
      case 'search':
        return Icons.search;
      case 'tickets':
        return Icons.local_activity;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color topBarColor = isDark
        ? const Color(0xFF3a602a)
        : const Color(0xFF91be7e);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        backgroundColor: topBarColor,
        centerTitle: true,
      ),
      backgroundColor: AppColors.background(context),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 4,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _openAvatarOptions,
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: AppColors.primary(context),
                          backgroundImage: _photoUrl != null
                              ? NetworkImage(_photoUrl!)
                              : _avatarFile != null
                              ? FileImage(_avatarFile!) as ImageProvider
                              : null,
                          child: _photoUrl == null && _avatarFile == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.foreground(context),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _username,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email,
                        style: TextStyle(
                          fontFamily: 'Cormorant',
                          fontSize: 16,
                          color: AppColors.subtext(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getUserTitle(),
                        style: TextStyle(
                          fontFamily: 'Cormorant',
                          fontSize: 16,
                          color: AppColors.foreground(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔢 Contatori
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat('Borghi', _borghiCount),
                            _buildStat('Selfie', _selfieCount),
                            _buildStat('Eventi', _eventiCount),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 🏅 Badge ottenuti
                      const Text(
                        'Badge ottenuti',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_unlockedBadges.isNotEmpty)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 16,
                          children: _unlockedBadges.map((id) {
                            final badge = _badgeData[id];
                            final iconName = badge?['icon'] ?? 'star';
                            final title =
                                badge?['title'] ?? id.replaceAll('-', ' ');
                            return Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary(context),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForBadge(iconName),
                                    color: AppColors.foreground(context),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Cormorant',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        )
                      else
                        Text(
                          'Nessun badge ancora sbloccato.\nContinua ad esplorare!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 15,
                            color: AppColors.subtext(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 30),
                      _buildLinkTile(
                        icon: Icons.bookmark,
                        label: 'Borghi salvati',
                        onTap: () =>
                            Navigator.pushNamed(context, '/borghi_salvati'),
                      ),
                      _buildLinkTile(
                        icon: Icons.location_on,
                        label: 'Borghi visitati',
                        onTap: () =>
                            Navigator.pushNamed(context, '/borghi_visitati'),
                      ),
                      _buildLinkTile(
                        icon: Icons.people,
                        label: 'Community',
                        onTap: () => Navigator.pushNamed(context, '/community'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🌟 Popup badge sbloccato
          if (_newBadgeTitle != null)
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.foreground(context).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF91be7e),
                          size: 50,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Hai sbloccato un nuovo badge!',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _newBadgeTitle!,
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 16,
                            color: AppColors.foreground(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cormorant',
            fontSize: 14,
            color: AppColors.subtext(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      color: AppColors.card(context),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary(context)),
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cormorant',
            fontSize: 16,
            color: AppColors.foreground(context),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.subtext(context)),
        onTap: onTap,
      ),
    );
  }
}
