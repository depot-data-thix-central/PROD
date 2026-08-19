/// THIX SOS — Saisie PIN sécurité (production)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/sos_providers.dart';
import '../thix_sos_screen.dart';

enum SosPinMode { cancel, resolve }

class SosPinPage extends ConsumerStatefulWidget {
  const SosPinPage({
    super.key,
    required this.incidentId,
    this.mode = SosPinMode.cancel,
  });

  final String incidentId;
  final SosPinMode mode;

  @override
  ConsumerState<SosPinPage> createState() => _SosPinPageState();
}

class _SosPinPageState extends ConsumerState<SosPinPage> {
  static const int _pinLength = 4;

  final List<String> _digits = [];
  bool _loading = false;
  String? _error;

  void _onKey(String value) {
    if (_loading) return;
    HapticFeedback.selectionClick();

    if (value == 'del') {
      if (_digits.isNotEmpty) {
        setState(() {
          _digits.removeLast();
          _error = null;
        });
      }
      return;
    }

    if (_digits.length >= _pinLength) return;

    setState(() {
      _digits.add(value);
      _error = null;
    });

    if (_digits.length == _pinLength) {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // MVP : PIN local (à remplacer par vérification serveur hashée)
    // Pour l'instant on accepte tout PIN à 4 chiffres et on exécute l'action.
    final pin = _digits.join();
    if (pin.length != _pinLength) {
      setState(() {
        _loading = false;
        _error = 'Code incomplet';
        _digits.clear();
      });
      return;
    }

    final notifier = ref.read(sosResolveProvider.notifier);
    final ok = widget.mode == SosPinMode.cancel
        ? await notifier.cancel(widget.incidentId)
        : await notifier.resolve(widget.incidentId);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.mode == SosPinMode.cancel
                ? 'SOS annulé'
                : 'SOS terminé',
          ),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ThixSosScreen()),
        (_) => false,
      );
    } else {
      setState(() {
        _loading = false;
        _error = 'Échec. Réessayez.';
        _digits.clear();
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancel = widget.mode == SosPinMode.cancel;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            Icon(
              Icons.lock_outline,
              size: 40,
              color: isCancel ? const Color(0xFFEF4444) : const Color(0xFF34D399),
            ),
            const SizedBox(height: 16),
            Text(
              isCancel ? 'Annuler le SOS' : 'Terminer le SOS',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Entrez votre code de sécurité à $_pinLength chiffres',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _digits.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (isCancel
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF34D399))
                        : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? (isCancel
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF34D399))
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            if (_loading) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFFEF4444),
                  strokeWidth: 2.5,
                ),
              ),
            ],

            const Spacer(flex: 1),

            // Pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', 'del'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((key) {
                          if (key.isEmpty) {
                            return const SizedBox(width: 72, height: 72);
                          }
                          return _Key(
                            label: key == 'del' ? null : key,
                            icon: key == 'del' ? Icons.backspace_outlined : null,
                            onTap: () => _onKey(key),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16161F),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white70, size: 24)
                : Text(
                    label!,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
