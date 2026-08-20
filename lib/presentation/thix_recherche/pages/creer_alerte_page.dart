import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/personne_recherchee_model.dart';
import '../providers/recherche_providers.dart';
import '../utils/recherche_roles.dart';

/// mode:
/// - disparue  → tous les users authentifiés
/// - recherchee (WANTED) → admin / police / justice uniquement
class CreerAlertePage extends ConsumerStatefulWidget {
  const CreerAlertePage({
    super.key,
    this.initialType = TypeAlerte.disparue,
  });

  final TypeAlerte initialType;

  @override
  ConsumerState<CreerAlertePage> createState() => _CreerAlertePageState();
}

class _CreerAlertePageState extends ConsumerState<CreerAlertePage> {
  final _formKey = GlobalKey<FormState>();

  // Identité
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _nationaliteCtrl = TextEditingController();

  // Physique
  final _tailleCtrl = TextEditingController();
  final _descPhysiqueCtrl = TextEditingController();
  final _signesCtrl = TextEditingController();

  // Localisation
  final _zoneCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _paysCtrl = TextEditingController();

  // Motif (WANTED)
  final _motifCtrl = TextEditingController();
  final _lieuFaitsCtrl = TextEditingController();

  // Contact déclarant (disparu)
  final _contactCtrl = TextEditingController();

  TypeAlerte _type = TypeAlerte.disparue;
  String? _sexe;
  String _indicatif = '+243';
  CategorieAlerte _categorie = CategorieAlerte.disparitionInquietante;
  String _priorite = 'normale'; // normale | elevee | critique
  bool _dangereux = false;
  bool _arme = false;
  bool _nePasApprocher = false;

  DateTime? _derniereVueAt;
  double? _lat;
  double? _lng;

