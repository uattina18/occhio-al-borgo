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
    _compassSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      if (!mounted) return;
      // Calcola azimuth approssimato
      final value = event.x;
      setState(() {
        _azimuth = value;
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

      String? detectedName;
      if (_latitude != null && _longitude != null) {
        detectedName = await _identifyBorgo(_latitude!, _longitude!);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_borgo_photo', path);
      await prefs.setString(
        'last_borgo_name',
        detectedName ?? 'Borgo sconosciuto',
      );
      await prefs.setDouble('last_borgo_lat', _latitude ?? 0);
      await prefs.setDouble('last_borgo_lng', _longitude ?? 0);
      await prefs.setDouble('last_borgo_azimuth', _azimuth ?? 0);
      await prefs.setString(
        'last_borgo_date',
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;

      Navigator.pop(context, {
        'photo': path,
        'name': detectedName,
        'lat': _latitude,
        'lng': _longitude,
        'azimuth': _azimuth,
      });
    } catch (e) {
      debugPrint('Errore scatto foto: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // 📍 Coordinate e bussola visuali
          Positioned(
            bottom: 120,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
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

          Positioned(
            bottom: 120,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _azimuth != null
                    ? 'Bussola: ${_azimuth!.toStringAsFixed(1)}°'
                    : 'Bussola...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Cormorant',
                ),
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
                    border: Border.all(color: Colors.white, width: 5),
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
