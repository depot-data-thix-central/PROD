// lib/presentation/thix_money/pages/investments_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/formatter.dart';
import '../utils/constants.dart';

class InvestmentModel {
  final String id;
  final String thixId;
  final String title;
  final String description;
  final int amount;
  final double roi;
  final String statut;
  final String devise;
  final String riskLevel;
  final String category;
  final DateTime createdAt;
  final DateTime? maturityDate;
  
  InvestmentModel({
    required this.id,
    required this.thixId,
    required this.title,
    required this.description,
    required this.amount,
    required this.roi,
    required this.statut,
    required this.devise,
    required this.riskLevel,
    required this.category,
    required this.createdAt,
    this.maturityDate,
  });

  factory InvestmentModel.fromJson(Map<String, dynamic> j) => InvestmentModel(
    id: j['id'],
    thixId: j['thix_id'],
    title: j['title']?? 'Investissement',
    description: j['description']?? '',
    amount: (j['amount']?? 0) as int,
    roi: ((j['roi']?? 0) as num).toDouble(),
    statut: j['statut']?? 'actif',
    devise: j['devise']?? 'CDF',
    riskLevel: j['risk_level']?? 'modéré',
    category: j['category']?? 'general',
    createdAt: DateTime.tryParse(j['created_at']?? '')?? DateTime.now(),
    maturityDate: j['maturity_date']!= null? DateTime.tryParse(j['maturity_date']) : null,
  );

  int get projectedGain => (amount * roi / 100).toInt();
  int get totalReturn => amount + projectedGain;
}

