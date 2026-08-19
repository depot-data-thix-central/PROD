/// THIX SOS — Ajouter un secours (production)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/sos_providers.dart';

class AjouterSecoursPage extends ConsumerStatefulWidget {
  const AjouterSecoursPage({super.key, this.initialCircle = 1});

  final int initialCircle;

  @override
  ConsumerState<AjouterSecoursPage> createState() => _AjouterSecoursPageState();
}

class _AjouterSecoursPageState extends ConsumerState<AjouterSecoursPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _thixIdCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();

  late int _circle;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _circle = widget.initialCircle.clamp(1, 3);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _thixIdCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(sosContactActionsProvider).add(
            name: _nameCtrl.text.trim(),
            circle: _circle,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            thixId:
                _thixIdCtrl.text.trim().isEmpty ? null : _thixIdCtrl.text.trim(),
            relation: _relationCtrl.text.trim().isEmpty
                ? null
                : _relationCtrl.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secours ajouté'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ajouter un secours',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Cercle',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in [1, 2, 3]) ...[
                  Expanded(child: _CircleChoice(
                    circle: c,
                    selected: _circle == c,
                    onTap: () => setState(() => _circle = c),
                  )),
                  if (c < 3) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 24),

            _label('Nom complet *'),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: _decoration('Ex: Marie Leroy'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 16),

            _label('Téléphone'),
            TextFormField(
              controller: _phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: _decoration('+243 …'),
            ),
            const SizedBox(height: 16),

            _label('THIX ID (optionnel)'),
            TextFormField(
              controller: _thixIdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('THIX-XXXX'),
            ),
            const SizedBox(height: 16),

            _label('Relation'),
            TextFormField(
              controller: _relationCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Ex: Mère, Ami, Collègue…'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Enregistrer le secours',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white24),
      filled: true,
      fillColor: const Color(0xFF16161F),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _CircleChoice extends StatelessWidget {
  const _CircleChoice({
    required this.circle,
    required this.selected,
    required this.onTap,
  });

  final int circle;
  final bool selected;
  final VoidCallback onTap;

  Color get _color {
    switch (circle) {
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String get _label {
    switch (circle) {
      case 1:
        return 'Prioritaire';
      case 2:
        return 'Secondaire';
      default:
        return 'Urgence';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _color.withOpacity(0.2) : const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _color : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$circle',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: selected ? _color : Colors.white54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? _color : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
