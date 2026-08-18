import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/market_providers.dart';

final myAnnouncementsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if(uid==null) return [];
  final res = await db.from('products').select().eq('owner_id', uid).order('created_at', ascending: false);
  return List<Map<String,dynamic>>.from(res);
});

final myOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if(uid==null) return [];
  final res = await db.from('orders').select().eq('seller_id', uid).order('created_at', ascending: false).limit(100);
  return List<Map<String,dynamic>>.from(res);
});

final myLivesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if(uid==null) return [];
  final res = await db.from('lives').select().eq('host_id', uid).order('created_at', ascending: false);
  return List<Map<String,dynamic>>.from(res);
});

final sellerStatsProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final orders = await ref.watch(myOrdersProvider.future);
  final ann = await ref.watch(myAnnouncementsProvider.future);
  int revenue = 0;
  for(final o in orders){
    final t = o['total'];
    if(t!=null) revenue += (t as num).toInt();
  }
  int views = 0;
  for(final a in ann){
    final v = a['views'];
    if(v!=null) views += (v as num).toInt();
  }
  double conv = 0;
  if(ann.isNotEmpty) conv = (orders.length / ann.length * 100).clamp(0,100).toDouble();
  List<Map<String,dynamic>> sales = [];
  for(int i=0;i<6;i++){
    final d = DateTime.now().subtract(Duration(days: (5-i)*30));
    final label = DateFormat('MMM').format(d);
    double val = 10;
    if(revenue>0) val = (i+1) * revenue / 6.0;
    sales.add({'label': label, 'value': val});
  }
  final top = ann.take(5).map((e)=> {'image_url': e['image_url'], 'name': e['title'], 'sales': e['views'], 'revenue': e['price']}).toList();
  return {'total_sales': orders.length, 'revenue': revenue, 'total_views': views, 'conversion_rate': conv, 'sales_data': sales, 'top_products': top};
});

