import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import '../widgets/bottom_navbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class BorghiRiconosciutiScreen extends StatefulWidget {
  const BorghiRiconosciutiScreen({super.key});

  @override
  State<BorghiRiconosciutiScreen> createState() =>
      _BorghiRiconosciutiScreenState();
}

class _BorghiRiconosciutiScreenState extends State<BorghiRiconosciutiScreen> {
  List<Map<String, dynamic>> _borghi = [];

  @override
  void initState() {
    super.initState();
    _loadBorghi();
  }

  /* =========================
     DISTANZA
     ========================= */
  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /* =========================
     MAPS
     ========================= */
  Future<void> openMaps(double lat, double lng, String mode) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=$mode',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /* =========================
     LOAD BORGHI
     ========================= */
  Future<void> _loadBorghi() async {
    final prefs = await SharedPreferences.getInstance();

    final lastName = prefs.getString('last_borgo_name');
    final lastPhoto = prefs.getString('last_borgo_photo');
    final lastLat = prefs.getDouble('last_borgo_lat');
    final lastLng = prefs.getDouble('last_borgo_lng');

    double? userLat;
    double? userLng;

    try {
      final position = await Geolocator.getCurrentPosition();
      userLat = position.latitude;
      userLng = position.longitude;
    } catch (_) {}

    final List<Map<String, dynamic>> demo = [
      {'name': 'Tellaro', 'thumb': 'assets/images/demo1.jpg', 'count': 3},
      {'name': 'Apricale', 'thumb': 'assets/images/demo2.jpg', 'count': 2},
      {'name': 'Finalborgo', 'thumb': 'assets/images/demo3.jpg', 'count': 1},
    ];

    if (lastName != null) {
      demo.insert(0, {
        'name': lastName,
        'thumb': (lastPhoto != null && File(lastPhoto).existsSync())
            ? lastPhoto
            : 'assets/images/demo1.jpg',
        'count': 1,
        'lat': lastLat,
        'lng': lastLng,
        'distance':
            (lastLat != null &&
                lastLng != null &&
                userLat != null &&
                userLng != null)
            ? calculateDistance(userLat, userLng, lastLat, lastLng)
            : null,
      });
    }

    setState(() => _borghi = demo);
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
        Navigator.pushReplacementNamed(context, '/profilo');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topBarColor = const Color(0xFF91be7e);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Borghi riconosciuti',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 4,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
      ),
      backgroundColor: AppColors.background(context),
      body: _borghi.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _borghi.length,
              itemBuilder: (context, i) {
                final b = _borghi[i];
                final isAsset = (b['thumb'] as String).startsWith('assets/');

                return Card(
                  color: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isAsset
                          ? Image.asset(
                              b['thumb'],
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(b['thumb']),
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                    ),
                    title: Text(
                      b['name'],
                      style: const TextStyle(
                        fontFamily: 'Cinzel',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      b['distance'] != null
                          ? '${b['count']} foto • ${b['distance'].toStringAsFixed(1)} km'
                          : '${b['count']} foto',
                      style: const TextStyle(fontFamily: 'Cormorant'),
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (b['lat'] != null && b['lng'] != null)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.map),
                            onSelected: (value) {
                              openMaps(b['lat'], b['lng'], value);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'walking',
                                child: Text('🚶 A piedi'),
                              ),
                              PopupMenuItem(
                                value: 'driving',
                                child: Text('🚗 In auto'),
                              ),
                              PopupMenuItem(
                                value: 'bicycling',
                                child: Text('🚴 In bici'),
                              ),
                            ],
                          ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/foto_borgo',
                              arguments: b['name'],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/scatta'),
        backgroundColor: AppColors.accent(context),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text(
          'SCATTA UN BORGO',
          style: TextStyle(
            fontFamily: 'Cinzel',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            const Text(
              'Nessun borgo riconosciuto',
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scatta un borgo per iniziare a creare la tua galleria.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cormorant', fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scatta'),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text(
                'SCATTA ORA',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent(context),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
