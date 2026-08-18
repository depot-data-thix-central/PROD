import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/admin_constants.dart';
import '../../providers/admin_state.dart';
import '../../services/admin_event_service.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

final adminBookingsProvider = StateNotifierProvider<BookingNotifier, AdminPaginatedState<Map<String,dynamic>>>((ref) {
  return BookingNotifier(AdminEventService(Supabase.instance.client));
});

class BookingNotifier extends StateNotifier<AdminPaginatedState<Map<String,dynamic>>> {
  final AdminEventService _svc;
  String? filterEventId;
  BookingNotifier(this._svc) : super(const AdminPaginatedState());

  Future<void> load({bool refresh = false, bool loadMore = false}) async {
    if (refresh) state = state.copyWith(status: AdminStatus.loading, currentPage: 0, hasMore: true, items: []);
    if (loadMore) {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(status: AdminStatus.loadingMore);
    }
    try {
      final page = refresh? 0 : state.currentPage + (loadMore? 1 : 0);
      final data = await _svc.getBookingsPaginated(page: page, pageSize: 50, eventId: filterEventId);
      state = AdminPaginatedState(items: refresh? data : [...state.items,...data], status: data.isEmpty && refresh? AdminStatus.empty : AdminStatus.success, hasMore: data.length == 50, currentPage: page);
    } catch (e) {
      state = state.copyWith(status: AdminStatus.error, error: e.toString());
    }
  }
}

class BookingManagementPage extends ConsumerStatefulWidget {
  const BookingManagementPage({super.key});
  @override ConsumerState<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends ConsumerState<BookingManagementPage> {
  final _scrollCtrl = ScrollController();
  @override void initState() { super.initState(); Future.microtask(() => ref.read(adminBookingsProvider.notifier).load(refresh: true)); _scrollCtrl.addListener(_onScroll); }
  void _onScroll() { if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 300) ref.read(adminBookingsProvider.notifier).load(loadMore: true); }
  @override void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': case 'paid': case 'valide': return const Color(0xFF10B981);
      case 'used': case 'scanned': return _ThixColors.textMuted;
      case 'cancelled': return _ThixColors.primary;
      case 'postponed': return const Color(0xFFF59E0B);
      default: return const Color(0xFF3B82F6);
    }
  }
  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed': case 'paid': return 'VALIDE';
      case 'used': case 'scanned': return 'UTILISE';
      case 'cancelled': return 'ANNULE';
      case 'postponed': return 'REPORTE';
      default: return 'EN ATTENTE';
    }
  }

  void _showDetails(Map<String,dynamic> booking) {
    final title = booking['events']?['title']?? 'Evenement Inconnu';
    final raw = booking['status']?? 'pending';
    final col = _statusColor(raw);
    final label = _statusLabel(raw);
    final dateStr = booking['booking_date']!= null? DateFormat('dd MMM yyyy, HH:mm', 'fr').format(DateTime.parse(booking['booking_date'].toString())) : 'Date inconnue';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), border: Border(top: BorderSide(color: _ThixColors.cardBorder))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Details Billet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withOpacity(0.3))), child: Text(label, style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 18),
          _row(Icons.event_rounded, 'Evenement', title),
          const Divider(color: _ThixColors.cardBorder, height: 24),
          _row(Icons.receipt_long_rounded, 'ID Reservation', booking['id']?.toString()?? 'N/A', mono: true),
          const Divider(color: _ThixColors.cardBorder, height: 24),
          Row(children: [Expanded(child: _block('Quantite', '${booking['ticket_quantity']?? 1} place(s)')), Expanded(child: _block('Categorie', booking['ticket_category']?? 'Standard'))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _block('Montant', '${booking['total_price']?? 0} FC', color: Colors.white)), Expanded(child: _block('PIN', booking['pin_code']?.toString()?? 'N/A', mono: true))]),
          const Divider(color: _ThixColors.cardBorder, height: 24),
          _row(Icons.access_time_rounded, 'Date achat', dateStr),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 44, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))), child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String val, {bool mono = false}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: _ThixColors.textMuted), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)), const SizedBox(height: 2), Text(val, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: mono? 'monospace' : null))]))]);
  Widget _block(String l, String v, {Color color = Colors.white, bool mono = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)), const SizedBox(height: 3), Text(v, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, fontFamily: mono? 'monospace' : null))]);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBookingsProvider);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.of(context).pop()),
              title: const Text('Reservations • 50/page', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              actions: [IconButton(icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export serveur en cours (job)'))))],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.white, backgroundColor: _ThixColors.surface,
        onRefresh: () async => ref.read(adminBookingsProvider.notifier).load(refresh: true),
        child: switch (state.status) {
          AdminStatus.loading => const Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)),
          AdminStatus.error => Center(child: Text(state.error?? 'Erreur', style: const TextStyle(color: _ThixColors.textMuted))),
          AdminStatus.empty => const Center(child: Text('Aucune reservation', style: TextStyle(color: _ThixColors.textMuted))),
          _ => ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(top: 12, bottom: 100),
              itemCount: state.items.length + (state.hasMore? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == state.items.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)));
                final b = state.items[i];
                final title = b['events']?['title']?? 'Evenement';
                final raw = b['status']?? 'pending';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _ThixColors.cardBorder)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16), onTap: () => _showDetails(b),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.confirmation_num_rounded, size: 18, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 3), Text('${b['user_id'].toString().substring(0,8)}... • ${b['ticket_quantity']}x ${b['ticket_category']?? 'Std'}', style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10)), const SizedBox(height: 3), Text('${b['total_price']} FC', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: _statusColor(raw).withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: _statusColor(raw).withOpacity(0.25))), child: Text(_statusLabel(raw), style: TextStyle(color: _statusColor(raw), fontSize: 8, fontWeight: FontWeight.w900))), const SizedBox(height: 8), const Icon(Icons.chevron_right_rounded, color: _ThixColors.textMuted, size: 18)]),
                      ]),
                    ),
                  ),
                );
              },
            ),
        },
      ),
    );
  }
}
