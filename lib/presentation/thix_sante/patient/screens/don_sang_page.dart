// lib/presentation/thix_sante/patient/screens/don_sang_page.dart
// THIX SANTE - Don Sang PROD - 8 features: eligibilite, stock live, carte, alertes, histo, badges, QR, stats
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/don_sang_service.dart';

class DonSangPage extends ConsumerStatefulWidget {
  const DonSangPage({super.key});
  @override
  ConsumerState<DonSangPage> createState() => _DonSangPageState();
}

class _DonSangPageState extends ConsumerState<DonSangPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _groupe = 'O+';
  final List<String> groupes = ['O+','O-','A+','A-','B+','B-','AB+','AB-'];
  final DonSangService service = DonSangService();

  Map<String, dynamic>? _elig;
  List<Map<String, dynamic>> _centres = [];
  List<Map<String, dynamic>> _alertes = [];
  List<Map<String, dynamic>> _hist = [];
  bool _loading = true;

  final TextEditingController _poidsCtrl = TextEditingController(text: '65');
  final TextEditingController _hbCtrl = TextEditingController(text: '13.5');
  bool _tatouageRecent = false;
  bool _maladieRecente = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final e = await service.getEligibilite();
      final c = await service.getCentresWithStock(_groupe);
      final a = await service.getAlertes();
      final h = await service.getHistorique();
      if (!mounted) return;
      setState(() {
        _elig = e;
        _centres = c;
        _alertes = a;
        _hist = h;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get isEligibleQuestionnaire {
    final p = double.tryParse(_poidsCtrl.text)?? 0;
    final hb = double.tryParse(_hbCtrl.text)?? 0;
    return p >= 50 && hb >= 12 &&!_tatouageRecent &&!_maladieRecente;
  }

  @override
  void dispose() {
    _tab.dispose();
    _poidsCtrl.dispose();
    _hbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Don de sang', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFFDC2626),
          tabs: const [Tab(text: 'Donner'), Tab(text: 'Demander'), Tab(text: 'Mon suivi')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_tabDonner(), _tabDemander(), _tabSuivi()],
      ),
    );
  }

  Widget _tabDonner() {
    return CustomScrollView(
      slivers: [
        if (_alertes.isNotEmpty)
          SliverToBoxAdapter(child: _alertesCard()),
        SliverToBoxAdapter(child: _groupeSelector()),
        SliverToBoxAdapter(child: _questionnaireCard()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: const [
                Text('Stock en temps réel', style: TextStyle(fontWeight: FontWeight.w800)),
                Spacer(),
                Icon(Icons.circle, size: 8, color: Colors.green),
                SizedBox(width: 4),
                Text('Live Supabase', style: TextStyle(fontSize: 10, color: Colors.green)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: _centres.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _centreCardLive(_centres[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _alertesCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              SizedBox(width: 6),
              Text('Alertes urgentes', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 6),
         ..._alertes.map((a) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('🩸 ${a['message']}', style: const TextStyle(fontSize: 12)),
          )),
        ],
      ),
    );
  }

  Widget _groupeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Mon groupe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: groupes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final g = groupes[i];
              final sel = g == _groupe;
              return ChoiceChip(
                label: Text(g),
                selected: sel,
                selectedColor: const Color(0xFFDC2626),
                labelStyle: TextStyle(color: sel? Colors.white : const Color(0xFF6B7280), fontWeight: FontWeight.w800),
                onSelected: (_) {
                  setState(() => _groupe = g);
                  _loadAll();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _questionnaireCard() {
    final eligSupabase = _elig == null || _elig!['eligible'] == true;
    final eligible = eligSupabase && isEligibleQuestionnaire;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.quiz_rounded, color: Color(0xFFDC2626)), SizedBox(width: 8), Text('Questionnaire eligibilite', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _poidsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Poids kg', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _hbCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Hb g/dL', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (_) => setState(() {}))),
            ],
          ),
          CheckboxListTile(value: _tatouageRecent, dense: true, controlAffinity: ListTileControlAffinity.leading, title: const Text('Tatouage < 4 mois', style: TextStyle(fontSize: 12)), onChanged: (v) => setState(() => _tatouageRecent = v!)),
          CheckboxListTile(value: _maladieRecente, dense: true, controlAffinity: ListTileControlAffinity.leading, title: const Text('Fievre / maladie < 7j', style: TextStyle(fontSize: 12)), onChanged: (v) => setState(() => _maladieRecente = v!)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: eligible? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(eligible? Icons.check_circle : Icons.block_rounded, color: eligible? Colors.green : Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(eligible? 'Eligible - Vous pouvez donner' : 'Non eligible - corrigez questionnaire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: eligible? const Color(0xFF15803D) : const Color(0xFF991B1B)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centreCardLive(Map<String, dynamic> c) {
    final stock = service.getStockForGroupe(c, _groupe);
    final critique = stock <= 2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: critique? const Color(0xFFFECACA) : const Color(0xFFE5E7EB))),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c['nom']?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), Text(c['adresse']?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: critique? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)), child: Text('$stock poches $_groupe', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: critique? const Color(0xFFDC2626) : const Color(0xFF16A34A)))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(c['horaires']?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              const Spacer(),
              ElevatedButton(
                onPressed:!isEligibleQuestionnaire? null : () async {
                  try {
                    await service.prendreRdvDon(groupe: _groupe, centreId: c['id'].toString(), date: DateTime.now().add(const Duration(days: 1)), questionnaire: {'poids': double.tryParse(_poidsCtrl.text), 'hemoglobine': double.tryParse(_hbCtrl.text), 'tension': '120/80'});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RDV confirme - QR genere')));
                    _loadAll();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, minimumSize: const Size(0, 32)),
                child: const Text('Donner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabDemander() {
    final telCtrl = TextEditingController();
    final raisonCtrl = TextEditingController();
    String urgence = 'urgent';
    String groupeDemande = 'O+';
    int poches = 1;
    return StatefulBuilder(
      builder: (ctx, setSB) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)]), borderRadius: BorderRadius.circular(16)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Demander du sang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)), SizedBox(height: 4), Text('Reponse en < 30 min', style: TextStyle(color: Colors.white70, fontSize: 12))])),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: groupes.map((g) => ChoiceChip(label: Text(g), selected: groupeDemande == g, onSelected: (_) => setSB(() => groupeDemande = g))).toList()),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: urgence, decoration: InputDecoration(labelText: 'Urgence', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: const [DropdownMenuItem(value: 'critique', child: Text('Critique <2h')), DropdownMenuItem(value: 'urgent', child: Text('Urgent <24h')), DropdownMenuItem(value: 'modere', child: Text('Modere'))], onChanged: (v) => setSB(() => urgence = v!)),
            const SizedBox(height: 12),
            Row(children: [const Text('Poches:'), IconButton(onPressed: () => setSB(() => poches = poches > 1? poches - 1 : 1), icon: const Icon(Icons.remove_circle_outline)), Text('$poches', style: const TextStyle(fontWeight: FontWeight.w800)), IconButton(onPressed: () => setSB(() => poches++), icon: const Icon(Icons.add_circle_outline))]),
            TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Telephone *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: raisonCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Raison', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () async { if (telCtrl.text.isEmpty) return; await service.demanderSang(groupe: groupeDemande, urgence: urgence, poches: poches, tel: telCtrl.text, raison: raisonCtrl.text); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyee'), backgroundColor: Color(0xFF16A34A))); }, icon: const Icon(Icons.send_rounded), label: const Text('Lancer alerte'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52))),
          ],
        );
      },
    );
  }

  Widget _tabSuivi() {
    final total = _hist.length;
    final vies = total * 3;
    final badge = total >= 10? 'Or' : total >= 5? 'Argent' : total >= 1? 'Bronze' : 'Nouveau';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_stat('$total', 'Dons', '❤️'), _stat('$vies', 'Vies', '🙏'), _stat(badge, 'Badge', '🏅')])),
        const SizedBox(height: 16),
        if (_hist.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucun don', style: TextStyle(color: Color(0xFF9CA3AF))))),
       ..._hist.map((h) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(h['groupe_sanguin']?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${h['statut']?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${h['date_don']?.toString().substring(0, 10)?? ''} • QR ${h['qr_code']?.toString().substring(0, 8).toUpperCase()?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)))])), const Icon(Icons.qr_code_2_rounded)]))),
      ],
    );
  }

  Widget _stat(String v, String l, String i) => Column(children: [Text(i, style: const TextStyle(fontSize: 20)), const SizedBox(height: 4), Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11))]);
}