class InvestmentsPage extends ConsumerStatefulWidget {
  const InvestmentsPage({super.key});
  @override
  ConsumerState<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends ConsumerState<InvestmentsPage> {
  final _scroll = ScrollController();
  List<InvestmentModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _filter = 'Tous';
  int _page = 0;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 && !_loadingMore && _hasMore) _load();
    });
  }

  Future<String> _getVerifiedThixId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');
    final profile = await Supabase.instance.client.from('profiles').select('thix_id').eq('id', user.id).single();
    final thixId = profile['thix_id'] as String?;
    if (thixId == null || thixId.isEmpty || thixId == 'THIX-PENDING') throw Exception('THIX ID non vérifié');
    return thixId;
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { _page = 0; _hasMore = true; _items = []; }
    if (!_hasMore) return;
    setState(() => refresh? _loading = true : _loadingMore = true);
    try {
      final thixId = await _getVerifiedThixId();
      final start = _page * _limit;
      final end = start + _limit - 1;
      dynamic query;
      if (_filter == 'Tous') {
        query = await Supabase.instance.client.from('thix_investments').select().eq('thix_id', thixId).order('created_at', ascending: false).range(start, end);
      } else {
        query = await Supabase.instance.client.from('thix_investments').select().eq('thix_id', thixId).eq('statut', _filter.toLowerCase()).order('created_at', ascending: false).range(start, end);
      }
      final fetched = (query as List).map((e) => InvestmentModel.fromJson(e)).toList();
      setState(() {
        if (refresh) _items = fetched; else _items.addAll(fetched);
        _hasMore = fetched.length == _limit;
        _page++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  int get _totalPortfolio => _items.fold<int>(0, (s, e) => s + e.amount);
  int get _totalProjected => _items.fold<int>(0, (s, e) => s + e.projectedGain);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(title: const Text('Investissements', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilter)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCreateSheet, backgroundColor: ThixConstants.primary, label: const Text('Nouveau', style: TextStyle(color: Colors.white)), icon: const Icon(Icons.add, color: Colors.white)),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F1D5E), ThixConstants.primary]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: ThixConstants.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Portefeuille vérifié', style: TextStyle(color: Colors.white70, fontSize: 12)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.verified, color: Colors.white, size: 12), SizedBox(width: 4), Text('thix_id OK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]))]),
                  const SizedBox(height: 12),
                  Text(ThixFormatter.formatAmount(_totalPortfolio, 'CDF'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('+ ${ThixFormatter.formatAmount(_totalProjected, 'CDF')} projetés • ${_items.length} actifs', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatChip(label: 'Actifs', value: '${_items.where((e) => e.statut == 'actif').length}'),
                    const SizedBox(width: 8),
                    _StatChip(label: 'ROI moyen', value: '${_items.isEmpty? 0 : (_items.map((e) => e.roi).reduce((a, b) => a + b) / _items.length).toStringAsFixed(1)}%'),
                  ]),
                ]),
              ),
            ),
            if (_loading) const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))) else if (_items.isEmpty)
              SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 80), child: Column(children: [Icon(Icons.trending_up, size: 64, color: Colors.grey), SizedBox(height: 12), Text('Aucun investissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4), Text('Chaque investissement est lié à votre THIX ID vérifié en base', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center)]))))
            else
              SliverList.builder(
                itemCount: _items.length + (_hasMore? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  final inv = _items[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                    child: ListTile(
                      onTap: () => _showDetail(inv),
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixConstants.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.show_chart, color: ThixConstants.primary)),
                      title: Row(children: [Expanded(child: Text(inv.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(inv.statut, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)))]),
                      subtitle: Text('${inv.roi}% ROI • Risque ${inv.riskLevel} • ${ThixFormatter.formatAmount(inv.projectedGain, inv.devise)} gains', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(ThixFormatter.formatAmount(inv.amount, inv.devise), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(ThixFormatter.formatDate(inv.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Tous', 'actif', 'cloture', 'en_attente'].map((f) {
            return ListTile(
              title: Text(f),
              trailing: _filter == f ? const Icon(Icons.check, color: ThixConstants.primary) : null,
              onTap: () { setState(() => _filter = f); Navigator.pop(context); _load(refresh: true); },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDetail(InvestmentModel inv) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.9, expand: false, builder: (_, scroll) => SingleChildScrollView(controller: scroll, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
      const SizedBox(height: 16),
      Text(inv.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text('THIX ID: ${inv.thixId} • Vérifié en base profiles ✓', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _DetailCard(label: 'Investi', value: ThixFormatter.formatAmount(inv.amount, inv.devise))), const SizedBox(width: 8), Expanded(child: _DetailCard(label: 'Gain projeté', value: ThixFormatter.formatAmount(inv.projectedGain, inv.devise), color: Colors.green))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _DetailCard(label: 'Total retour', value: ThixFormatter.formatAmount(inv.totalReturn, inv.devise))), const SizedBox(width: 8), Expanded(child: _DetailCard(label: 'ROI', value: '${inv.roi}%'))]),
      const SizedBox(height: 16),
      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(inv.description.isEmpty? 'Investissement THIX lié à votre thix_id, sécurisé et traçable.' : inv.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Fermer', style: TextStyle(color: Colors.white)))),
    ]))));
  }

  void _showCreateSheet() {
    final titleCtrl = TextEditingController(); final amountCtrl = TextEditingController(); String devise = 'CDF';
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Nouvel investissement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 12),
      TextField(controller: titleCtrl, decoration: InputDecoration(labelText: 'Titre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      TextField(controller: amountCtrl, decoration: InputDecoration(labelText: 'Montant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'CDF', label: Text('CDF')), ButtonSegment(value: 'USD', label: Text('USD'))], selected: {devise}, onSelectionChanged: (s) => setSt(() => devise = s.first)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () async {
        try {
          final thixId = await _getVerifiedThixId();
          await Supabase.instance.client.from('thix_investments').insert({'thix_id': thixId, 'title': titleCtrl.text, 'amount': int.parse(amountCtrl.text), 'devise': devise, 'roi': 12.5, 'statut': 'actif', 'risk_level': 'modéré', 'category': 'general'});
          if (!mounted) return; Navigator.pop(ctx); _load(refresh: true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Investissement créé et lié à votre THIX ID')));
        } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }
      }, style: ElevatedButton.styleFrom(backgroundColor: ThixConstants.primary), child: const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 24),
    ]))));
  }
}

class _StatChip extends StatelessWidget {
  final String label; final String value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]));
}

class _DetailCard extends StatelessWidget {
  final String label; final String value; final Color? color;
  const _DetailCard({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF6F8FF), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color?? Colors.black))]));
}
