import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class EventSearchPage extends ConsumerStatefulWidget {
  const EventSearchPage({super.key});
  @override
  ConsumerState<EventSearchPage> createState() => _EventSearchPageState();
}

class _EventSearchPageState extends ConsumerState<EventSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<Event> _results = [];
  bool _searching = false;
  String _filter = 'all';
  String _city = 'all';
  Timer? _debounce;
  final _cities = const ['all', 'Kinshasa', 'Lubumbashi', 'Goma', 'Bukavu', 'Kisangani'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _doSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = q.trim();
      if (query.isEmpty) {
        if (mounted) setState(() { _results = []; _searching = false; });
        return;
      }
      setState(() => _searching = true);
      var res = await ref.read(eventServiceProvider).searchEvents(query);
      if (_city!= 'all') res = res.where((e) => e.city == _city).toList();
      if (_filter == 'free') res = res.where((e) => e.isFree).toList();
      if (mounted) setState(() { _results = res; _searching = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () => context.pop(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: _ThixColors.cardBorder),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _ThixColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ThixColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _doSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Rechercher...",
                      hintStyle: const TextStyle(color: _ThixColors.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _ThixColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_controller.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _ThixColors.cardBorder)),
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _chip("Tous", "all", _filter, (v) { setState(() => _filter = v); _doSearch(_controller.text); }),
                        const SizedBox(width: 8),
                        _chip("Gratuits", "free", _filter, (v) { setState(() => _filter = v); _doSearch(_controller.text); }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _cities.map((c) {
                        final label = c == "all"? "Toutes villes" : c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _chip(label, c, _city, (v) { setState(() => _city = v); _doSearch(_controller.text); }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _searching
               ? const Center(child: CircularProgressIndicator(color: _ThixColors.primary))
                : _results.isEmpty && _controller.text.isNotEmpty
                   ? _emptyResult()
                    : _results.isEmpty
                       ? _initial()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _card(_results[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, String group, Function(String) onTap) {
    final sel = group == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel? _ThixColors.primary.withOpacity(0.15) : _ThixColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel? _ThixColors.primary : _ThixColors.cardBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: sel? FontWeight.w800 : FontWeight.w600, color: sel? _ThixColors.primary : _ThixColors.textSecondary)),
      ),
    );
  }

  Widget _card(Event e) {
    return GestureDetector(
      onTap: () => context.push("/thix-event/event/${e.id}"),
      child: Container(
        decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ThixColors.cardBorder)),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(e.imageUrl?? "", width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: Colors.white10)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text("${e.formattedDate} - ${e.location}", maxLines: 1, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyResult() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.search_off_rounded, size: 32, color: _ThixColors.textMuted)),
        const SizedBox(height: 14),
        Text('Aucun resultat pour "${_controller.text}"', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _initial() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: const Icon(Icons.travel_explore_rounded, size: 32, color: _ThixColors.textMuted)),
        const SizedBox(height: 14),
        const Text("Trouvez votre prochaine sortie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