  final List<({Uint8List bytes, String name})> _photos = [];
  bool _loading = false;
  bool _isAdmin = false;
  bool _roleLoading = true;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _loadRole();
  }

  Future<void> _loadRole() async {
    final admin = await RechercheRoles.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = admin;
      _roleLoading = false;
      // Si non-admin force disparue
      if (!admin) _type = TypeAlerte.disparue;
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _aliasCtrl.dispose();
    _ageCtrl.dispose();
    _nationaliteCtrl.dispose();
    _tailleCtrl.dispose();
    _descPhysiqueCtrl.dispose();
    _signesCtrl.dispose();
    _zoneCtrl.dispose();
    _villeCtrl.dispose();
    _paysCtrl.dispose();
    _motifCtrl.dispose();
    _lieuFaitsCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 3) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (files.isEmpty) return;
    for (final f in files) {
      if (_photos.length >= 3) break;
      final bytes = await f.readAsBytes();
      _photos.add((bytes: bytes, name: f.name));
    }
    setState(() {});
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _derniereVueAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_derniereVueAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;

    setState(() {
      _derniereVueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _useMyLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Permission localisation refusée');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year} à '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Sécurité côté client
    if (_type == TypeAlerte.recherchee && !_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservé aux autorités (admin / police / justice)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(rechercheServiceProvider);

      List<String> urls = [];
      if (_photos.isNotEmpty) {
        urls = await service.uploadPhotos(_photos);
      }

      final age = int.tryParse(_ageCtrl.text.trim());
      final tailleRaw = double.tryParse(
        _tailleCtrl.text.trim().replaceAll(',', '.'),
      );
      final tailleCm =
          tailleRaw == null ? null : (tailleRaw < 3 ? tailleRaw * 100 : tailleRaw);

      final contact = _contactCtrl.text.trim().isEmpty
          ? null
          : '\( _indicatif \){_contactCtrl.text.trim()}';

      // Description enrichie (physique + signes + motif)
      final descParts = <String>[];
      if (_descPhysiqueCtrl.text.trim().isNotEmpty) {
        descParts.add(_descPhysiqueCtrl.text.trim());
      }
      if (_signesCtrl.text.trim().isNotEmpty) {
        descParts.add('Signes: ${_signesCtrl.text.trim()}');
      }
      if (_type == TypeAlerte.recherchee &&
          _motifCtrl.text.trim().isNotEmpty) {
        descParts.add('Motif: ${_motifCtrl.text.trim()}');
      }
      if (_type == TypeAlerte.recherchee) {
        final flags = <String>[];
        if (_dangereux) flags.add('dangereux');
        if (_arme) flags.add('possiblement armé');
        if (_nePasApprocher) flags.add('ne pas approcher');
        if (flags.isNotEmpty) descParts.add('Alerte: ${flags.join(', ')}');
        descParts.add('Priorité: $_priorite');
      }

      final zoneLabel = [
        if (_zoneCtrl.text.trim().isNotEmpty) _zoneCtrl.text.trim(),
        if (_villeCtrl.text.trim().isNotEmpty) _villeCtrl.text.trim(),
        if (_paysCtrl.text.trim().isNotEmpty) _paysCtrl.text.trim(),
      ].join(', ');

      final created = await service.creerAlerte(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim().isEmpty
            ? null
            : _prenomCtrl.text.trim(),
        age: age,
        sexe: _sexe,
        tailleCm: tailleCm,
        typeAlerte: _type,
        categorie: _type == TypeAlerte.recherchee ? _categorie : null,
        photoUrls: urls,
        photoUrl: urls.isNotEmpty ? urls.first : null,
        derniereZone: zoneLabel.isEmpty ? null : zoneLabel,
        derniereVueAt: _derniereVueAt,
        latitude: _lat,
        longitude: _lng,
        description: descParts.isEmpty ? null : descParts.join('\n'),
        contactInfo: contact,
      );

      if (!mounted) return;
      if (created != null) {
        ref.invalidate(alertesActivesProvider);
        ref.invalidate(mesAlertesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == TypeAlerte.disparue
                  ? 'Alerte disparition publiée'
                  : 'Avis WANTED publié',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_roleLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isWanted = _type == TypeAlerte.recherchee;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isWanted ? 'Créer un avis WANTED' : 'Signaler une disparition',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // ——— Type (admin seulement peut choisir WANTED) ———
            if (_isAdmin) ...[
              Text('Type',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Disparu'),
                      selected: _type == TypeAlerte.disparue,
                      onSelected: (_) =>
                          setState(() => _type = TypeAlerte.disparue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('WANTED'),
                      selected: _type == TypeAlerte.recherchee,
                      onSelected: (_) =>
                          setState(() => _type = TypeAlerte.recherchee),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ——— Photos (max 3) ———
            Text('Photos (max 3)',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _photos[i].bytes,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photos.removeAt(i)),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_photos.length < 3)
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined),
                            SizedBox(height: 4),
                            Text('Ajouter', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ——— Identité ———
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prenomCtrl,
              decoration: const InputDecoration(
                labelText: 'Prénom(s)',
                border: OutlineInputBorder(),
              ),
            ),
            if (isWanted) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _aliasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alias / surnom',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Âge',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sexe,
                    decoration: const InputDecoration(
                      labelText: 'Sexe',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'F', child: Text('F')),
                      DropdownMenuItem(value: 'M', child: Text('M')),
                      DropdownMenuItem(value: 'X', child: Text('X')),
                    ],
                    onChanged: (v) => setState(() => _sexe = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tailleCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Taille (m ou cm)',
                border: OutlineInputBorder(),
              ),
            ),
            if (isWanted) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _nationaliteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nationalité',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descPhysiqueCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description physique',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Signes distinctifs (tatouages, cicatrices…)',
                border: OutlineInputBorder(),
              ),
            ),

            // ——— WANTED only ———
            if (isWanted) ...[
              const SizedBox(height: 20),
              Text('Motif de recherche',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<CategorieAlerte>(
                value: _categorie,
                decoration: const InputDecoration(
                  labelText: 'Catégorie *',
                  border: OutlineInputBorder(),
                ),
                items: CategorieAlerte.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.labelFr)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categorie = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description du motif',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lieuFaitsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lieu associé aux faits',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Niveau d\'alerte',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Potentiellement dangereux'),
                value: _dangereux,
                onChanged: (v) => setState(() => _dangereux = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Possiblement armé'),
                value: _arme,
                onChanged: (v) => setState(() => _arme = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ne pas approcher'),
                value: _nePasApprocher,
                onChanged: (v) => setState(() => _nePasApprocher = v),
              ),
              DropdownButtonFormField<String>(
                value: _priorite,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'normale', child: Text('Normale')),
                  DropdownMenuItem(value: 'elevee', child: Text('Élevée')),
                  DropdownMenuItem(value: 'critique', child: Text('Critique')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _priorite = v);
                },
              ),
            ],

            // ——— Dernière localisation ———
            const SizedBox(height: 20),
            Text('Dernière localisation',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _derniereVueAt == null
                    ? 'Date & heure de dernière vue'
                    : 'Vu le ${_fmt(_derniereVueAt!)}',
              ),
              trailing: const Icon(Icons.event),
              onTap: _pickDateTime,
            ),
            TextFormField(
              controller: _zoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Zone / quartier',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _villeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _paysCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pays',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                _lat == null
                    ? 'Utiliser ma position GPS'
                    : 'GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
              ),
            ),

            // ——— Contact déclarant (surtout disparition) ———
            if (!isWanted) ...[
              const SizedBox(height: 20),
              Text('Votre contact (optionnel)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      value: _indicatif,
                      decoration: const InputDecoration(
                        labelText: 'Indicatif',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '+243', child: Text('+243')),
                        DropdownMenuItem(value: '+225', child: Text('+225')),
                        DropdownMenuItem(value: '+237', child: Text('+237')),
                        DropdownMenuItem(value: '+221', child: Text('+221')),
                        DropdownMenuItem(value: '+33', child: Text('+33')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _indicatif = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Numéro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ——— Avertissement public ———
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                isWanted
                    ? '⚠️ NE PAS INTERVENIR DIRECTEMENT\n'
                        'Transmettez toute information aux autorités compétentes.'
                    : '⚠️ Si vous avez des informations sur cette personne, '
                        'contactez les secours ou la police. Ne prenez aucun risque.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWanted
                      ? const Color(0xFF7F1D1D)
                      : const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isWanted
                            ? 'Publier l\'avis WANTED'
                            : 'Publier la disparition',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
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
}
