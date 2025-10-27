import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class BorghiVisitatiScreen extends StatefulWidget {
  const BorghiVisitatiScreen({super.key});

  @override
  State<BorghiVisitatiScreen> createState() => _BorghiVisitatiScreenState();
}

class _BorghiVisitatiScreenState extends State<BorghiVisitatiScreen> {
  List<Map<String, dynamic>> _borghiVisitati = [];

  @override
  void initState() {
    super.initState();
    _loadBorghi();
  }

  Future<void> _loadBorghi() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('borghi_list') ?? [];
    setState(() {
      _borghiVisitati = list
          .map((e) => jsonDecode(e))
          .where((b) => b['status'] == 'riconosciuto')
          .cast<Map<String, dynamic>>()
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text(
          'Borghi visitati',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: _borghiVisitati.isEmpty
          ? const Center(
              child: Text(
                'Nessun borgo visitato per ora.',
                style: TextStyle(fontFamily: 'Cormorant', fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _borghiVisitati.length,
              itemBuilder: (context, i) {
                final b = _borghiVisitati[i];
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
                            Icons.image,
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
                  ),
                );
              },
            ),
    );
  }
}
