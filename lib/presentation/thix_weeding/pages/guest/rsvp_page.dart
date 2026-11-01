// lib/presentation/thix_weeding/pages/guest/rsvp_page.dart
// ============================================================================
// THIX WEDDING — RSVP GUEST (PRODUCTION)
// ✅ Oui / Non / Peut-être → thix_weeding_guests
// ✅ Pré-remplissage si user_id lié
// ✅ Design aligné invitation guest
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _R {
  static const Color rose = Color(0xFFE31C4E);
  static const Color roseSoft = Color(0xFFFFE3EA);
  static const Color ink = Color(0xFF241521);
  static const Color inkSoft = Color(0xFF8A7580);
  static const Color surface = Color(0xFFFFFBFC);
  static const Color border = Color(0xFFF3E1E6);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
}

class RsvpPage extends ConsumerStatefulWidget {
  final String weddingId;
  const RsvpPage({super.key, required this.weddingId});

  @override
  ConsumerState<RsvpPage> createState() => _RsvpPageState();
}

class _RsvpPageState extends ConsumerState<RsvpPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _msgCtrl;
  late final TextEditingController _phoneCtrl;

  String _status = 'yes'; // yes | no | maybe
  int _count = 1;
  bool _loading = true;
  bool _saving = false;
  String? _existingGuestId;
  String _couple = 'les mariés';
  String? _deadlineHint;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _msgCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final wedding = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select('bride_name, groom_name, wedding_date')
          .eq('id', widget.weddingId)
          .maybeSingle();

      if (wedding != null) {
        final b = (wedding['bride_name'] as String?)?.trim() ?? '';
        final g = (wedding['groom_name'] as String?)?.trim() ?? '';
        if (b.isNotEmpty || g.isNotEmpty) {
          _couple = [b, g].where((e) => e.isNotEmpty).join(' & ');
        }
        final d = wedding['wedding_date'];
        if (d != null) {
          final dt = DateTime.tryParse(d.toString());
          if (dt != null) {
            final limit = dt.subtract(const Duration(days: 7));
            _deadlineHint =
                'Merci de confirmer avant le ${limit.day.toString().padLeft(2, '0')}/${limit.month.toString().padLeft(2, '0')}/${limit.year}';
          }
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final guest = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id, name, phone, rsvp_status, guests_count, notes')
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();
        if (guest != null) {
          _existingGuestId = guest['id'] as String?;
          _nameCtrl.text = (guest['name'] as String?) ?? '';
          _phoneCtrl.text = (guest['phone'] as String?) ?? '';
          _msgCtrl.text = (guest['notes'] as String?) ?? '';
          _count = (guest['guests_count'] as int?) ?? 1;
          final st = (guest['rsvp_status'] as String?) ?? '';
          _status = switch (st) {
            'confirmed' || 'accepted' || 'yes' => 'yes',
            'declined' || 'no' => 'no',
            'maybe' => 'maybe',
            _ => 'yes',
          };
        }
      }
    } catch (_) {
      // soft fail — formulaire vide ok
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _dbStatus {
    switch (_status) {
      case 'yes':
        return 'confirmed';
      case 'no':
        return 'declined';
      default:
        return 'maybe';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final payload = <String, dynamic>{
        'wedding_id': widget.weddingId,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'rsvp_status': _dbStatus,
        'guests_count': _count,
        'notes': _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
      };
      if (user != null) payload['user_id'] = user.id;

      if (_existingGuestId != null) {
        await Supabase.instance.client
            .from('thix_weeding_guests')
            .update({
              'name': payload['name'],
              'phone': payload['phone'],
              'rsvp_status': payload['rsvp_status'],
              'guests_count': payload['guests_count'],
              'notes': payload['notes'],
              if (user != null) 'user_id': user.id,
            })
            .eq('id', _existingGuestId!);
      } else if (user != null) {
        final existing = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();
        if (existing != null) {
          _existingGuestId = existing['id'] as String;
          await Supabase.instance.client
              .from('thix_weeding_guests')
              .update({
                'name': payload['name'],
                'phone': payload['phone'],
                'rsvp_status': payload['rsvp_status'],
                'guests_count': payload['guests_count'],
                'notes': payload['notes'],
              })
              .eq('id', _existingGuestId!);
        } else {
          final res = await Supabase.instance.client
              .from('thix_weeding_guests')
              .insert(payload)
              .select('id')
              .single();
          _existingGuestId = res['id'] as String?;
        }
      } else {
        // Anonyme : tenter match par nom
        final byName = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .ilike('name', _nameCtrl.text.trim())
            .maybeSingle();
        if (byName != null) {
          _existingGuestId = byName['id'] as String;
          await Supabase.instance.client.from('thix_weeding_guests').update({
            'rsvp_status': payload['rsvp_status'],
            'guests_count': payload['guests_count'],
            'notes': payload['notes'],
            'phone': payload['phone'],
          }).eq('id', _existingGuestId!);
        } else {
          final res = await Supabase.instance.client
              .from('thix_weeding_guests')
              .insert(payload)
              .select('id')
              .single();
          _existingGuestId = res['id'] as String?;
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);

      final msg = switch (_status) {
        'yes' => 'Présence confirmée — à bientôt auprès de $_couple !',
        'no' => 'Réponse enregistrée. Dommage de ne pas vous voir.',
        _ => 'Réponse « Peut-être » enregistrée. Vous pourrez la modifier plus tard.',
      };

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Merci !',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900),
          ),
          content: Text(msg, style: GoogleFonts.inter(height: 1.4)),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _R.rose),
              onPressed: () {
                if (ctx.mounted) ctx.pop();
                if (mounted && context.canPop()) context.pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _R.ink,
        title: Text(
          'Confirmer ma présence',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _R.rose))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Text(
                    'RSVP',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _R.rose,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Répondez à l\'invitation de $_couple',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _R.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_deadlineHint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _deadlineHint!,
                      style: GoogleFonts.inter(fontSize: 12, color: _R.amber, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Nom
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDeco(
                      label: 'Nom complet *',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Min. 2 caractères' : null,
                  ),
                  const SizedBox(height: 14),

                  // Téléphone
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDeco(
                      label: 'Téléphone (optionnel)',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'Serez-vous présent ?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _R.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusTile(
                    title: 'Oui, avec joie !',
                    subtitle: 'Je confirmerai ma présence',
                    value: 'yes',
                    group: _status,
                    color: _R.green,
                    icon: Icons.check_circle_outline_rounded,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 8),
                  _StatusTile(
                    title: 'Peut-être',
                    subtitle: 'Je confirmerai plus tard',
                    value: 'maybe',
                    group: _status,
                    color: _R.amber,
                    icon: Icons.help_outline_rounded,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 8),
                  _StatusTile(
                    title: 'Non, désolé',
                    subtitle: 'Je ne pourrai pas venir',
                    value: 'no',
                    group: _status,
                    color: _R.rose,
                    icon: Icons.cancel_outlined,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 22),

                  // Compteur
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _R.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nombre de personnes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: _R.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _count > 1
                              ? () => setState(() => _count--)
                              : null,
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: _count > 1 ? _R.rose : _R.inkSoft,
                          ),
                        ),
                        Container(
                          minWidth: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _R.roseSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$_count',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _R.rose,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _count < 15
                              ? () => setState(() => _count++)
                              : null,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: _count < 15 ? _R.rose : _R.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _msgCtrl,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDeco(
                      label: 'Message pour les mariés (optionnel)',
                      icon: Icons.favorite_border_rounded,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _R.rose,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.2,
                              ),
                            )
                          : Text(
                              'Confirmer ma réponse',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _R.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _R.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _R.rose, width: 1.5),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String group;
  final Color color;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.group,
    required this.color,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Material(
      color: selected ? color.withOpacity(0.1) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : _R.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? color : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? Colors.white : color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: selected ? color : _R.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _R.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : _R.inkSoft,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
