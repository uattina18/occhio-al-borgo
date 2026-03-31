import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;

  // filtri
  String _selectedRegion = 'tutti';
  bool _nearMe = false;

  // dati
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];

  final List<Map<String, String>> _regions = [
    {'id': 'tutti', 'label': 'Tutte le aree'},
    {'id': 'liguria', 'label': 'Liguria'},
    {'id': 'toscana', 'label': 'Toscana'},
    {'id': 'piemonte', 'label': 'Piemonte'},
    {'id': 'lombardia', 'label': 'Lombardia'},
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // --------------------------------------------------
  // LOAD EVENTS DA FIRESTORE
  // --------------------------------------------------

  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();

      print("🔥 DOCUMENTI TROVATI: ${snapshot.docs.length}");

      for (var doc in snapshot.docs) {
        print("👉 DOC ID: ${doc.id}");
        print(doc.data());
      }

      _allEvents = snapshot.docs.map((doc) => doc.data()).toList();
      _filteredEvents = _allEvents;
    } catch (e) {
      print("❌ ERRORE FIRESTORE: $e");
    }

    setState(() => _loading = false);
  }

  // --------------------------------------------------
  // FILTRI
  // --------------------------------------------------

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allEvents);

    // filtro regione
    if (_selectedRegion != 'tutti') {
      filtered = filtered.where((e) => e['region'] == _selectedRegion).toList();
    }

    // filtro "vicino a me" (demo)
    if (_nearMe) {
      const double userLat = 44.4056; // Genova demo
      const double userLng = 8.9463;
      const double maxKm = 30;

      filtered = filtered.where((e) {
        if (e['lat'] == null || e['lng'] == null) return false;

        final d = _distanceKm(userLat, userLng, e['lat'], e['lng']);

        return d <= maxKm;
      }).toList();
    }

    _filteredEvents = filtered;
  }

  // --------------------------------------------------
  // DISTANZA
  // --------------------------------------------------

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  // --------------------------------------------------
  // UTILS
  // --------------------------------------------------

  String _formatDate(String? start, String? end) {
    if (start == null || start.isEmpty) return '';

    final s = DateTime.tryParse(start);
    final e = (end != null && end.isNotEmpty) ? DateTime.tryParse(end) : null;

    if (s == null) return '';

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';

    final now = DateTime.now();

    if (e != null) {
      if (s.isBefore(now) && e.isAfter(now)) {
        return 'In corso fino al ${fmt(e)}';
      }
      return 'Dal ${fmt(s)} al ${fmt(e)}';
    }

    return 'Dal ${fmt(s)}';
  }

  Future<void> _openEvent(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topBar = AppColors.primary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),

      appBar: AppBar(
        title: const Text('Eventi', style: TextStyle(fontFamily: 'Cinzel')),
        backgroundColor: topBar,
        centerTitle: true,
      ),

      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) Navigator.pushReplacementNamed(context, '/');
          if (i == 2) Navigator.pushNamed(context, '/scatta');
          if (i == 3) Navigator.pushNamed(context, '/notifiche');
          if (i == 4) Navigator.pushNamed(context, '/profilo');
        },
        backgroundColor: topBar,
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // FILTRI
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRegion,
                        items: _regions.map((r) {
                          return DropdownMenuItem(
                            value: r['id'],
                            child: Text(r['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRegion = value!;
                            _applyFilters();
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Filtra per area',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Vicino a me'),
                        value: _nearMe,
                        onChanged: (v) {
                          setState(() {
                            _nearMe = v;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // LISTA EVENTI
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? const Center(child: Text('Nessun evento disponibile'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (context, index) {
                            final e = _filteredEvents[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(10),
                                    ),
                                    child: Builder(
                                      builder: (_) {
                                        final imageUrl =
                                            (e['image'] ?? e['img'] ?? '')
                                                .toString();

                                        if (imageUrl.isNotEmpty) {
                                          return Image.network(
                                            imageUrl,
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 90,
                                                    height: 90,
                                                    color: Colors.grey.shade300,
                                                  );
                                                },
                                          );
                                        }

                                        return Container(
                                          width: 90,
                                          height: 90,
                                          color: Colors.grey.shade300,
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Text(
                                            e['title'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Cinzel',
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accent(context),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatDate(
                                              e['start_date'],
                                              e['end_date'],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _openEvent(e['url'] ?? ''),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.accent(
                                                context,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text(
                                              'SCOPRI DI PIÙ',
                                              style: TextStyle(
                                                fontFamily: 'Cinzel',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
