import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart' as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ⬇️ importa la navbar aggiornata
import '../widgets/bottom_navbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String? _username;
  File? _profileImage;

  String? _lastBorgoName;
  File? _lastBorgoPhoto;
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastDate;

  List<Map<String, dynamic>> _unlockedBadges = [];
  List<_EventoItem> _upcomingEvents = [];

  final picker.ImagePicker _picker = picker.ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadUserAndProfile(),
      _loadLastBorgo(),
      _loadBadges(),
      _loadEventsFromAsset(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _loadUserAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? 'utente';
    final profilePath = prefs.getString('profile_image');
    if (profilePath != null && File(profilePath).existsSync()) {
      _profileImage = File(profilePath);
    }
  }

  Future<void> _changeProfileImage() async {
    final source = await showModalBottomSheet<picker.ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(context, picker.ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, picker.ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker.XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', image.path);
        setState(() => _profileImage = File(image.path));
      }
    }
  }

  Future<void> _loadLastBorgo() async {
    final prefs = await SharedPreferences.getInstance();
    _lastBorgoName =
        prefs.getString('last_borgo_name') ?? 'Nessun borgo riconosciuto';
    _lastLat = prefs.getDouble('last_borgo_lat');
    _lastLng = prefs.getDouble('last_borgo_lng');
    final savedPath = prefs.getString('last_borgo_photo');
    if (savedPath != null && File(savedPath).existsSync()) {
      _lastBorgoPhoto = File(savedPath);
    }
    final dateStr = prefs.getString('last_borgo_date');
    if (dateStr != null) _lastDate = DateTime.tryParse(dateStr);
  }

  Future<void> _takeNewPhotoFallback() async {
    final picker.XFile? photo = await _picker.pickImage(
      source: picker.ImageSource.camera,
    );
    if (photo != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_borgo_photo', photo.path);
      await prefs.setString('last_borgo_name', 'Borgo sconosciuto');
      await prefs.setDouble('last_borgo_lat', 0);
      await prefs.setDouble('last_borgo_lng', 0);
      await prefs.setString(
        'last_borgo_date',
        DateTime.now().toIso8601String(),
      );
      setState(() {
        _lastBorgoPhoto = File(photo.path);
        _lastBorgoName = 'Borgo sconosciuto';
        _lastDate = DateTime.now();
      });
    }
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final badgesJson = prefs.getStringList('unlocked_badges');
    if (badgesJson != null && badgesJson.isNotEmpty) {
      _unlockedBadges = badgesJson
          .map((name) => {'title': name, 'icon': Icons.star})
          .toList();
    }
  }

  Future<void> _loadEventsFromAsset() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/eventi_liguria.json',
      );
      final List<dynamic> data = json.decode(raw);
      final today = DateTime.now();
      final items = <_EventoItem>[];

      for (final ev in data) {
        final title = (ev['data-page-selector'] ?? ev['data2'] ?? 'Evento')
            .toString();
        final img = (ev['image-0-src'] ?? ev['image-src'] ?? '').toString();
        final url =
            (ev['data-page-selector-href'] ?? ev['web-scraper-start-url'] ?? '')
                .toString();
        final end = _getEndDateFromEvent(ev);
        if (end != null && !end.isBefore(today)) {
          items.add(
            _EventoItem(title: title, img: img, url: url, endDate: end),
          );
        }
      }
      items.sort((a, b) => a.endDate.compareTo(b.endDate));
      _upcomingEvents = items.take(3).toList();
    } catch (_) {
      _upcomingEvents = [];
    }
  }

  DateTime? _getEndDateFromEvent(Map ev) {
    if (ev['event_dates-0'] != null) {
      final d = _parseEndFromRange(ev['event_dates-0'].toString());
      if (d != null) return d;
    }
    if (ev['data'] != null) {
      final d = _parseItalianDateEnd(ev['data'].toString());
      if (d != null) return d;
    }
    return null;
  }

  DateTime? _parseEndFromRange(String s) {
    final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})(?!.*\d)').firstMatch(s);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!) - 1;
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month + 1, day);
  }

  static const _itMonths = {
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

  DateTime? _parseItalianDateEnd(String s) {
    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-zÀ-ÿ]+)\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final mon = _itMonths[m.group(2)!.toLowerCase()] ?? 1;
      final year = int.parse(m.group(3)!);
      return DateTime(year, mon, day);
    }
    return null;
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text(
          'Occhio al Borgo',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _changeProfileImage,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF91be7e),
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bentornata, ${_username ?? ""}!',
                style: const TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Ultimo borgo visitato',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _lastBorgoPhoto != null
                    ? Image.file(
                        _lastBorgoPhoto!,
                        width: screenWidth * 0.55,
                        height: screenWidth * 0.55,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/borgo_placeholder.png',
                        width: screenWidth * 0.55,
                        height: screenWidth * 0.55,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastDate != null
                    ? _formatItalianDate(_lastDate!)
                    : 'Data non disponibile',
                style: const TextStyle(fontFamily: 'Cormorant', fontSize: 14),
              ),
              Text(
                _lastBorgoName ?? 'Nome borgo sconosciuto',
                style: const TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/scatta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
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
              const SizedBox(height: 34),
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
                  children: _unlockedBadges
                      .map(
                        (b) => _buildBadge(
                          b['title'] as String,
                          b['icon'] as IconData,
                        ),
                      )
                      .toList(),
                )
              else
                const Text(
                  'Non hai ancora sbloccato nessun badge...\nContinua ad esplorare i borghi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cormorant',
                    fontSize: 15,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 34),
              const Text(
                'Eventi in arrivo',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_upcomingEvents.isEmpty)
                const Text(
                  'Nessun evento disponibile al momento.',
                  style: TextStyle(fontFamily: 'Cormorant', fontSize: 14),
                )
              else
                Column(
                  children: _upcomingEvents
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEventCard(e),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String title, IconData icon) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            color: Color(0xFF91be7e),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cormorant', fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(_EventoItem e) {
    Future<void> _openLink(String url) async {
      if (url.isEmpty) return;
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint('Impossibile aprire: $url');
    }

    return InkWell(
      onTap: () async {
        if (e.img.isNotEmpty) {
          await _openLink(e.img);
        } else if (e.url.isNotEmpty) {
          await _openLink(e.url);
        }
      },
      onLongPress: () async {
        if (e.url.isNotEmpty) await _openLink(e.url);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
        child: Row(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFF91be7e),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
              child: e.img.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                      child: Image.network(e.img, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.event, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fino al ${_formatItalianDate(e.endDate)}',
                      style: const TextStyle(
                        fontFamily: 'Cormorant',
                        fontSize: 13,
                        color: Colors.black54,
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
  }

  String _formatItalianDate(DateTime d) {
    const mesi = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${mesi[d.month - 1]} ${d.year}';
  }
}

class _EventoItem {
  final String title;
  final String img;
  final String url;
  final DateTime endDate;

  _EventoItem({
    required this.title,
    required this.img,
    required this.url,
    required this.endDate,
  });
}
