import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/bottom_navbar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _borghi = [];
  List<dynamic> _filteredBorghi = [];
  String _query = '';
  String _selectedRegion = 'all';
  int _currentIndex = 1;

  // 🔁 controller per mantenere lo scroll
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _regioni = [
    {'id': 'all', 'label': 'Tutte'},
    {'id': 'liguria', 'label': 'Liguria'},
    {'id': 'piemonte', 'label': 'Piemonte'},
    {'id': 'toscana', 'label': 'Toscana'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBorghi();
  }

  Future<void> _loadBorghi() async {
    final jsonString = await rootBundle.loadString(
      'assets/data/borghi_min.json',
    );
    final data = json.decode(jsonString);
    setState(() {
      _borghi = data;
      _filteredBorghi = data;
    });
  }

  void _filterBorghi(String query) {
    setState(() {
      _query = query.toLowerCase();
      _filteredBorghi = _borghi.where((b) {
        final name = (b['name'] ?? '').toString().toLowerCase();
        final region = (b['regionId'] ?? '').toString().toLowerCase();
        final regionMatch =
            _selectedRegion == 'all' || region == _selectedRegion;
        return name.contains(_query) && regionMatch;
      }).toList();
    });
  }

  void _changeRegion(String region) {
    setState(() {
      _selectedRegion = region;
      _filterBorghi(_query);
    });
  }

  void _onNavTap(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      // già su esplora
    } else if (index == 2) {
      Navigator.pushNamed(context, '/scatta');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/notifiche');
    } else if (index == 4) {
      Navigator.pushNamed(context, '/profilo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFe8e9ea),
      appBar: AppBar(
        title: const Text(
          'Esplora Borghi',
          style: TextStyle(fontFamily: 'Cinzel'),
        ),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔍 Campo di ricerca
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cerca un borgo...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Cormorant',
                    color: Colors.black54,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _filterBorghi,
              ),
              const SizedBox(height: 12),

              // 🌍 Filtri regioni
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _regioni.map((reg) {
                    final selected = _selectedRegion == reg['id'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          reg['label']!,
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFF3a602a),
                        backgroundColor: const Color(0xFFD7D7D9),
                        onSelected: (_) => _changeRegion(reg['id']!),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 📋 Lista borghi con scroll salvato
              Expanded(
                child: _filteredBorghi.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun borgo trovato.',
                          style: TextStyle(
                            fontFamily: 'Cormorant',
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollEndNotification>(
                        onNotification: (_) {
                          // salva posizione corrente dello scroll
                          _lastScrollOffset = _scrollController.offset;
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredBorghi.length,
                          itemBuilder: (context, index) {
                            final b = _filteredBorghi[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(
                                  b['name'],
                                  style: const TextStyle(
                                    fontFamily: 'Cinzel',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  (b['regionId'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Cormorant',
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () async {
                                  final currentOffset =
                                      _scrollController.offset;
                                  await Navigator.pushNamed(
                                    context,
                                    '/borgo_detail',
                                    arguments: b,
                                  );
                                  // 🔙 ripristina scroll
                                  if (mounted) {
                                    Future.delayed(
                                      const Duration(milliseconds: 150),
                                      () {
                                        _scrollController.jumpTo(currentOffset);
                                      },
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔁 per mantenere la posizione dopo il pop
  double _lastScrollOffset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _lastScrollOffset > 0) {
        _scrollController.jumpTo(_lastScrollOffset);
      }
    });
  }
}
