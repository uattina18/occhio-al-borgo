import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

/// Schermata di emergenza.
///
/// L'app NON invia richieste di aiuto a nessuno: l'unica azione è aprire il
/// telefono con il 112 già composto. Su telefono `tel:` apre solo il tastierino,
/// la chiamata parte quando l'utente preme il tasto verde.
///
/// In modalità di sviluppo (debug) il telefono non viene aperto: si mostra solo
/// un avviso, così durante i test non si rischia di chiamare davvero.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  static const String _emergencyNumber = '112';

  Future<void> _callEmergency(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chiamare il 112?'),
        content: const Text(
          'Si aprirà il telefono con il numero di emergenza 112 già composto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apri il telefono'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Modalità di sviluppo: niente chiamata, solo un avviso.
    if (kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Modalità sviluppo: qui si aprirebbe il telefono con il 112.',
          ),
        ),
      );
      return;
    }

    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: _emergencyNumber));
    } catch (e) {
      debugPrint('Impossibile aprire il telefono: $e');
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile aprire il telefono. Componi il 112 manualmente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Emergenza'),
        backgroundColor: const Color(0xFF91be7e),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Colors.redAccent,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                'Hai bisogno di aiuto?',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Questa app non invia richieste di aiuto. '
                'In caso di emergenza chiama il numero unico 112.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.foreground(context),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _callEmergency(context),
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text(
                  'CHIAMA IL 112',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cinzel',
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
