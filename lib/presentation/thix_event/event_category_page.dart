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

const _names = {
  'musique': 'Musique & Concerts',
  'concert': 'Musique & Concerts',
  'festival': 'Festivals',
  'business': 'Business',
  'conference': 'Conférences',
  'culture': 'Culture & Art',
  'sport': 'Sport',
  'spectacle': 'Spectacles',
};

class EventCategoryPage extends ConsumerStatefulWidget {
  final String category;
  const EventCategoryPage({super.key, required this.category});
  @override
  ConsumerState<EventCategoryPage> createState() => _EventCategoryPageState();
}

class _EventCategoryPageState extends ConsumerState<EventCategoryPage> {
  final ScrollController _scroll = ScrollController();
  List<Event> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 &&!_loading &&!_loadingMore && _hasMore) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { _page = 0; _hasMore = true; }
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(eventServiceProvider);
      final res = await svc.getEvents(category: widget.category, page: 0, limit: 20);
      if (!mounted) return;
      setState(() { _events = res; _loading = false; _hasMore = res.length >= 20; _page = 0; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Connexion impossible'; });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final svc = ref.read(eventServiceProvider);
      final res = await svc.getEvents(category: widget.category, page: _page + 1, limit: 20);
      if (!mounted) return;
      setState(() { _page++; _events = [..._events,...res]; _hasMore = res.length >= 20; _loadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: _appBar(),
      body: _loading
         ? const Center(child: CircularProgressIndicator(color: _ThixColors.primary))
          : _error!= null
             ? _errorState()
              : _events.isEmpty
                 ? _emptyState()
                  : RefreshIndicator(
                      color: _ThixColors.primary,
                      backgroundColor: _ThixColors.surface,
                      onRefresh: () => _load(refresh: true),
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.68),
                              delegate: SliverChildBuilderDelegate((_, i) => _card(_events[i]), childCount: _events.length),
                            ),
                          ),
                          if (_loadingMore) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ThixColors.primary))))),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
    );
  }

  PreferredSizeWidget _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: _ThixColors.bg.withOpacity(0.85),
            elevation: 0,
            leading: Padding(padding: const EdgeInsets.all(8), child: InkWell(onTap: () => context.pop(), borderRadius: BorderRadius.circular(20), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18)))),
            title: Text(_names[widget.category.toLowerCase()]?? widget.category.toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            centerTitle: true,
          ),
        ),
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
            Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.12))), child: Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
          ]),
          Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
            const Spacer(),
            Row(children: [Container(height: 26, width: 26, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 12)), const SizedBox(width: 6), const Expanded(child: Text('Réserver', style: TextStyle(fontSize: 10, color: _ThixColors.textSecondary, fontWeight: FontWeight.w700)))]),
          ]))),
        ]),
      ),
    );
  }

  Widget _errorState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.wifi_off_rounded, color: Colors.red)), const SizedBox(height: 14), Text(_error!, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 13)), const SizedBox(height: 16), ElevatedButton(onPressed: () => _load(), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.w800)))]));
  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: Icon(Icons.local_activity_outlined, size: 40, color: Colors.white.withOpacity(0.3))), const SizedBox(height: 16), const Text('Aucun événement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)), const SizedBox(height: 6), const Text('Pas encore d\'événements\ndans cette catégorie', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _ThixColors.textMuted)), const SizedBox(height: 20), OutlinedButton(onPressed: () => context.pop(), style: OutlinedButton.styleFrom(side: const BorderSide(color: _ThixColors.cardBorderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Retour', style: TextStyle(color: Colors.white)))]));
}
