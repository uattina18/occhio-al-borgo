import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import '../widgets/bottom_navbar.dart';

class ScattaScreen extends StatefulWidget {
  const ScattaScreen({super.key});

  @override
  State<ScattaScreen> createState() => _ScattaScreenState();
}

class _ScattaScreenState extends State<ScattaScreen> {
  CameraController? _controller;
  bool _isReady = false;
  bool _isCapturing = false;

  double? _latitude;
  double? _longitude;
  double? _azimuth;

  String? _currentBorgo;
  double? _currentDistance;

  Timer? _updateTimer;
  StreamSubscription<MagnetometerEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationUpdates();
    _listenCompass();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(cameras.first, ResolutionPreset.medium);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);

      _updateTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (_latitude != null && _longitude != null && _azimuth != null) {
          final result = await _identifyBorgo(
            _latitude!,
            _longitude!,
            _azimuth!,
          );
          if (mounted) {
            setState(() {
              _currentBorgo = result?.$1;
              _currentDistance = result?.$2;
            });
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Errore inizializzazione fotocamera: $e');
    }
  }

  void _startLocationUpdates() async {
    try {
      await Geolocator.requestPermission();
      _positionSubscription = Geolocator.getPositionStream().listen((pos) {
        if (!mounted) return;
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
      });
    } catch (e) {
      debugPrint('❌ Errore nel tracciamento posizione: $e');
    }
  }

  void _listenCompass() {
    _compassSubscription = magnetometerEvents.listen((event) {
      final double heading = atan2(event.y, event.x) * (180 / pi);
      setState(() {
        _azimuth = (heading + 360) % 360;
      });
    });
  }

  double _distanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final y = sin(dLon) * cos(lat2 * pi / 180);
    final x =
        cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _angleDifference(double a, double b) {
    final diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  /// 🔍 Riconoscimento borgo + distanza
  Future<(String?, double?)?> _identifyBorgo(
    double lat,
    double lng,
    double bearing,
  ) async {
    try {
      final jsonData = await rootBundle.loadString(
        'assets/data/borghi_min.json',
      );
      final List data = json.decode(jsonData);

      String? bestName;
      double bestScore = double.infinity;
      double bestDist = double.infinity;

      for (final borgo in data) {
        final double dist = _distanceInKm(lat, lng, borgo['lat'], borgo['lng']);
        if (dist > 15.0) continue;

        final double borgoBearing = _calculateBearing(
          lat,
          lng,
          borgo['lat'],
          borgo['lng'],
        );
        final double diff = _angleDifference(bearing, borgoBearing);
        final double score = dist + diff / 10;

        if (score < bestScore) {
          bestScore = score;
          bestName = borgo['name'];
          bestDist = dist;
        }
      }

      return (bestScore < 30) ? (bestName, bestDist) : null;
    } catch (e) {
      debugPrint('❌ Errore identificazione borgo: $e');
      return null;
    }
  }

  /// 📸 Scatta e salva
  Future<void> _capture() async {
    if (_controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(
        dir.path,
        'borgo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await image.saveTo(path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_borgo_photo', path);
      await prefs.setDouble('last_borgo_lat', _latitude ?? 0);
      await prefs.setDouble('last_borgo_lng', _longitude ?? 0);
      await prefs.setDouble('last_borgo_azimuth', _azimuth ?? 0);
      await prefs.setString(
        'last_borgo_date',
        DateTime.now().toIso8601String(),
      );

      final connectivity = await Connectivity().checkConnectivity();
      final battery = Battery();
      final level = await battery.batteryLevel;

      String? detectedName;
      double? distanceKm;

      if (_latitude != null && _longitude != null && _azimuth != null) {
        final result = await _identifyBorgo(_latitude!, _longitude!, _azimuth!);
        detectedName = result?.$1;
        distanceKm = result?.$2;
      }

      final user = _auth.currentUser;
      if (user != null && detectedName != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'borghi_riconosciuti/${user.uid}/$detectedName/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(File(path));
        final imageUrl = await ref.getDownloadURL();

        // 🔹 Salva su Firestore in borghi_riconosciuti
        await _firestore.collection('borghi_riconosciuti').add({
          'uid': user.uid,
          'nome': detectedName,
          'photoUrl': imageUrl,
          'data': DateTime.now().toIso8601String(),
          'lat': _latitude,
          'lng': _longitude,
          'azimuth': _azimuth,
        });

        // 🔹 Salva anche in borghi_visitati
        await _firestore.collection('borghi_visitati').add({
          'uid': user.uid,
          'nome': detectedName,
          'data': DateTime.now().toIso8601String(),
          'photoUrl': imageUrl,
        });
      }

      await prefs.setString(
        'last_borgo_name',
        detectedName ?? 'Borgo sconosciuto',
      );
      await prefs.setBool('pending_borgo', false);

      if (!mounted) return;

      // 📍 Popup conferma visiva
      if (detectedName != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('📍 Borgo riconosciuto'),
            content: Text(
              '$detectedName\nDistanza: ${distanceKm?.toStringAsFixed(2)} km',
              style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❓ Borgo non riconosciuto')),
        );
      }
    } catch (e) {
      debugPrint('❌ Errore durante lo scatto: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
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
  void dispose() {
    _controller?.dispose();
    _updateTimer?.cancel();
    _compassSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent(context)),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = Colors.black.withOpacity(0.5);
    final captureColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.accent(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 2,
        onTap: _onNavTap,
        backgroundColor: AppColors.primary(context),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // 📍 Coordinate
          Positioned(
            bottom: 140,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _latitude != null && _longitude != null
                    ? 'Lat: ${_latitude!.toStringAsFixed(5)}\nLng: ${_longitude!.toStringAsFixed(5)}'
                    : 'Localizzazione...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Cormorant',
                ),
              ),
            ),
          ),

          // 🧭 Bussola
          Positioned(
            bottom: 120,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: -(_azimuth ?? 0) * (pi / 180),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _azimuth != null
                        ? '${_azimuth!.toStringAsFixed(1)}°'
                        : 'Bussola...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📌 Borgo inquadrato
          if (_currentBorgo != null)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentBorgo (${_currentDistance?.toStringAsFixed(2)} km)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Cinzel',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // 📸 Pulsante scatto
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: captureColor.withOpacity(0.9),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 2),
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
}
