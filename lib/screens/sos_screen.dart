import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:occhio_al_borgo/theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSending = false;

  Future<void> _sendSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma SOS'),
        content: const Text(
          'Vuoi davvero inviare una richiesta di aiuto? Verrà salvata la tua posizione attuale e notificato il supporto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Invia SOS'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance.collection('sos_requests').add({
        'uid': user?.uid,
        'email': user?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Richiesta di aiuto inviata con successo.'),
        ),
      );
    } catch (e) {
      debugPrint('❌ Errore invio SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l’invio della richiesta.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _callEmergency() async {
    const emergencyNumber = '112';
    final Uri telUri = Uri(scheme: 'tel', path: emergencyNumber);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire il dialer del telefono.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Emergenza SOS'),
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
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSending ? null : _sendSOS,
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
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text(
                        'INVIA SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cinzel',
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _callEmergency,
                icon: const Icon(Icons.phone, color: Colors.green),
                label: const Text(
                  'Chiama il 112',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'Cinzel',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
