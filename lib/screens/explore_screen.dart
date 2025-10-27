import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/bottom_navbar.dart';
import 'borghi_detail_screen.dart';
import '../theme/app_theme.dart';

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
  double _lastScrollOffset = 0;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _lastScrollOffset > 0) {
        _scrollController.jumpTo(_lastScrollOffset);
      }
    });
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color topBarColor = isDark
        ? const Color(0xFF3a602a)
        : const Color(0xFF91be7e);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          'Esplora Borghi',
          style: TextStyle(
            fontFamily: 'Cinzel',
            color: AppColors.foreground(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: topBarColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.foreground(context)),
            tooltip: 'Impostazioni',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: _onNavTap,
        backgroundColor: topBarColor,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔍 Campo di ricerca
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cerca un borgo...',
                      hintStyle: TextStyle(
                        fontFamily: 'Cormorant',
                        color: AppColors.subtext(context),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.subtext(context),
                      ),
                      filled: true,
                      fillColor: AppColors.card(context),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _regioni.map((reg) {
                        final selected = _selectedRegion == reg['id'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(
                              reg['label']!,
                              style: TextStyle(
                                fontFamily: 'Cormorant',
                                color: AppColors.foreground(context),
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.primary(context),
                            backgroundColor: AppColors.card(context),
                            onSelected: (_) => _changeRegion(reg['id']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📋 Lista borghi
                  Expanded(
                    child: _filteredBorghi.isEmpty
                        ? Center(
                            child: Text(
                              'Nessun borgo trovato.',
                              style: TextStyle(
                                fontFamily: 'Cormorant',
                                fontSize: 16,
                                color: AppColors.subtext(context),
                              ),
                            ),
                          )
                        : NotificationListener<ScrollEndNotification>(
                            onNotification: (_) {
                              _lastScrollOffset = _scrollController.offset;
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _filteredBorghi.length,
                              itemBuilder: (context, index) {
                                final b = _filteredBorghi[index];
                                return Card(
                                  color: AppColors.card(context),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      b['name'],
                                      style: TextStyle(
                                        fontFamily: 'Cinzel',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.foreground(context),
                                      ),
                                    ),
                                    subtitle: Text(
                                      (b['regionId'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Cormorant',
                                        fontSize: 14,
                                        color: AppColors.subtext(context),
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: AppColors.subtext(context),
                                    ),
                                    onTap: () async {
                                      final currentOffset =
                                          _scrollController.offset;
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BorgoDetailScreen(
                                                id: b['id'] ?? '',
                                                name:
                                                    b['name'] ??
                                                    'Borgo sconosciuto',
                                                region: b['regionId'] ?? '',
                                                province: b['provinceCode'],
                                              ),
                                        ),
                                      );
                                      if (mounted) {
                                        Future.delayed(
                                          const Duration(milliseconds: 150),
                                          () => _scrollController.jumpTo(
                                            currentOffset,
                                          ),
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
        ),
      ),
    );
  }
}
