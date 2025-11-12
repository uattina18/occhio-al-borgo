import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/bottom_navbar.dart';
import 'borghi_detail_screen.dart';
import '../theme/app_theme.dart';
import 'package:occhio_al_borgo/l10n/app_localizations.dart'; // 🌍 Localizzazione

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Map<String, dynamic>> _borghi = [];
  List<Map<String, dynamic>> _filtered = [];

  String _query = '';
  String _selectedRegion = 'all';
  bool _loading = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  final List<Map<String, String>> _regioni = const [
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
    try {
      final raw = await rootBundle.loadString('assets/data/borghi_min.json');
      final decoded = json.decode(raw);
      if (decoded is! List) throw Exception('Formato JSON inatteso');

      final list = decoded.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'id': m['id'],
          'name': (m['name'] ?? '').toString(),
          'lat': (m['lat'] is num) ? m['lat'] : double.tryParse('${m['lat']}'),
          'lng': (m['lng'] is num) ? m['lng'] : double.tryParse('${m['lng']}'),
          'provinceCode': (m['provinceCode'] ?? '').toString(),
          'regionId': (m['regionId'] ?? '').toString().toLowerCase(),
        };
      }).toList();

      setState(() {
        _borghi = list;
        _filtered = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Errore caricamento dati: $e';
      });
    }
  }

  String _norm(String s) => s.toLowerCase().trim();

  void _applyFilters() {
    final q = _norm(_query);
    final region = _selectedRegion;

    final res = _borghi.where((b) {
      final name = _norm(b['name'] ?? '');
      final regionId = (b['regionId'] ?? '').toString().toLowerCase();
      final regionMatch = region == 'all' || regionId == region;
      final nameMatch = q.isEmpty || name.contains(q);
      return regionMatch && nameMatch;
    }).toList();

    setState(() => _filtered = res);
  }

  void _onSearchChanged(String text) {
    _query = text;
    _applyFilters();
  }

  void _onRegionChanged(String id) {
    _selectedRegion = id;
    _applyFilters();
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
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarColor = isDark
        ? const Color(0xFF3a602a)
        : const Color(0xFF91be7e);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          loc?.explore ?? 'Esplora Borghi',
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
            tooltip: loc?.settings ?? 'Impostazioni',
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
              child: _loading
                  ? _buildLoading(context, loc)
                  : (_error != null
                        ? _buildError(context, loc, _error!)
                        : _buildContent(context, loc)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context, AppLocalizations? loc) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircularProgressIndicator(color: AppColors.accent(context)),
      const SizedBox(height: 12),
      Text(
        loc?.loading ?? 'Caricamento in corso…',
        style: TextStyle(
          fontFamily: 'Cormorant',
          color: AppColors.subtext(context),
        ),
      ),
    ],
  );

  Widget _buildError(BuildContext context, AppLocalizations? loc, String msg) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(
            loc?.dataNotAvailable ?? 'Dati non disponibili',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontWeight: FontWeight.bold,
              color: AppColors.foreground(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cormorant',
              color: AppColors.subtext(context),
            ),
          ),
        ],
      );

  Widget _buildContent(BuildContext context, AppLocalizations? loc) {
    return Column(
      children: [
        // 🔍 Campo di ricerca
        TextField(
          decoration: InputDecoration(
            hintText: loc?.searchHint ?? 'Cerca un borgo…',
            hintStyle: TextStyle(
              fontFamily: 'Cormorant',
              color: AppColors.subtext(context),
            ),
            prefixIcon: Icon(Icons.search, color: AppColors.subtext(context)),
            filled: true,
            fillColor: AppColors.card(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
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
                  onSelected: (_) => _onRegionChanged(reg['id']!),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 📋 Lista borghi
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? (loc?.noBorghiFound ?? 'Nessun borgo trovato.')
                        : '${loc?.noBorghiFor ?? "Nessun borgo per"} "$_query".',
                    textAlign: TextAlign.center,
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
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final b = _filtered[index];
                      final region = (b['regionId'] ?? '').toString();
                      final province = (b['provinceCode'] ?? '').toString();
                      return Card(
                        color: AppColors.card(context),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            b['name'] ?? 'Borgo',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.foreground(context),
                            ),
                          ),
                          subtitle: Text(
                            [
                              region.isNotEmpty ? region.toUpperCase() : null,
                              province.isNotEmpty
                                  ? province.toUpperCase()
                                  : null,
                            ].whereType<String>().join(' – '),
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
                            final currentOffset = _scrollController.offset;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BorgoDetailScreen(
                                  id: '${b['id'] ?? ''}',
                                  name: b['name'] ?? 'Borgo sconosciuto',
                                  region: region,
                                  province: province,
                                ),
                              ),
                            );
                            if (mounted) {
                              Future.delayed(
                                const Duration(milliseconds: 120),
                                () => _scrollController.jumpTo(currentOffset),
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
    );
  }
}
