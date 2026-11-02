import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;

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
  bool _gpsProblem = false;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initGPS();
    _initCompass();
  }

  // ================= CAMERA =================

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      debugPrint("❌ Camera error: $e");
    }
  }

  // ================= GPS =================

  Future<void> _initGPS() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!enabled ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsProblem = true);
      return;
    }

    _gpsSub = Geolocator.getPositionStream().listen(
      (pos) {
        if (!mounted) return;
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _gpsProblem = false;
        });
      },
      onError: (e) {
        debugPrint('❌ GPS error: $e');
        if (mounted) setState(() => _gpsProblem = true);
      },
    );
  }

  // ================= COMPASS =================

  void _initCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) return; // il telefono non ha la bussola

    _compassSub = stream.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      setState(() {
        _azimuth = (heading + 360) % 360;
      });
    });
  }

  // ================= BACKEND =================

  Future<Map<String, dynamic>> _callBackend(String path) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://occhio-al-borgo-backend.onrender.com/recognize'),
    );

    request.files.add(await http.MultipartFile.fromPath('file', path));

    request.fields['lat'] = _latitude!.toString();
    request.fields['lng'] = _longitude!.toString();
    if (_azimuth != null) {
      request.fields['heading'] = _azimuth!.toString();
    }

    try {
      var response = await request.send().timeout(const Duration(seconds: 25));
      var body = await response.stream.bytesToString();

      return jsonDecode(body);
    } catch (e) {
      throw Exception("Connessione fallita: $e");
    }
  }

  // ================= SCATTO =================

  Future<void> _capture() async {
    if (_controller == null || _isCapturing) return;

    if (_latitude == null || _longitude == null) {
      _showDialog(
        '📍 Posizione non disponibile',
        _gpsProblem
            ? 'Attiva il GPS e consenti all\'app di usare la posizione, poi riprova.'
            : 'Sto ancora cercando il segnale GPS. Aspetta qualche secondo e riprova.',
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();

      final result = await _callBackend(file.path);

      final candidates = result["candidates"];

      if (candidates == null || candidates.isEmpty) {
        _showDialog("🤖 AI", "Non sembra esserci un borgo.");
        return;
      }

      final name = candidates[0]["name"];

      _showDialog("📍 Borgo trovato", name);
    } catch (e) {
      _showDialog("❌ Errore", e.toString());
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ================= UI =================

  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(title: Text(title), content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _gpsSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),

          // GPS overlay
          Positioned(
            bottom: 140,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(
                _latitude != null
                    ? "Lat: ${_latitude!.toStringAsFixed(5)}\nLng: ${_longitude!.toStringAsFixed(5)}"
                    : (_gpsProblem ? "GPS non disponibile" : "GPS…"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          // Bottone scatto
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
                    color: _isCapturing ? Colors.grey : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
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
