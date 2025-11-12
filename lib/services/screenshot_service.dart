import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ScreenshotWrapper extends StatefulWidget {
  final Widget child;
  const ScreenshotWrapper({super.key, required this.child});

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  final ScreenshotController _controller = ScreenshotController();

  Future<void> _capture(BuildContext context) async {
    try {
      final image = await _controller.capture();
      if (image == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '📸 Screenshot da Occhio al Borgo!');
    } catch (e) {
      debugPrint('❌ Errore screenshot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante la cattura dello screenshot'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          // 🔘 Pulsante screenshot fisso in alto a destra
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: null,
              backgroundColor: const Color(0xFF91be7e),
              onPressed: () => _capture(context),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
