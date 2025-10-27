import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;
  File? _avatarFile;
  String? _lastBorgoName;
  String? _lastBorgoDate;
  File? _lastBorgoPhoto;
  List<Map<String, dynamic>> _upcomingEvents = [];
  List<String> _unlockedBadges = [];

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
          prefs.getString('last_borgo_name') ?? 'Nessun borgo riconosciuto';
      _lastBorgoDate = prefs.getString('last_borgo_date');
      final photoPath = prefs.getString('last_borgo_photo');
      if (photoPath != null && File(photoPath).existsSync()) {
        _lastBorgoPhoto = File(photoPath);
      }
    });
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _unlockedBadges = prefs.getStringList('unlocked_badges') ?? [];
    });
  }

  // 🔹 CARICAMENTO EVENTI
  Future<void> _loadEvents() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/eventi_liguria.json',
      );
      final data = json.decode(raw) as List;
      final today = DateTime.now();

      final events = data
          .map<Map<String, dynamic>>((ev) {
            return {
              'title': ev['data-page-selector'] ?? 'Evento',
              'date': ev['event_dates-0'] ?? ev['data'] ?? '',
              'img': ev['image-0-src'] ?? ev['image-src'] ?? '',
              'url':
                  ev['data-page-selector-href'] ??
                  ev['web-scraper-start-url'] ??
                  '',
            };
          })
          .where((e) {
            final d = _parseDate(e['date']);
            return d != null && !d.isBefore(today);
          })
          .toList();

      events.sort((a, b) {
        final da = _parseDate(a['date']);
        final db = _parseDate(b['date']);
        return (da ?? today).compareTo(db ?? today);
      });

      setState(() {
        _upcomingEvents = events.take(3).toList();
      });

      // Debug (puoi rimuovere dopo)
      for (var e in _upcomingEvents) {
        debugPrint('🗓 Evento: ${e['title']} - ${e['date']}');
      }
    } catch (e) {
      debugPrint('❌ Errore caricamento eventi: $e');
    }
  }

  // 🔹 LETTURA DATE FLESSIBILE
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
    final meseStr = match.group(2)!.toLowerCase();
    final mese = mesi[meseStr] ?? int.tryParse(meseStr) ?? 1;
    var anno = int.tryParse(match.group(3) ?? '') ?? DateTime.now().year;
    if (anno < 100) anno += 2000;

    return DateTime(anno, mese, giorno);
  }

  Future<void> _changeAvatar() async {
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_avatar', img.path);
    setState(() => _avatarFile = File(img.path));
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

  Future<void> _openEvent(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color topBarColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Occhio al Borgo',
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
            tooltip: 'Impostazioni',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
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
                  // 👤 Avatar
                  GestureDetector(
                    onTap: _changeAvatar,
                    child: CircleAvatar(
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
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bentornata, ${_username ?? "Utente"}!',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 22,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 📍 Ultimo borgo
                  Text(
                    'Ultimo borgo visitato',
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
                            'assets/images/borgo_placeholder.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastBorgoDate != null
                        ? 'Visitato il ${_lastBorgoDate!.split("T").first}'
                        : 'Data non disponibile',
                    style: TextStyle(
                      fontFamily: 'Cormorant',
                      fontSize: 14,
                      color: AppColors.subtext(context),
                    ),
                  ),
                  Text(
                    _lastBorgoName ?? 'Nome borgo sconosciuto',
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
                    child: const Text(
                      'SCATTA UN NUOVO BORGO',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🏅 Badge
                  Text(
                    'Badge ottenuti',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _unlockedBadges.isNotEmpty
                      ? Wrap(
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
                                  width: 90,
                                  child: Text(
                                    b,
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
                        )
                      : Text(
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

                  // 📅 Eventi
                  Text(
                    'Eventi in arrivo',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/segnala_evento'),
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.accent(context),
                    ),
                    label: Text(
                      'Segnala un evento',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  if (_upcomingEvents.isEmpty)
                    Text(
                      'Nessun evento disponibile al momento.',
                      style: TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: 14,
                        color: AppColors.subtext(context),
                      ),
                    )
                  else
                    Column(
                      children: _upcomingEvents.map((e) {
                        return GestureDetector(
                          onTap: () => _openEvent(e['url']),
                          child: Card(
                            color: AppColors.card(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                if (e['img'] != null && e['img'].isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(10),
                                    ),
                                    child: Image.network(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          e['title'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Cinzel',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.foreground(
                                              context,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          e['date'],
                                          style: TextStyle(
                                            fontFamily: 'Cormorant',
                                            fontSize: 13,
                                            color: AppColors.subtext(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
