import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class GalleriaScreen extends StatefulWidget {
  const GalleriaScreen({super.key});

  @override
  State<GalleriaScreen> createState() => _GalleriaScreenState();
}

class _GalleriaScreenState extends State<GalleriaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final picker = ImagePicker();
  bool _isUploading = false;
  List<Map<String, dynamic>> _localPhotos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocalPhotos();
  }

  Future<void> _loadLocalPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('local_photos') ?? [];
    setState(() {
      _localPhotos = saved
          .map((path) => {'path': path, 'queued': true})
          .toList();
    });
    // aggiorna subito il contatore in profilo
    await prefs.setInt('queue_count', _localPhotos.length);
  }

  Future<void> _saveLocalPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = _localPhotos.map((p) => p['path'] as String).toList();
    await prefs.setStringList('local_photos', paths);
    await prefs.setInt('queue_count', _localPhotos.length);
  }

  Future<void> _pickPhoto() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(
      () => _localPhotos.insert(0, {'path': picked.path, 'queued': true}),
    );
    await _saveLocalPhotos();
  }

  Future<void> _capturePhoto() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(
      () => _localPhotos.insert(0, {'path': picked.path, 'queued': true}),
    );
    await _saveLocalPhotos();
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    setState(() => _localPhotos.remove(photo));
    await _saveLocalPhotos();
    final file = File(photo['path']);
    if (await file.exists()) await file.delete();
  }

  Future<bool> _canUploadNow() async {
    final conn = await Connectivity().checkConnectivity();
    final battery = Battery();
    final level = await battery.batteryLevel;
    return conn != ConnectivityResult.none && level > 10;
  }

  Future<void> _uploadAll() async {
    if (!await _canUploadNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connessione o batteria insufficienti per caricare'),
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      final storage = FirebaseStorage.instance;
      final firestore = FirebaseFirestore.instance;

      for (final photo in List<Map<String, dynamic>>.from(_localPhotos)) {
        final file = File(photo['path']);
        if (!await file.exists()) continue;

        final ref = storage.ref().child(
          'community/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        await firestore.collection('posts').add({
          'title': 'Foto dalla community',
          'imageUrl': url,
          'likes': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() => photo['queued'] = false);
        await file.delete();
      }

      setState(() {
        _localPhotos.removeWhere((p) => p['queued'] == false);
      });
      await _saveLocalPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tutte le foto sono state caricate!')),
        );
      }
    } catch (e) {
      debugPrint('❌ Errore upload galleria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante il caricamento')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
        // Sei già qui
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galleria'),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.foreground(context),
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Le mie foto'),
            Tab(icon: Icon(Icons.public), text: 'Community'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFe8e9ea),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 2,
        onTap: _onNavTap,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMineTab(), _buildCommunityTab()],
      ),
    );
  }

  Widget _buildMineTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.image),
                label: const Text('Galleria'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF91be7e),
                  foregroundColor: AppColors.foreground(context),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scatta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF91be7e),
                  foregroundColor: AppColors.foreground(context),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadAll,
                icon: const Icon(Icons.cloud_upload),
                label: _isUploading
                    ? const Text('Invio...')
                    : const Text('Invia ora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
                  foregroundColor: AppColors.foreground(context),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _localPhotos.isEmpty
              ? const Center(
                  child: Text(
                    'Nessuna foto salvata',
                    style: TextStyle(fontFamily: 'Cormorant', fontSize: 16),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _localPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = _localPhotos[index];
                    final file = File(photo['path']);
                    final isQueued = photo['queued'] == true;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        if (isQueued)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.foreground(
                                  context,
                                ).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'In coda',
                                style: TextStyle(
                                  color: AppColors.foreground(context),
                                  fontSize: 12,
                                  fontFamily: 'Cinzel',
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deletePhoto(photo),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCommunityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('Nessuna foto nella community'));
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final likes = data['likes'] ?? 0;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: Image.network(
                        data['imageUrl'],
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['title'] ?? 'Senza titolo',
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.pink),
                            const SizedBox(width: 4),
                            Text('$likes'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
