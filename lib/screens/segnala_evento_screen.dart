import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class SegnalaEventoScreen extends StatefulWidget {
  const SegnalaEventoScreen({super.key});

  @override
  State<SegnalaEventoScreen> createState() => _SegnalaEventoScreenState();
}

class _SegnalaEventoScreenState extends State<SegnalaEventoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titoloController = TextEditingController();
  final _luogoController = TextEditingController();
  final _dataController = TextEditingController();
  final _linkController = TextEditingController();
  final _noteController = TextEditingController();

  File? _locandina;
  bool _loading = false;

  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _locandina = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      String imageUrl = '';
      if (_locandina != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'eventi/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(_locandina!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('eventi_segnalati').add({
        'titolo': _titoloController.text.trim(),
        'luogo': _luogoController.text.trim(),
        'data': _dataController.text.trim(),
        'link': _linkController.text.trim(),
        'note': _noteController.text.trim(),
        'immagine': imageUrl,
        'inviato_il': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento segnalato con successo!')),
      );

      _formKey.currentState!.reset();
      setState(() => _locandina = null);
    } catch (e) {
      debugPrint('Errore segnalazione: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante l’invio. Riprova.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Segnala evento'),
        backgroundColor: isDark
            ? const Color(0xFF3a602a)
            : AppColors.primary(context),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextFormField(
                      controller: _titoloController,
                      decoration: InputDecoration(
                        labelText: 'Titolo evento *',
                        filled: true,
                        fillColor: AppColors.card(context),
                      ),
                      style: TextStyle(color: AppColors.foreground(context)),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Inserisci un titolo' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _luogoController,
                      decoration: InputDecoration(
                        labelText: 'Luogo * (città/borgo)',
                        filled: true,
                        fillColor: AppColors.card(context),
                      ),
                      style: TextStyle(color: AppColors.foreground(context)),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Inserisci il luogo' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _dataController,
                      decoration: InputDecoration(
                        labelText: 'Data o periodo',
                        hintText: 'Es. 12/08/2025 - 14/08/2025',
                        filled: true,
                        fillColor: AppColors.card(context),
                      ),
                      style: TextStyle(color: AppColors.foreground(context)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        labelText: 'Link ufficiale (facoltativo)',
                        filled: true,
                        fillColor: AppColors.card(context),
                      ),
                      style: TextStyle(color: AppColors.foreground(context)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Descrizione / Note',
                        filled: true,
                        fillColor: AppColors.card(context),
                      ),
                      maxLines: 4,
                      style: TextStyle(color: AppColors.foreground(context)),
                    ),
                    const SizedBox(height: 20),

                    // Immagine locandina
                    if (_locandina != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _locandina!,
                              width: 250,
                              height: 250,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() => _locandina = null),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Rimuovi immagine',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Carica locandina'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground(context),
                        side: BorderSide(color: AppColors.foreground(context)),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Pulsante invio
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent(context),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'INVIA SEGNALAZIONE',
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
