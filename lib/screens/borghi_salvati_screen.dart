import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class BorghiSalvatiScreen extends StatefulWidget {
  const BorghiSalvatiScreen({super.key});

  @override
  State<BorghiSalvatiScreen> createState() => _BorghiSalvatiScreenState();
}

class _BorghiSalvatiScreenState extends State<BorghiSalvatiScreen> {
  List<Map<String, dynamic>> _borghiSalvati = [];

  @override
  void initState() {
    super.initState();
    _loadBorghi();
  }

  Future<void> _loadBorghi() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('borghi_list') ?? [];
    setState(() {
      _borghiSalvati = list
          .map((e) => jsonDecode(e))
          .where((b) => b['status'] == 'pending')
          .cast<Map<String, dynamic>>()
          .toList();
    });
  }

  Future<void> _deleteBorgo(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _borghiSalvati.removeAt(index);
    final updated = _borghiSalvati.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('borghi_list', updated);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text(
          'Borghi salvati',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: _borghiSalvati.isEmpty
          ? const Center(
              child: Text(
                'Nessun borgo salvato per ora.',
                style: TextStyle(fontFamily: 'Cormorant', fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _borghiSalvati.length,
              itemBuilder: (context, i) {
                final b = _borghiSalvati[i];
                final file = File(b['photo']);
                final exists = file.existsSync();
                final date = DateTime.tryParse(b['date'] ?? '');
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: exists
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: AppColors.subtext(context),
                          ),
                    title: Text(
                      b['name'] ?? 'Borgo sconosciuto',
                      style: const TextStyle(fontFamily: 'Cinzel'),
                    ),
                    subtitle: Text(
                      date != null
                          ? '${date.day}/${date.month}/${date.year}'
                          : 'Data sconosciuta',
                      style: const TextStyle(fontFamily: 'Cormorant'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBorgo(i),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
