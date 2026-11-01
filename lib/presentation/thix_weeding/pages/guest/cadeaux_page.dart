// lib/presentation/thix_weeding/pages/guest/cadeaux_page.dart
// Guest : SIGNALER un cadeau (pas contribution financière)
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _R {
  static const rose = Color(0xFFE31C4E);
  static const roseSoft = Color(0xFFFFE3EA);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const ink = Color(0xFF241521);
  static const soft = Color(0xFF8A7580);
  static const border = Color(0xFFF3E1E6);
  static const surface = Color(0xFFFFFBFC);
}

const _giftTypes = [
  'Objet',
  'Argent / Cagnotte',
  'Expérience',
  'Voyage',
  'Maison / Déco',
  'Électroménager',
  'Autre',
];

final _guestGiftsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_gifts')
      .select()
      .eq('wedding_id', weddingId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res)
      .where((e) {
        final st = e['status'] as String? ?? '';
        // Invité voit ses propositions + validés (pas les rejetés)
        return st != 'rejected';
      })
      .toList();
});

class CadeauxPage extends ConsumerStatefulWidget {
  final String weddingId;
  const CadeauxPage({super.key, required this.weddingId});

  @override
  ConsumerState<CadeauxPage> createState() => _CadeauxPageState();
}

class _CadeauxPageState extends ConsumerState<CadeauxPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_guestGiftsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _R.ink,
        elevation: 0,
        title: Text('Cadeaux', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _R.rose,
        onPressed: _openSignal,
        icon: const Icon(Icons.add),
        label: const Text('Signaler un cadeau'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _R.rose)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Erreur: $e'),
            FilledButton(
              onPressed: () => ref.invalidate(_guestGiftsProvider(widget.weddingId)),
              child: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (gifts) => RefreshIndicator(
          color: _R.rose,
          onRefresh: () async => ref.invalidate(_guestGiftsProvider(widget.weddingId)),
          child: CustomScrollView(slivers: [
           
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signaler un cadeau',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Indiquez un cadeau que vous offrez ou souhaitez offrir. '
                      'L’organisation validera votre signalement. '
                      'Seul le nom est obligatoire.',
                      style: GoogleFonts.inter(fontSize: 13, color: _R.soft, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            if (gifts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Aucun cadeau signalé pour le moment')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _SignalTile(gift: gifts[i]),
                    childCount: gifts.length,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openSignal() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final whoCtrl = TextEditingController();
    String? giftType;
    Uint8List? photoBytes;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Signaler un cadeau',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Ce n’est pas une contribution financière — juste un signalement.',
                      style: GoogleFonts.inter(fontSize: 12, color: _R.soft)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nom du cadeau *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: giftType,
                    decoration: const InputDecoration(
                      labelText: 'Nature / type (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: _giftTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setModal(() => giftType = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valeur indicative FCFA (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: whoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Votre nom (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1600,
                            imageQuality: 85,
                          );
                          if (x == null) return;
                          final bytes = await x.readAsBytes();
                          setModal(() => photoBytes = bytes);
                        },
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: Text(photoBytes == null ? 'Photo (optionnel)' : 'Changer photo'),
                      ),
                      if (photoBytes != null) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(photoBytes!, width: 48, height: 48, fit: BoxFit.cover),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _R.rose),
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indiquez le nom du cadeau')),
                                );
                                return;
                              }
                              setModal(() => saving = true);
                              try {
                                String? imageUrl;
                                if (photoBytes != null) {
                                  final path =
                                      '${widget.weddingId}/gifts/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  await Supabase.instance.client.storage
                                      .from('thix-weeding-gallery')
                                      .uploadBinary(
                                        path,
                                        photoBytes!,
                                        fileOptions: const FileOptions(
                                          contentType: 'image/jpeg',
                                          upsert: true,
                                        ),
                                      );
                                  imageUrl = Supabase.instance.client.storage
                                      .from('thix-weeding-gallery')
                                      .getPublicUrl(path);
                                }

                                final price = double.tryParse(
                                      priceCtrl.text.replaceAll(' ', '').replaceAll(',', ''),
                                    ) ??
                                    0;

                                final payload = <String, dynamic>{
                                  'wedding_id': widget.weddingId,
                                  'name': name,
                                  'price': price,
                                  'contributed': 0,
                                  'status': 'proposed',
                                  'is_group_collect': false,
                                };
                                final desc = descCtrl.text.trim();
                                if (desc.isNotEmpty) payload['description'] = desc;
                                if (giftType != null) payload['gift_type'] = giftType;
                                if (whoCtrl.text.trim().isNotEmpty) {
                                  payload['proposed_by_name'] = whoCtrl.text.trim();
                                }
                                if (imageUrl != null) payload['image_url'] = imageUrl;

                                try {
                                  await Supabase.instance.client
                                      .from('thix_weeding_gifts')
                                      .insert(payload);
                                } catch (e) {
                                  final soft = Map<String, dynamic>.from(payload)
                                    ..remove('description')
                                    ..remove('gift_type')
                                    ..remove('image_url')
                                    ..remove('proposed_by_name')
                                    ..remove('is_group_collect');
                                  await Supabase.instance.client
                                      .from('thix_weeding_gifts')
                                      .insert(soft);
                                }

                                ref.invalidate(_guestGiftsProvider(widget.weddingId));
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('Cadeau signalé — en attente de validation'),
                                    backgroundColor: _R.green,
                                  ));
                                }
                              } catch (e) {
                                setModal(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: _R.rose,
                                ));
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Envoyer le signalement'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

class _SignalTile extends StatelessWidget {
  final Map<String, dynamic> gift;
  const _SignalTile({required this.gift});

  @override
  Widget build(BuildContext context) {
    final name = gift['name']?.toString() ?? '';
    final type = gift['gift_type']?.toString() ?? '';
    final status = gift['status']?.toString() ?? '';
    final img = gift['image_url']?.toString() ?? '';
    final by = gift['proposed_by_name']?.toString() ?? '';
    final price = (gift['price'] as num?)?.toDouble() ?? 0;
    final desc = gift['description']?.toString() ?? '';

    final (label, color) = switch (status) {
      'proposed' => ('En attente', _R.amber),
      'approved' || 'wishlist' => ('Accepté', _R.green),
      'completed' => ('Déposé', _R.green),
      _ => (status, _R.soft),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: img.isNotEmpty
                ? Image.network(img, width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ph())
                : _ph(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                    ),
                  ],
                ),
                if (type.isNotEmpty)
                  Text(type, style: GoogleFonts.inter(fontSize: 12, color: _R.rose, fontWeight: FontWeight.w600)),
                if (desc.isNotEmpty)
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: _R.soft)),
                if (price > 0)
                  Text('${price.toStringAsFixed(0)} FCFA',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.rose, fontSize: 12)),
                if (by.isNotEmpty)
                  Text('Par $by', style: GoogleFonts.inter(fontSize: 11, color: _R.soft)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ph() => Container(
        width: 64,
        height: 64,
        color: _R.roseSoft,
        child: const Icon(Icons.card_giftcard, color: _R.rose),
      );
}