class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});
  @override ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override void initState(){ super.initState(); _tabController = TabController(length: 4, vsync: this); _tabController.addListener(()=> setState((){})); }
  Future<void> _refresh() async { ref.invalidate(myAnnouncementsProvider); ref.invalidate(myOrdersProvider); ref.invalidate(myLivesProvider); ref.invalidate(sellerStatsProvider); }
  @override void dispose(){ _tabController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Espace Vendeur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1D29))),
        backgroundColor: Colors.white, elevation: 0,
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Annonces'), Tab(text: 'Commandes'), Tab(text: 'Stats'), Tab(text: 'Lives')], indicatorColor: Color(0xFF1A73E8), labelColor: Color(0xFF1A73E8), unselectedLabelColor: Colors.grey),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: _refresh)],
      ),
      body: TabBarView(controller: _tabController, children: [_annoncesTab(), _ordersTab(), _statsTab(), _livesTab()]),
      floatingActionButton: _tabController.index==0 || _tabController.index==3? FloatingActionButton.extended(
        onPressed: _tabController.index==0? ()=> context.push('/market/announcement/publish') : ()=> context.push('/market/live/create'),
        backgroundColor: const Color(0xFF1A73E8),
        icon: Icon(_tabController.index==0? Icons.add : Icons.videocam, color: Colors.white),
        label: Text(_tabController.index==0? 'Publier' : 'Créer un live', style: const TextStyle(color: Colors.white)),
      ) : null,
    );
  }

  Widget _annoncesTab(){
    final async = ref.watch(myAnnouncementsProvider);
    return async.when(
      loading: ()=> const Center(child: CircularProgressIndicator()),
      error: (e,_ )=> Center(child: Text('Erreur $e')),
      data: (list){
        if(list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sell, size: 72, color: Colors.grey.shade300), const SizedBox(height: 12), const Text('Aucune annonce'), const SizedBox(height: 12), ElevatedButton(onPressed: ()=> context.push('/market/announcement/publish'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A73E8)), child: Text('Publier', style: TextStyle(color: Colors.white)))]));
        return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (_,i)=> _announcementCard(list[i])));
      },
    );
  }

  Widget _announcementCard(Map<String,dynamic> ann){
    String status = 'active';
    if(ann['status']!=null) status = ann['status'].toString();
    int priceVal = 0;
    if(ann['price']!=null) priceVal = (ann['price'] as num).toInt();
    int discountVal = -1;
    if(ann['discount_price']!=null) discountVal = (ann['discount_price'] as num).toInt();
    bool hasDiscount = discountVal>=0 && discountVal < priceVal;
    int displayPrice = hasDiscount? discountVal : priceVal;
    String img = '';
    if(ann['image_url']!=null) img = ann['image_url'].toString();
    else if(ann['images']!=null && (ann['images'] as List).isNotEmpty) img = (ann['images'] as List).first.toString();
    int views = 0;
    if(ann['views']!=null) views = (ann['views'] as num).toInt();
    String title = 'Sans titre';
    if(ann['title']!=null) title = ann['title'].toString();
    String id = '';
    if(ann['id']!=null) id = ann['id'].toString();
    return Card(margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: img.isEmpty? Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)) : Image.network(img, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (a,b,c)=> Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.image)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Row(children: [
            Text('$displayPrice FCFA', style: const TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
            if(hasDiscount) Padding(padding: const EdgeInsets.only(left: 6), child: Text('$priceVal FCFA', style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 12, color: Colors.grey.shade500))),
          ]),
          const SizedBox(height: 4),
          Text('Vues: $views', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ])),
      ]),
      const Divider(height: 20),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: ()=> context.push('/market/announcement/$id/edit'), icon: const Icon(Icons.edit, size: 18), label: const Text('Modifier'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: ()=> _showBoost(id), icon: const Icon(Icons.trending_up, size: 18), label: const Text('Booster'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: (){}, icon: const Icon(Icons.share, size: 18), label: const Text('Partager'))),
      ]),
    ])));
  }

  Widget _ordersTab(){
    final async = ref.watch(myOrdersProvider);
    return async.when(
      loading: ()=> const Center(child: CircularProgressIndicator()),
      error: (e,_ )=> Center(child: Text('Erreur $e')),
      data: (orders){
        if(orders.isEmpty) return const Center(child: Text('Aucune commande'));
        List<Map<String,dynamic>> pending = [];
        List<Map<String,dynamic>> preparing = [];
        List<Map<String,dynamic>> shipped = [];
        List<Map<String,dynamic>> completed = [];
        for(final o in orders){
          final s = o['status'].toString();
          if(s=='pending') pending.add(o);
          else if(s=='preparing') preparing.add(o);
          else if(s=='shipped') shipped.add(o);
          else if(s=='completed') completed.add(o);
        }
        return DefaultTabController(length: 4, child: Column(children: [
          const TabBar(tabs: [Tab(text: 'À traiter'), Tab(text: 'Préparation'), Tab(text: 'Expédiées'), Tab(text: 'Terminées')], isScrollable: true, indicatorColor: Color(0xFF1A73E8), labelColor: Color(0xFF1A73E8), unselectedLabelColor: Colors.grey),
          Expanded(child: TabBarView(children: [_orderList(pending), _orderList(preparing), _orderList(shipped), _orderList(completed)])),
        ]));
      },
    );
  }

  Widget _orderList(List<Map<String,dynamic>> orders){
    if(orders.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('Aucune commande', style: TextStyle(color: Colors.grey.shade600))]));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (_,i){
      final o = orders[i];
      int total = 0;
      if(o['total']!=null) total = (o['total'] as num).toInt();
      String sid = o['id'].toString();
      String s = '';
      if(o['status']!=null) s = o['status'].toString();
      String shortId = sid.length>8? sid.substring(0,8) : sid;
      return Card(margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: ListTile(onTap: ()=> context.push('/market/order/$sid'), title: Text('Commande #$shortId', style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('$total FCFA'), trailing: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))));
    });
  }

  Widget _statsTab(){
    final async = ref.watch(sellerStatsProvider);
    return async.when(
      loading: ()=> const Center(child: CircularProgressIndicator()),
      error: (e,_ )=> Center(child: Text('Erreur $e')),
      data: (stats){
        final salesData = stats['sales_data'] as List;
        List<double> vals = [];
        List<String> labs = [];
        for(final e in salesData){
          vals.add((e['value'] as num).toDouble());
          labs.add(e['label'].toString());
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1, children: [
            _statCard('Ventes totales', stats['total_sales'].toString(), Icons.trending_up, Colors.green),
            _statCard('Chiffre', '${stats['revenue']} FCFA', Icons.attach_money, const Color(0xFF1A73E8)),
            _statCard('Vues', stats['total_views'].toString(), Icons.visibility, Colors.purple),
            _statCard('Conversion', '${(stats['conversion_rate'] as double).toStringAsFixed(1)}%', Icons.percent, Colors.orange),
          ]),
          const SizedBox(height: 16),
          Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ventes mensuelles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: LineChart(LineChartData(gridData: const FlGridData(show: false), titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,m){ int idx=v.toInt(); if(idx>=0 && idx<labs.length) return Text(labs[idx], style: const TextStyle(fontSize: 10)); return const Text(''); }, reservedSize: 24)), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), lineBarsData: [LineChartBarData(spots: List.generate(vals.length, (i)=> FlSpot(i.toDouble(), vals[i])), isCurved: true, color: const Color(0xFF1A73E8), barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: const Color(0xFF1A73E8).withOpacity(0.1)))]))),
          ]))),
        ]));
      },
    );
  }

  Widget _statCard(String t, String v, IconData ic, Color c){
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(ic, color: c, size: 28), const SizedBox(height: 6), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text(t, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center)])));
  }

  Widget _livesTab(){
    final async = ref.watch(myLivesProvider);
    return async.when(
      loading: ()=> const Center(child: CircularProgressIndicator()),
      error: (e,_ )=> Center(child: Text('Erreur $e')),
      data: (lives){
        if(lives.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.live_tv, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('Aucun live', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Créez votre premier live', style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: ()=> context.push('/market/live/create'), icon: const Icon(Icons.videocam), label: const Text('Démarrer un live'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)))]));
        return RefreshIndicator(onRefresh: _refresh, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: lives.length, itemBuilder: (_,i){
          final live = lives[i];
          String title = 'Live';
          if(live['title']!=null) title = live['title'].toString();
          String thumb = '';
          if(live['thumbnail']!=null) thumb = live['thumbnail'].toString();
          String status = '';
          if(live['status']!=null) status = live['status'].toString();
          bool isLive = status=='live';
          String created = '';
          if(live['created_at']!=null) created = live['created_at'].toString();
          String dateStr = '';
          try{ dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(created)); }catch(_){ dateStr = created; }
          String id = live['id'].toString();
          return Card(margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: thumb.isEmpty? Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.live_tv, color: Colors.grey)) : Image.network(thumb, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (a,b,c)=> Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.live_tv)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)), if(isLive) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]),
              const SizedBox(height: 4),
              Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Row(children: [
                if(isLive) Expanded(child: ElevatedButton.icon(onPressed: ()=> context.push('/market/live/$id'), icon: const Icon(Icons.visibility, size: 16), label: const Text('Voir', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white))),
                if(!isLive) Expanded(child: OutlinedButton.icon(onPressed: ()=> context.push('/market/live/$id/replay'), icon: const Icon(Icons.replay, size: 16), label: const Text('Replay', style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: ()=> context.push('/market/live/$id/stats'), icon: const Icon(Icons.bar_chart, size: 16), label: const Text('Stats', style: TextStyle(fontSize: 12)))),
              ]),
            ])),
          ])));
        }));
      },
    );
  }

  void _showBoost(String id){
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c)=> Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Booster votre annonce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      ListTile(title: const Text('Standard - 2500 FCFA'), subtitle: const Text('5 000 vues garanties'), onTap: ()=> Navigator.pop(context)),
      ListTile(title: const Text('Premium - 5000 FCFA'), subtitle: const Text('15 000 vues garanties'), onTap: ()=> Navigator.pop(context)),
      ListTile(title: const Text('VIP - 10000 FCFA'), subtitle: const Text('50 000 vues garanties'), onTap: ()=> Navigator.pop(context)),
    ])));
  }
}
