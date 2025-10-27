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
import 'package:occhio_al_borgo/theme/app_theme.dart';

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

  StreamSubscription<MagnetometerEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;

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
    } catch (e) {
      debugPrint('Errore inizializzazione fotocamera: $e');
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
      debugPrint('Errore nel tracciamento posizione: $e');
    }
  }

  void _listenCompass() {
    _compassSubscription = magnetometerEvents.listen((event) {
      // Calcola direzione magnetica (azimuth)
      final double heading = atan2(event.y, event.x) * (180 / pi);
      setState(() {
        _azimuth = (heading + 360) % 360; // Normalizza tra 0 e 360°
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

  Future<String?> _identifyBorgo(double lat, double lng) async {
    try {
      final jsonData = await rootBundle.loadString(
        'assets/data/borghi_min.json',
      );
      final List data = json.decode(jsonData);
      double minDistance = double.infinity;
      String? nearestName;

      for (final borgo in data) {
        final dist = _distanceInKm(lat, lng, borgo['lat'], borgo['lng']);
        if (dist < minDistance) {
          minDistance = dist;
          nearestName = borgo['name'];
        }
      }

      return (minDistance < 5.0) ? nearestName : null;
    } catch (e) {
      debugPrint('Errore identificazione borgo: $e');
      return null;
    }
  }

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

      if (connectivity == ConnectivityResult.none || level <= 10) {
        await prefs.setBool('pending_borgo', true);
        await prefs.setString('pending_borgo_path', path);
      } else {
        String? detectedName;
        if (_latitude != null && _longitude != null) {
          detectedName = await _identifyBorgo(_latitude!, _longitude!);
        }
        await prefs.setString(
          'last_borgo_name',
          detectedName ?? 'Borgo sconosciuto',
        );
        await prefs.setBool('pending_borgo', false);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Errore durante lo scatto: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelColor = Colors.black.withValues(alpha: 0.5);
    final Color captureColor = isDark
        ? const Color(0xFF3a602a)
        : AppColors.accent(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // 📍 Coordinate GPS
          Positioned(
            bottom: 120,
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

          // 🧭 Bussola sincronizzata
          Positioned(
            bottom: 100,
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
                            color: Colors.white.withValues(alpha: 0.8),
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

          // 📸 Pulsante di scatto
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
                    color: captureColor.withValues(alpha: 0.9),
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
