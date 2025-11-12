// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import 'package:occhio_al_borgo/services/user_sync_service.dart';
import 'package:occhio_al_borgo/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---- USER / UI STATE ----
  String? _username;
  File? _avatarFile;
  bool _uploadingAvatar = false;

  String? _lastBorgoName;
  String? _lastBorgoDate;
  File? _lastBorgoPhoto;

  List<Map<String, dynamic>> _upcomingEvents = [];
  List<Map<String, String>> _unlockedBadges = [];

  final ImagePicker _picker = ImagePicker();
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _syncUserData();

    // sync automatico ogni 10'
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Sincronizzazione automatica in corso...'),
          duration: Duration(seconds: 2),
        ),
      );
      await _syncUserData();
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  // ---- SYNC / LOAD ----
  Future<void> _syncUserData() async {
    final data = await UserSyncService.syncUserData();
    if (!mounted || data == null) return;
    setState(() {
      _username = data['username'] ?? _username;
    });
  }

  Future<void> _loadAllData() async {
    await _loadUserData();
    await _loadLastBorgo();
    await _loadBadges();
    await _loadEvents();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Utente';
      final avatarPath = prefs.getString('profile_avatar');
      if (avatarPath != null && File(avatarPath).existsSync()) {
        _avatarFile = File(avatarPath);
      }
    });
  }

  Future<void> _loadLastBorgo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastBorgoName =
          prefs.getString('last_borgo_name') ?? 'Finalborgo (SV)'; // demo
      _lastBorgoDate =
          prefs.getString('last_borgo_date') ?? '2025-09-15T00:00:00'; // demo
      final photoPath = prefs.getString('last_borgo_photo');
      if (photoPath != null && File(photoPath).existsSync()) {
        _lastBorgoPhoto = File(photoPath);
      }
    });
  }

  /// Badge: accetta sia List<String> (ids) che demo locale
  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('unlocked_badges');

    try {
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _unlockedBadges = saved
              .map(
                (id) => {'id': id, 'title': _titleFromId(id), 'icon': 'star'},
              )
              .toList();
        });
      } else {
        // demo
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
    } catch (e) {
      debugPrint('❌ Errore caricamento badge: $e');
    }
  }

  String _titleFromId(String id) {
    final map = {
      'fotografa-locale': 'Fotografa Locale',
      'borgo-lover': 'Borgo Lover',
      'viaggiatrice-liguria': 'Viaggiatrice Liguria',
      'curiosona': 'Curiosona',
    };
    return map[id] ?? id.replaceAll('-', ' ');
  }

  Future<void> _loadEvents() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/eventi_liguria.json',
      );
      final data = json.decode(raw) as List;
      final today = DateTime.now();

      final events = data
          .map<Map<String, dynamic>>(
            (ev) => {
              'title': ev['data-page-selector'] ?? 'Evento',
              'date': ev['event_dates-0'] ?? ev['data'] ?? '',
              'img': ev['image-0-src'] ?? ev['image-src'] ?? '',
              'url':
                  ev['data-page-selector-href'] ??
                  ev['web-scraper-start-url'] ??
                  '',
            },
          )
          .where((e) {
            final d = _parseDate(e['date']);
            return d != null && !d.isBefore(today);
          })
          .toList();

      if (events.isEmpty) {
        _setDemoEvents();
      } else {
        setState(() => _upcomingEvents = events.take(3).toList());
      }
    } catch (_) {
      _setDemoEvents();
    }
  }

  void _setDemoEvents() {
    setState(() {
      _upcomingEvents = [
        {
          'title': 'Festa dell’Olio a Finalborgo',
          'date': '15 Ottobre 2025',
          'img': 'assets/images/demo1.jpg',
          'url': '',
        },
        {
          'title': 'Notte Medievale di Finalborgo',
          'date': '2 Novembre 2025',
          'img': 'assets/images/demo2.jpg',
          'url': '',
        },
        {
          'title': 'Mercatino dei Sapori Liguri',
          'date': '10 Dicembre 2025',
          'img': 'assets/images/demo3.jpg',
          'url': '',
        },
      ];
    });
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final cleaned = dateStr.split('-').first.trim();
    final match = RegExp(
      r'(\d{1,2})(?:[\/\-\s]+)([A-Za-z]+|\d{1,2})(?:[\/\-\s]+)?(\d{2,4})?',
    ).firstMatch(cleaned);
    if (match == null) return null;

    const mesi = {
      'gennaio': 1,
      'febbraio': 2,
      'marzo': 3,
      'aprile': 4,
      'maggio': 5,
      'giugno': 6,
      'luglio': 7,
      'agosto': 8,
      'settembre': 9,
      'ottobre': 10,
      'novembre': 11,
      'dicembre': 12,
    };

    final giorno = int.tryParse(match.group(1) ?? '') ?? 1;
    final meseStr = (match.group(2) ?? '').toLowerCase();
    final mese = mesi[meseStr] ?? int.tryParse(meseStr) ?? 1;
    var anno = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    if (anno < 100) anno += 2000;
    return DateTime(anno, mese, giorno);
  }

  // ---- ACTIONS ----
  Future<void> _changeAvatar() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final File imageFile = File(img.path);
    final uid = user.uid;

    try {
      setState(() => _uploadingAvatar = true);

      // Upload su Storage
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(imageFile);
      final newUrl = await ref.getDownloadURL();

      // Aggiorna Firestore + profilo Firebase
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': newUrl,
      });
      await user.updatePhotoURL(newUrl);

      // Persisti localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photoUrl', newUrl);
      await prefs.setString('profile_avatar', img.path);

      setState(() => _avatarFile = imageFile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Foto profilo aggiornata!')),
      );
    } catch (e) {
      debugPrint('Errore caricamento avatar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Errore durante il caricamento')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _openEvent(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
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
        Navigator.pushReplacementNamed(context, '/profilo');
        break;
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!; // ✅ non-null
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color topBarColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          loc.appTitle,
          style: TextStyle(
            color: AppColors.foreground(context),
            fontFamily: 'Cinzel',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.foreground(context)),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/sos'),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: Text(
          loc.helpRequest(),
          style: const TextStyle(
            fontFamily: 'Cinzel',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ---- AVATAR ----
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary(context),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? Icon(
                                  Icons.person,
                                  color: AppColors.foreground(context),
                                  size: 50,
                                )
                              : null,
                        ),
                        if (_uploadingAvatar)
                          const SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loc.homeWelcome(_username ?? 'Utente'),
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 22,
                      color: AppColors.foreground(context),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ---- ULTIMO BORGO ----
                  Text(
                    loc.lastBorgo,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _lastBorgoPhoto != null
                        ? Image.file(
                            _lastBorgoPhoto!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            'assets/images/demo1.jpg',
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_lastBorgoDate != null
                            ? 'Visitato il ${_lastBorgoDate!.split("T").first}'
                            : 'Visitato il 2025-09-15')
                        .toString(),
                    style: TextStyle(
                      fontFamily: 'Cormorant',
                      fontSize: 14,
                      color: AppColors.subtext(context),
                    ),
                  ),
                  Text(
                    _lastBorgoName ?? 'Finalborgo (SV)',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/scatta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent(context),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      loc.takePhoto,
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ---- BADGE ----
                  Text(
                    loc.badgesTitle,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
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
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primary(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.star,
                              color: AppColors.foreground(context),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 100,
                            child: Text(
                              b['title'] ?? '',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cormorant',
                                fontSize: 13,
                                color: AppColors.foreground(context),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 30),

                  // ---- EVENTI ----
                  Text(
                    loc.eventsTitle,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: _upcomingEvents.map((e) {
                      return Card(
                        color: AppColors.card(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            if ((e['img'] ?? '').toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10),
                                ),
                                child:
                                    (e['img'] as String).startsWith('assets/')
                                    ? Image.asset(
                                        e['img'],
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        e['img'],
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      e['title'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cinzel',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.foreground(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e['date'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Cormorant',
                                        fontSize: 13,
                                        color: AppColors.subtext(context),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _openEvent(e['url'] ?? ''),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent(
                                          context,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'SCOPRI DI PIÙ',
                                        style: TextStyle(
                                          fontFamily: 'Cinzel',
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
