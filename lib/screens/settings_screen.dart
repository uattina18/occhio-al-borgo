import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_navbar.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _selectedMode;
  bool _notificationsEnabled = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  void _changeMode(ThemeMode mode) {
    setState(() => _selectedMode = mode);
    widget.onThemeChanged(mode);
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

  // ✉️ Contatta assistenza
  Future<void> _contattaSupporto() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'supporto@occhioalborgo.it',
      queryParameters: {
        'subject': 'Richiesta assistenza - Occhio al Borgo',
        'body': 'Ciao, ho bisogno di aiuto con...',
      },
    );

    try {
      final canOpen = await canLaunchUrl(emailUri);
      if (!canOpen) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessuna app di posta trovata sul dispositivo.'),
            ),
          );
        }
        return;
      }

      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore apertura email: $e')));
      }
    }
  }

  // 🔐 Logout Firebase
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma logout'),
        content: const Text('Vuoi davvero uscire dal tuo account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFB00020)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Logout effettuato con successo')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
            const Text(
              'Tema',
              style: TextStyle(fontFamily: 'Cinzel', fontSize: 18),
            ),
            const SizedBox(height: 12),

            _buildThemeOption(ThemeMode.light, 'Chiaro', Icons.wb_sunny),
            _buildThemeOption(ThemeMode.dark, 'Scuro', Icons.dark_mode),
            _buildThemeOption(ThemeMode.system, 'Sistema', Icons.phone_android),

            const SizedBox(height: 30),

            const Text(
              'Notifiche',
              style: TextStyle(fontFamily: 'Cinzel', fontSize: 18),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text(
                'Notifiche attive',
                style: TextStyle(fontFamily: 'Cormorant', fontSize: 16),
              ),
              trailing: Switch.adaptive(
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                  (states) => states.contains(WidgetState.selected)
                      ? Icon(
                          Icons.notifications_active,
                          color: AppColors.foreground(context),
                          size: 14,
                        )
                      : Icon(
                          Icons.notifications_off,
                          color: AppColors.foreground(context),
                          size: 14,
                        ),
                ),
                trackColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary(context)
                      : AppColors.foreground(context),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(thickness: 1),

            Center(
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout, color: AppColors.foreground(context)),
                label: Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: AppColors.foreground(context),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a602a),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Center(
              child: ElevatedButton.icon(
                onPressed: _contattaSupporto,
                icon: Icon(
                  Icons.mail_outline,
                  color: AppColors.foreground(context),
                ),
                label: Text(
                  'CONTATTA L’ASSISTENZA',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: AppColors.foreground(context),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ usa il nuovo approccio senza groupValue/onChanged
  Widget _buildThemeOption(ThemeMode mode, String label, IconData icon) {
    final theme = Theme.of(context);

    return RadioMenuButton<ThemeMode>(
      value: mode,
      groupValue: _selectedMode,
      onChanged: (value) {
        if (value != null) _changeMode(value);
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFFD7E9D2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Cormorant', fontSize: 16),
          ),
        ],
      ),
    );
  }
}
