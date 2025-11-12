import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';
import '../widgets/bottom_navbar.dart';

class FotoBorgoScreen extends StatefulWidget {
  final String borgoName;

  const FotoBorgoScreen({super.key, required this.borgoName});

  @override
  State<FotoBorgoScreen> createState() => _FotoBorgoScreenState();
}

class _FotoBorgoScreenState extends State<FotoBorgoScreen> {
  final _picker = ImagePicker();
  List<String> _fotoPaths = [];

  @override
  void initState() {
    super.initState();
    _loadFoto();
  }

  Future<void> _loadFoto() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'foto_${widget.borgoName}';
    final saved = prefs.getStringList(key);

    if (saved == null || saved.isEmpty) {
      setState(() {
        _fotoPaths = [
          'assets/images/demo1.jpg',
          'assets/images/demo2.jpg',
          'assets/images/demo3.jpg',
        ];
      });
    } else {
      setState(() => _fotoPaths = saved);
    }
  }

  Future<void> _addFoto(bool fromCamera) async {
    final XFile? img = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (img == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'foto_${widget.borgoName}';
    final updated = List<String>.from(_fotoPaths)..add(img.path);
    await prefs.setStringList(key, updated);
    setState(() => _fotoPaths = updated);
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

  void _openAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Aggiungi dalla galleria'),
              onTap: () {
                Navigator.pop(context);
                _addFoto(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta una nuova foto'),
              onTap: () {
                Navigator.pop(context);
                _addFoto(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color topBarColor = const Color(0xFF91be7e);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.borgoName,
          style: const TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 4,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent(context),
        onPressed: _openAddOptions,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: _fotoPaths.isEmpty
            ? _emptyState(context)
            : GridView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _fotoPaths.length,
                itemBuilder: (context, i) {
                  final path = _fotoPaths[i];
                  final isAsset = path.startsWith('assets/');
                  return GestureDetector(
                    onTap: () => _showFullScreen(path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: isAsset
                          ? Image.asset(path, fit: BoxFit.cover)
                          : Image.file(File(path), fit: BoxFit.cover),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Nessuna foto ancora!',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aggiungi le tue foto più belle di questo borgo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cormorant',
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: _openAddOptions,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text(
              'AGGIUNGI FOTO',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent(context),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(String path) {
    final isAsset = path.startsWith('assets/');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: isAsset ? Image.asset(path) : Image.file(File(path)),
            ),
          ),
        ),
      ),
    );
  }
}
