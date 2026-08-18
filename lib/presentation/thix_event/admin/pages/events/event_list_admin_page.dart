import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/admin_guards.dart';
import '../../providers/admin_event_provider.dart';
import '../../providers/admin_state.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class EventListAdminPage extends ConsumerStatefulWidget {
  const EventListAdminPage({super.key});
  @override ConsumerState<EventListAdminPage> createState() => _EventListAdminPageState();
}

class _EventListAdminPageState extends ConsumerState<EventListAdminPage> {
  final _searchCtrl = TextEditingController();
  String _cat = 'all';
  final _scroll = ScrollController();
  final _cats = ['all','concert','conference','sport','festival','theatre'];

  @override void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminEventProvider.notifier).loadEvents(refresh: true));
    _scroll.addListener(() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) ref.read(adminEventProvider.notifier).loadMoreEvents(); });
  }
  @override void dispose() { _searchCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final state = ref.watch(adminEventProvider);
    final notifier = ref.read(adminEventProvider.notifier);
    final evState = state.eventsState;

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => context.pop()),
              title: Text('Evenements (${evState.items.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              actions: [IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20), onPressed: () => context.push('/thix-event/admin/events/create'))],
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => notifier.searchEvents(v),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Rechercher par titre...', hintStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 11),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _ThixColors.textMuted),
                filled: true, fillColor: _ThixColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _ThixColors.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.cardBorder)),
              child: DropdownButton<String>(
                value: _cat, dropdownColor: _ThixColors.surface, underline: const SizedBox(), style: const TextStyle(color: Colors.white, fontSize: 11),
                items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { setState(() => _cat = v!); notifier.filterByCategory(v!); },
              ),
            ),
          ]),
        ),
        Expanded(
          child: switch (evState.status) {
            AdminStatus.loading => const Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)),
            AdminStatus.error => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(evState.error?? 'Erreur', style: const TextStyle(color: _ThixColors.textMuted)), const SizedBox(height: 8), ElevatedButton(onPressed: () => notifier.loadEvents(refresh: true), style: ElevatedButton.styleFrom(backgroundColor: _ThixColors.surface), child: const Text('Reessayer'))])),
            AdminStatus.empty => const Center(child: Text('Aucun evenement', style: TextStyle(color: _ThixColors.textMuted))),
            _ => RefreshIndicator(
              color: Colors.white, backgroundColor: _ThixColors.surface,
              onRefresh: () async => notifier.loadEvents(refresh: true),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: evState.items.length + (evState.hasMore? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == evState.items.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)));
                  return _EventTile(event: evState.items[i]);
                },
              ),
            ),
          },
        ),
      ]),
    );
  }
}

class _EventTile extends ConsumerWidget {
  final dynamic event;
  const _EventTile({required this.event});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(adminEventProvider.notifier);
    final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(event.startDate);
    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (dir) async {
        final role = await AdminGuard.getCurrentRole();
        if (!AdminGuard.canDelete(role)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas de permission delete'))); return false; }
        return await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: _ThixColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _ThixColors.cardBorder)), title: const Text('Supprimer ?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), content: Text('Supprimer ${event.title} ? Irreversible.', style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12)), actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Annuler', style: TextStyle(color: _ThixColors.textMuted))), ElevatedButton(onPressed: () => Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: _ThixColors.primary), child: const Text('Supprimer', style: TextStyle(color: Colors.white)))]))?? false;
      },
      onDismissed: (_) => notifier.deleteEvent(event.id),
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: _ThixColors.primary, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_rounded, color: Colors.white)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: event.imageUrl!= null? Image.network(event.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_,__,___) => _ph()) : _ph()),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))), if (event.isFeatured) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: const Text('STAR', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 2),
            Text('$dateStr • ${event.city?? event.location}', style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)),
            const SizedBox(height: 6),
            Row(children: [_badge('${event.price} ${event.priceCurrency}'), const SizedBox(width: 6), _badge('${event.remainingTickets?? 0}/${event.capacity?? 0} rest.'), const Spacer(), Switch.adaptive(value: event.isFeatured, activeColor: _ThixColors.primary, inactiveThumbColor: _ThixColors.textMuted, onChanged: (v) => notifier.toggleFeatured(event.id, v))]),
          ])),
          IconButton(icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white), onPressed: () => context.push('/thix-event/admin/events/create', extra: event)),
        ]),
      ),
    );
  }
  Widget _ph() => Container(width: 56, height: 56, decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.image_rounded, color: _ThixColors.textMuted, size: 18));
  Widget _badge(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: _ThixColors.cardBorder)), child: Text(t, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)));
}
