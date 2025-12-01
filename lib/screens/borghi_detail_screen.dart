import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class BorgoDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String region;
  final String? province;

  const BorgoDetailScreen({
    super.key,
    required this.id,
    required this.name,
    required this.region,
    this.province,
  });

  @override
  State<BorgoDetailScreen> createState() => _BorgoDetailScreenState();
}

class _BorgoDetailScreenState extends State<BorgoDetailScreen> {
  List<String> _photos = [];
  final _picker = ImagePicker();
  bool _badgeUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _checkBadge();
  }

  Future<void> _checkBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlocked_badges') ?? [];
    setState(() => _badgeUnlocked = unlocked.contains('fotografa-locale'));
  }

  Future<void> _loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('photos_${widget.id}');
    if (data != null) {
      setState(() {
        _photos = List<String>.from(json.decode(data));
      });
    }
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photos_${widget.id}', json.encode(_photos));
  }

  Future<void> _addPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _photos.insert(0, picked.path));
    await _savePhotos();
    await _maybeUnlockBadge();
  }

  // ✅ NUOVA FUNZIONE: usa la tua ScattaScreen invece della camera di sistema
  Future<void> _capturePhoto() async {
    await Navigator.pushNamed(
      context,
      '/scatta',
      arguments: {'fromBorgoId': widget.id, 'fromBorgoName': widget.name},
    );

    // Ricarica le foto (in caso tu voglia salvarle in futuro tramite ScattaScreen)
    await _loadPhotos();
  }

  Future<void> _deletePhoto(String path) async {
    setState(() => _photos.remove(path));
    await _savePhotos();
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _maybeUnlockBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlocked_badges') ?? [];

    if (!unlocked.contains('fotografa-locale')) {
      unlocked.add('fotografa-locale');
      await prefs.setStringList('unlocked_badges', unlocked);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '🏅 Hai sbloccato il badge “Fotografa locale”!',
            ),
            backgroundColor: AppColors.primary(context),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() => _badgeUnlocked = true);
    }
  }

  // 🔗 Apri Wikipedia
  Future<void> _openWikipedia() async {
    final safeName = widget.name.replaceAll(' ', '_');
    final Uri url = Uri.parse(
      'https://it.wikipedia.org/wiki/${Uri.encodeComponent(safeName)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire Wikipedia')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore apertura Wikipedia: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: AppColors.primary(context),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🌍 Info borgo
            Text(
              '${widget.region.toUpperCase()}'
              '${widget.province != null ? " – ${widget.province!.toUpperCase()}" : ""}',
              style: TextStyle(
                fontFamily: 'Cormorant',
                fontSize: 16,
                color: AppColors.subtext(context),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _openWikipedia,
              icon: const Icon(Icons.public),
              label: const Text('Apri Wikipedia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: AppColors.foreground(context),
              ),
            ),

            const Divider(thickness: 1, height: 40),

            // FOTO + BADGE
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Le mie foto in questo borgo',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground(context),
                  ),
                ),
                if (_badgeUnlocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.emoji_events, color: Colors.amber),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_photos.isEmpty)
              Text(
                'Non hai ancora aggiunto foto qui.',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  color: AppColors.subtext(context),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _photos.length,
                itemBuilder: (_, i) {
                  final path = _photos[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => _deletePhoto(path),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.subtext(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.delete,
                              size: 18,
                              color: AppColors.card(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galleria'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: AppColors.foreground(context),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _capturePhoto, // 👈 ora usa ScattaScreen
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scatta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: AppColors.foreground(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
