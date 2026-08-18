import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const cardBorderStrong = Color(0x26FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class FavoriteEventsPage extends ConsumerStatefulWidget {
  const FavoriteEventsPage({super.key});
  @override
  ConsumerState<FavoriteEventsPage> createState() => _FavoriteEventsPageState();
}

class _FavoriteEventsPageState extends ConsumerState<FavoriteEventsPage> {

  Future<void> _remove(String id) async {
    await ref.read(eventServiceProvider).unlikeEvent(id);
    ref.invalidate(favoriteEventsProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiré des favoris'), backgroundColor: _ThixColors.surfaceAlt));
  }

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(favoriteEventsProvider);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              leading: Padding(padding: const EdgeInsets.all(8), child: InkWell(onTap: () => context.pop(), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18)))),
              title: const Text('Mes favoris', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _ThixColors.primary)),
        error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: _ThixColors.textMuted))),
        data: (favorites) {
          if (favorites.isEmpty) return _empty();
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.68),
            itemCount: favorites.length,
            itemBuilder: (_, i) {
              final ev = favorites[i];
              return Stack(children: [
                _card(ev),
                Positioned(top: 8, right: 8, child: InkWell(onTap: () => _remove(ev.id), borderRadius: BorderRadius.circular(20), child: Container(height: 32, width: 32, decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))), child: const Icon(Icons.favorite_rounded, color: _ThixColors.primary, size: 16)))),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _card(Event event) {
    return GestureDetector(
      onTap: () => context.push('/thix-event/event/${event.id}'),
      child: Container(
        decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(aspectRatio: 1.25, child: Image.network(event.imageUrl?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surfaceAlt))),
            Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.12))), child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
          ]),
          Expanded(child: Padding(padding: const EdgeInsets.all(11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.2)),
            const Spacer(),
            Row(children: [Container(height: 26, width: 26, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 12)), const SizedBox(width: 6), const Text('Voir', style: TextStyle(color: _ThixColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700))]),
          ]))),
        ]),
      ),
    );
  }

  Widget _empty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: Icon(Icons.favorite_border_rounded, size: 32, color: Colors.white.withOpacity(0.3))),
      const SizedBox(height: 14),
      const Text('Aucun favori', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 6),
      const Text('Ajoutez des événements à vos favoris\npour les retrouver ici', textAlign: TextAlign.center, style: TextStyle(color: _ThixColors.textMuted, fontSize: 12, height: 1.4)),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: () => context.go('/thix-event'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10)), child: const Text('Découvrir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
    ]));
  }
}
