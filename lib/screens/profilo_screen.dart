// lib/screens/profilo_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/bottom_navbar.dart';

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen>
    with SingleTickerProviderStateMixin {
  String _username = 'Utente';
  File? _avatarFile;
  int _borghi = 0;
  int _selfie = 0;
  int _eventi = 0;
  int _avatarVersion = 1;

  final picker.ImagePicker _picker = picker.ImagePicker();
  String? _toastMsg;
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastOpacity;
  Timer? _toastTimer;

  static const _currentIndex = 4;

  @override
  void initState() {
    super.initState();
    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _toastOpacity = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut);
    _loadUserData();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastCtrl.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toastMsg = msg);
    _toastCtrl.forward();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      _toastCtrl.reverse().whenComplete(() {
        if (mounted) setState(() => _toastMsg = null);
      });
    });
  }

  Future<Directory> _ensureAvatarDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/profile');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _avatarDestFile() async {
    final dir = await _ensureAvatarDir();
    return File('${dir.path}/avatar.jpg');
  }

  Future<void> _saveAvatarFromXFile(picker.XFile x) async {
    try {
      final dest = await _avatarDestFile();
      await File(x.path).copy(dest.path);

      // Evict vecchia immagine dal cache per forzare l’aggiornamento
      try {
        final provider = FileImage(dest);
        await provider.evict();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path', dest.path);
      final ver = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('avatar_version', ver);

      setState(() {
        _avatarFile = dest;
        _avatarVersion = ver;
      });

      _showToast('✅ Avatar aggiornato');
    } catch (_) {
      _showToast('⚠️ Impossibile salvare l’immagine');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Utente';
      _borghi = prefs.getInt('borghi') ?? 0;
      _selfie = prefs.getInt('selfie') ?? 0;
      _eventi = prefs.getInt('eventi') ?? 0;
      _avatarVersion = prefs.getInt('avatar_version') ?? 1;

      final path = prefs.getString('avatar_path');
      if (path != null && File(path).existsSync()) {
        _avatarFile = File(path);
      }
    });
  }

  Future<void> _openAvatarMenu() async {
    final source = await showModalBottomSheet<picker.ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Carica da galleria'),
              onTap: () => Navigator.pop(context, picker.ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(context, picker.ImageSource.camera),
            ),
            if (_avatarFile != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB00020),
                ),
                title: const Text('Rimuovi'),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );

    if (source == null) {
      if (_avatarFile != null) {
        await _removeAvatar();
      }
      return;
    }

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) {
      await _saveAvatarFromXFile(picked);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final dest = await _avatarDestFile();
      if (dest.existsSync()) dest.deleteSync();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('avatar_path');
      await prefs.remove('avatar_version');
      setState(() {
        _avatarFile = null;
        _avatarVersion = 1;
      });
      _showToast('🗑️ Avatar rimosso');
    } catch (_) {
      _showToast('⚠️ Errore durante la rimozione');
    }
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

  // 🔐 Logout completo
  Future<void> _logoutFromProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma logout'),
        content: const Text('Vuoi davvero uscire dal tuo account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFB00020)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout effettuato con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante il logout')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF91be7e);

    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text('Profilo', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: green,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔹 Avatar
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      key: ValueKey(_avatarVersion), // ✅ forza rebuild
                      radius: 55,
                      backgroundColor: green,
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? const Icon(
                              Icons.person,
                              size: 70,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _openAvatarMenu,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3a602a),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                _username,
                style: const TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Borgo Lover',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7D7D9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _stat(label: 'Borghi', value: _borghi),
                    _divider(),
                    _stat(label: 'Selfie', value: _selfie),
                    _divider(),
                    _stat(label: 'Eventi', value: _eventi),
                  ],
                ),
              ),

              const SizedBox(height: 26),
              _linkRow(
                icon: Icons.notifications_none,
                label: 'Notifiche',
                onTap: () => Navigator.pushNamed(context, '/notifiche'),
              ),
              _linkRow(
                icon: Icons.settings_outlined,
                label: 'Impostazioni',
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              _linkRow(
                icon: Icons.explore_outlined,
                label: 'Esplora',
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/explore'),
              ),
              const SizedBox(height: 8),

              // 🔴 Logout
              ElevatedButton.icon(
                onPressed: _logoutFromProfile,
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 🔔 Toast
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _toastMsg == null
          ? null
          : FadeTransition(
              opacity: _toastOpacity,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _toastMsg!,
                  style: const TextStyle(fontFamily: 'Cinzel', fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }

  Widget _stat({required String label, required int value}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cormorant',
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.black12,
  );

  Widget _linkRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF3a602a)),
        title: Text(
          label,
          style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black54),
        onTap: onTap,
      ),
    );
  }
}
