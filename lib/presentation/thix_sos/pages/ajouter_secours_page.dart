/// THIX SOS — Ajouter un secours via THIX ID (production)
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
  final _thixCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  late int _circle;
  bool _searching = false;
  bool _saving = false;

  Map<String, dynamic>? _profile;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _circle = widget.initialCircle.clamp(1, 3);
  }

  @override
  void dispose() {
    _thixCtrl.dispose();
    _relationCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _displayName(Map<String, dynamic> p) {
    final full = (p['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final display = (p['display_name'] as String?)?.trim();
    if (display != null && display.isNotEmpty) return display;
    final first = (p['first_name'] as String?)?.trim() ?? '';
    final last = (p['last_name'] as String?)?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return (p['thix_id'] as String?) ?? 'Utilisateur THIX';
  }

  String? _photoUrl(Map<String, dynamic> p) {
    final a = p['avatar_url'] as String?;
    if (a != null && a.isNotEmpty) return a;
    final b = p['photo_url'] as String?;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  Future<void> _search() async {
    final raw = _thixCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _searchError = 'Saisissez un THIX ID';
        _profile = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _profile = null;
    });

    try {
      final profile =
          await ref.read(sosServiceProvider).lookupProfileByThixId(raw);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _searching = false;
          _searchError = 'Aucun compte THIX trouvé pour cet ID';
        });
        return;
      }
      setState(() {
        _searching = false;
        _profile = profile;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null) {
      setState(() => _searchError = 'Recherchez d\'abord un THIX ID valide');
      return;
    }

    setState(() => _saving = true);

    try {
      final thixId = (profile['thix_id'] as String?) ?? _thixCtrl.text.trim();
      final userId = profile['id'] as String;

      await ref.read(sosContactActionsProvider).addFromThix(
            thixId: thixId,
            contactUserId: userId,
            name: _displayName(profile),
            circle: _circle,
            photoUrl: _photoUrl(profile),
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            relation: _relationCtrl.text.trim().isEmpty
                ? null
                : _relationCtrl.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secours THIX enregistré'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
            ),
            child: Text(
              'Entrez le THIX ID du secours. Le système récupère automatiquement le nom et la photo depuis THIX.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cercle
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
                Expanded(
                  child: _CircleChoice(
                    circle: c,
                    selected: _circle == c,
                    onTap: () => setState(() => _circle = c),
                  ),
                ),
                if (c < 3) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // THIX ID + recherche
          Text(
            'THIX ID *',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _thixCtrl,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration('THIX-XXXX'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),

          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _searchError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],

          // Carte profil trouvé
          if (_profile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16161F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF374151),
                    backgroundImage: _photoUrl(_profile!) != null
                        ? NetworkImage(_photoUrl(_profile!)!)
                        : null,
                    child: _photoUrl(_profile!) == null
                        ? Text(
                            _displayName(_profile!)[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(_profile!),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (_profile!['thix_id'] as String?) ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Compte THIX vérifié',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, color: Color(0xFF34D399)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Relation (optionnel)
          Text(
            'Relation',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _relationCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Ex: Mère, Ami, Collègue…'),
          ),
          const SizedBox(height: 16),

          // Téléphone optionnel (secours uniquement, pas pour l'appel principal)
          Text(
            'Téléphone (optionnel)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: _decoration('+243 …'),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_profile == null || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                disabledBackgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
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
          const SizedBox(height: 12),
          Text(
            'Vous pouvez ajouter plusieurs secours dans chaque cercle.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
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
