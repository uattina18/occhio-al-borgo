import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<Locale>? onLanguageChanged;
  final Locale? currentLocale;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
    this.onLanguageChanged,
    this.currentLocale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _selectedMode;
  late Locale _selectedLocale;
  bool _notificationsEnabled = true;
  bool _showSyncLogs = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
    _selectedLocale = widget.currentLocale ?? const Locale('it');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _showSyncLogs = prefs.getBool('show_sync_logs') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _toggleSyncLogs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_sync_logs', value);
    setState(() => _showSyncLogs = value);
  }

  void _changeMode(ThemeMode mode) {
    setState(() => _selectedMode = mode);
    widget.onThemeChanged(mode);
  }

  void _changeLanguage(Locale locale) {
    setState(() => _selectedLocale = locale);
    widget.onLanguageChanged?.call(locale);
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
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

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il logout')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text('Tema', style: TextStyle(fontFamily: 'Cinzel', fontSize: 18)),
            const SizedBox(height: 12),
            _buildThemeOption(ThemeMode.light, 'Chiaro', Icons.wb_sunny),
            _buildThemeOption(ThemeMode.dark, 'Scuro', Icons.dark_mode),
            _buildThemeOption(ThemeMode.system, 'Sistema', Icons.phone_android),

            const SizedBox(height: 30),
            const Text('Lingua', style: TextStyle(fontFamily: 'Cinzel', fontSize: 18)),
            const SizedBox(height: 12),
            _buildLanguageOption(const Locale('it'), 'Italiano', Icons.flag),
            _buildLanguageOption(const Locale('en'), 'English', Icons.language),

            const SizedBox(height: 30),
            const Text('Notifiche', style: TextStyle(fontFamily: 'Cinzel', fontSize: 18)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Notifiche attive', style: TextStyle(fontFamily: 'Cormorant', fontSize: 16)),
              trailing: Switch.adaptive(value: _notificationsEnabled, onChanged: _toggleNotifications),
            ),

            const SizedBox(height: 30),
            const Text('Debug', style: TextStyle(fontFamily: 'Cinzel', fontSize: 18)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Mostra log sincronizzazione', style: TextStyle(fontFamily: 'Cormorant', fontSize: 16)),
              trailing: Switch.adaptive(value: _showSyncLogs, onChanged: _toggleSyncLogs),
            ),

            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontFamily: 'Cinzel', color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, String label, IconData icon) {
    final theme = Theme.of(context);
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: _selectedMode,
      onChanged: (value) => _changeMode(value!),
      activeColor: theme.primaryColor,
      title: Row(
        children: [
          Icon(icon, color: theme.iconTheme.color),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(Locale locale, String label, IconData icon) {
    final theme = Theme.of(context);
    return RadioListTile<Locale>(
      value: locale,
      groupValue: _selectedLocale,
      onChanged: (value) {
        if (value != null) _changeLanguage(value);
      },
      activeColor: theme.primaryColor,
      title: Row(
        children: [
          Icon(icon, color: theme.iconTheme.color),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16)),
        ],
      ),
    );
  }
}
