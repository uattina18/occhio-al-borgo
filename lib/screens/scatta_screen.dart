import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import '../widgets/bottom_navbar.dart';
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

  String? _currentBorgo;

  StreamSubscription<MagnetometerEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationUpdates();
    _listenCompass();
  }

  /* ========================= CAMERA ========================= */

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(cameras.first, ResolutionPreset.medium);
      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      debugPrint("❌ Errore camera: $e");
    }
  }

  /* ========================= GPS ========================= */

  void _startLocationUpdates() async {
    await Geolocator.requestPermission();

    _positionSubscription = Geolocator.getPositionStream().listen((pos) {
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    });
  }

  /* ========================= COMPASS ========================= */

  void _listenCompass() {
    _compassSubscription = magnetometerEvents.listen((event) {
      final heading = atan2(event.y, event.x) * (180 / pi);
      setState(() {
        _azimuth = (heading + 360) % 360;
      });
    });
  }

  /* ========================= BACKEND ========================= */

  Future<Map<String, dynamic>> _callBackendAI(
    String imagePath,
    double lat,
    double lng,
    double heading,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.178.24:8000/recognize'),
    );

    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    request.fields['lat'] = lat.toString();
    request.fields['lng'] = lng.toString();
    request.fields['heading'] = heading.toString();

    var response = await request.send();
    var resBody = await response.stream.bytesToString();

    return jsonDecode(resBody);
  }

  /* ========================= CAPTURE ========================= */

  Future<void> _capture() async {
    if (_controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final img = await _controller!.takePicture();

      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(
        dir.path,
        "borgo_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      await img.saveTo(path);

      if (_latitude == null || _longitude == null || _azimuth == null) {
        setState(() => _isCapturing = false);
        return;
      }

      final result = await _callBackendAI(
        path,
        _latitude!,
        _longitude!,
        _azimuth!,
      );

      final candidates = result["candidates"];

      /* 🔥 BLOCCO SE NON È BORGO */
      if (candidates == null || candidates.isEmpty) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("🤖 Analisi immagine"),
            content: Text(
              "Non sembra esserci un borgo.\nProva a inquadrare meglio.",
            ),
          ),
        );

        setState(() => _isCapturing = false);
        return;
      }

      final top = candidates[0];

      final name = top["name"];
      final borgoLat = top["lat"];
      final borgoLng = top["lng"];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("last_borgo_photo", path);
      await prefs.setString("last_borgo_name", name);
      await prefs.setString(
        "last_borgo_date",
        DateTime.now().toIso8601String(),
      );

      /* 🔥 SALVI COORDINATE DEL BORGO (GIUSTO) */
      await prefs.setDouble("last_borgo_lat", borgoLat);
      await prefs.setDouble("last_borgo_lng", borgoLng);

      if (!mounted) return;

      /* 🔥 POPUP FIGO */
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 40, color: Colors.green),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Cinzel',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Borgo riconosciuto",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Errore scatto: $e");
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

  /* ========================= UI ========================= */

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

    final panelColor = const Color.fromARGB(140, 0, 0, 0);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 2,
        onTap: (i) => Navigator.pushReplacementNamed(
          context,
          ['/home', '/explore', '/scatta', '/notifiche', '/profilo'][i],
        ),
        backgroundColor: AppColors.primary(context),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),

          Positioned(
            bottom: 140,
            left: 20,
            child: _buildPanel(
              panelColor,
              Text(
                _latitude != null
                    ? "Lat: ${_latitude!.toStringAsFixed(5)}\nLng: ${_longitude!.toStringAsFixed(5)}"
                    : "Localizzazione…",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

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
                    color: AppColors.accent(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(Color bg, Widget child) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
