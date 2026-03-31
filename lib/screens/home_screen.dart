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
import 'package:flutter/foundation.dart';

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
  // ---- USER STATE ----
  String? _username;
  File? _avatarFile;
  bool _uploadingAvatar = false;

  // ---- LAST BORGO ----
  String? _lastBorgoName;
  String? _lastBorgoDate;
  File? _lastBorgoPhoto;

  // ---- EVENTS / BADGES ----
  List<Map<String, dynamic>> _upcomingEvents = [];
  List<Map<String, String>> _unlockedBadges = [];

  final ImagePicker _picker = ImagePicker();
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _syncUserData();

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (!mounted) return;
      await _syncUserData();
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------
  // SYNC / LOAD
  // ---------------------------------------------------------

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

    if (kDebugMode) {
      setState(() {
        _lastBorgoName = "Finalborgo (SV)";
        _lastBorgoDate = DateTime.now().toIso8601String();
        _lastBorgoPhoto = null;
      });
      return;
    }

    setState(() {
      _lastBorgoName = prefs.getString('last_borgo_name');
      _lastBorgoDate = prefs.getString('last_borgo_date');

      final photoPath = prefs.getString('last_borgo_photo');
      if (photoPath != null && File(photoPath).existsSync()) {
        _lastBorgoPhoto = File(photoPath);
      }
    });
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('unlocked_badges');

    if (saved == null || saved.isEmpty) {
      setState(() {
        _unlockedBadges = [
          {'id': 'fotografa-locale', 'title': 'Fotografa Locale'},
          {'id': 'borgo-lover', 'title': 'Borgo Lover'},
        ];
      });
      return;
    }

    setState(() {
      _unlockedBadges = saved
          .map((id) => {'id': id, 'title': id.replaceAll('-', ' ')})
          .toList();
    });
  }

  // ---------------------------------------------------------
  // EVENTS (LOGICA CORRETTA)
  // ---------------------------------------------------------

  Future<void> _loadEvents() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/liguria/events_liguria.json',
      );

      final List<dynamic> data = json.decode(raw);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final events =
          data
              .map<Map<String, dynamic>>((ev) {
                return {
                  'title': ev['title'] ?? 'Evento',
                  'date': ev['start_date'] ?? '', // 🔥 QUESTA RIGA
                  'start': ev['start_date'],
                  'end': ev['end_date'],
                  'img': ev['image'] ?? '',
                  'url': ev['url'] ?? '',
                };
              })
              .where((e) {
                final endRaw = e['end'];
                if (endRaw == null || endRaw.toString().isEmpty) return true;

                final endDate = DateTime.tryParse(endRaw);
                if (endDate == null) return true;

                final eventEnd = DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                );

                return eventEnd.isAtSameMomentAs(today) ||
                    eventEnd.isAfter(today);
              })
              .toList()
            ..sort((a, b) {
              final aStart =
                  DateTime.tryParse(a['start'] ?? '') ?? DateTime(2100);
              final bStart =
                  DateTime.tryParse(b['start'] ?? '') ?? DateTime(2100);
              return aStart.compareTo(bStart);
            });
      debugPrint('EVENTI DOPO FILTRO: ${events.length}');
      for (final e in events.take(3)) {
        debugPrint('→ ${e['title']} | end=${e['end']}');
      }

      if (events.isEmpty) {
        setState(() {
          _upcomingEvents = [];
        });
      } else {
        setState(() {
          _upcomingEvents = events.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Errore caricamento eventi: $e');
    }
  }

  String formatEventDate(String? start, String? end) {
    if (start == null || start.isEmpty) return '';

    final startDate = DateTime.tryParse(start);
    final endDate = (end != null && end.isNotEmpty)
        ? DateTime.tryParse(end)
        : null;

    if (startDate == null) return '';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';

    final now = DateTime.now();

    if (endDate != null) {
      if (startDate.isBefore(now) && endDate.isAfter(now)) {
        return 'In corso fino al ${fmt(endDate)}';
      }
      return 'Dal ${fmt(startDate)} al ${fmt(endDate)}';
    }

    return 'Dal ${fmt(startDate)}';
  }

  // ---------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------

  Future<void> _changeAvatar() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final file = File(img.path);
    setState(() => _uploadingAvatar = true);

    try {
      final ref = FirebaseStorage.instance.ref().child(
        "avatars/${user.uid}.jpg",
      );

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': url},
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar', img.path);

      setState(() => _avatarFile = file);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _onNavTap(int index) {
    switch (index) {
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

  Future<void> _openEvent(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final topBar = AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(loc.appTitle, style: const TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: topBar,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.foreground(context)),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: _onNavTap,
        backgroundColor: topBar,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/sos'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sos),
        label: Text(loc.helpRequest()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // ---- AVATAR ----
                GestureDetector(
                  onTap: _uploadingAvatar ? null : _changeAvatar,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: topBar,
                    backgroundImage: _avatarFile != null
                        ? FileImage(_avatarFile!)
                        : null,
                    child: _avatarFile == null
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: AppColors.foreground(context),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  loc.homeWelcome(_username ?? "Utente"),
                  style: TextStyle(
                    fontFamily: "Cinzel",
                    fontSize: 22,
                    color: AppColors.foreground(context),
                  ),
                ),
                const SizedBox(height: 30),

                // ---- ULTIMO BORGO ----
                Text(
                  loc.lastBorgo,
                  style: TextStyle(
                    fontFamily: "Cinzel",
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
                          "assets/images/demo1.jpg",
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastBorgoName ?? "Scatta un nuovo borgo",
                  style: TextStyle(
                    fontFamily: "Cinzel",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground(context),
                  ),
                ),
                const SizedBox(height: 30),

                // ---- BADGES ----
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
                  spacing: 20,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: _unlockedBadges.map((b) {
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: topBar,
                          child: Icon(
                            Icons.star,
                            size: 32,
                            color: AppColors.foreground(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 100,
                          child: Text(
                            b['title']!,
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
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(10),
                            ),
                            child: e['img'].toString().startsWith("assets/")
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
                                children: [
                                  Text(
                                    e['title'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent(context),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () => _openEvent(e['url'] ?? ''),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent(
                                        context,
                                      ), // VERDONE
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 20,
                                      ),
                                    ),
                                    child: const Text(
                                      'SCOPRI DI PIÙ',
                                      style: TextStyle(fontFamily: 'Cinzel'),
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
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/events');
                  },
                  icon: const Icon(Icons.event),
                  label: const Text(
                    'VEDI TUTTI GLI EVENTI',
                    style: TextStyle(fontFamily: 'Cinzel'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent(context), // VERDONE
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
