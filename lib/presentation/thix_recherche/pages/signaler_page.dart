import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/recherche_providers.dart';

class SignalerPage extends ConsumerStatefulWidget {
  const SignalerPage({super.key, required this.personneId});
  final String personneId;

  @override
  ConsumerState<SignalerPage> createState() => _SignalerPageState();
}

class _SignalerPageState extends ConsumerState<SignalerPage> {
  final _msgCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(rechercheServiceProvider).signalerInfo(
            personneId: widget.personneId,
            message: _msgCtrl.text,
            zone: _zoneCtrl.text.isEmpty ? null : _zoneCtrl.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement envoyé. Merci.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signaler', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _zoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Zone / lieu (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Votre information *',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Envoyer',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
