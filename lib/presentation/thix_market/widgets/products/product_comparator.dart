import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/market_colors.dart';
import '../providers/market_providers.dart';

class ProductComparatorPage extends ConsumerStatefulWidget {
  final List<String>? initialProductIds;
  const ProductComparatorPage({super.key, this.initialProductIds});
  @override ConsumerState<ProductComparatorPage> createState() => _ProductComparatorPageState();
}

class _ProductComparatorPageState extends ConsumerState<ProductComparatorPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _productsToCompare = [];
  List<String> _productIdsToCompare = [];
  final int _max = 4;

  @override void initState() {
    super.initState();
    if (widget.initialProductIds!=null && widget.initialProductIds!.isNotEmpty) {
      _productIdsToCompare = widget.initialProductIds!.take(_max).toList();
      Future.microtask(_loadComparisonData);
    }
  }

  Future<void> _loadComparisonData() async {
    if (_productIdsToCompare.isEmpty) {
      setState(() { _productsToCompare = []; _isLoading = false; });
      return;
    }
    setState(()=> _isLoading=true);
    try {
      final db = ref.read(supabaseClientProvider);
      final response = await db.from('products').select('*, shop:shops(name)').inFilter('id', _productIdsToCompare);
      final list = List<Map<String, dynamic>>.from(response);
      // garder ordre sélection
      list.sort((a,b)=> _productIdsToCompare.indexOf(a['id']).compareTo(_productIdsToCompare.indexOf(b['id'])));
      if(mounted) setState(() { _productsToCompare=list; _isLoading=false; });
    } catch (e) {
      debugPrint('Comparator error $e');
      if(mounted) {
        setState(()=> _isLoading=false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur chargement comparateur'), backgroundColor: MarketColors.red));
      }
    }
  }

  void _removeProduct(String id) {
    setState(() {
      _productIdsToCompare.remove(id);
      _productsToCompare.removeWhere((p)=> p['id']==id);
    });
  }

  Future<void> _openSelector() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_)=> ProductSelector(excludeIds: _productIdsToCompare, maxSelect: _max - _productIdsToCompare.length)),
    );
    if(selected!=null && selected.isNotEmpty){
      setState(()=> _productIdsToCompare.addAll(selected));
      _loadComparisonData();
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.lightBg,
      appBar: AppBar(
        backgroundColor: MarketColors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: MarketColors.darkText),
        title: const Text('Comparateur B2B', style: TextStyle(color: MarketColors.darkText, fontWeight: FontWeight.w900, fontSize:18)),
        actions: [if(_productsToCompare.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: MarketColors.red), onPressed: ()=> setState((){ _productIdsToCompare.clear(); _productsToCompare.clear(); }))],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: MarketColors.cardBorder, height:1)),
      ),
      body: _isLoading? const Center(child: CircularProgressIndicator(color: MarketColors.red)) : _productsToCompare.isEmpty? _empty() : _table(),
    );
  }

  Widget _empty(){
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: MarketColors.creamBg, shape: BoxShape.circle), child: const Icon(Icons.compare_arrows_rounded, size:64, color: MarketColors.gold)),
          const SizedBox(height:24),
          const Text('Comparateur vide', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)),
          const SizedBox(height:8),
          const Text('Sélectionnez jusqu\'à 4 produits pour comparer leurs caractéristiques.', textAlign: TextAlign.center, style: TextStyle(fontSize:13, color: MarketColors.mutedText, height:1.4)),
          const SizedBox(height:32),
          ElevatedButton.icon(onPressed: _openSelector, icon: const Icon(Icons.add_rounded, color: Colors.white), label: const Text('Ajouter des produits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: MarketColors.red, padding: const EdgeInsets.symmetric(horizontal:24,vertical:16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation:0)),
        ]),
      ),
    );
  }

  Widget _table(){
    final features = [
      {'label':'Prix','key':'price'},
      {'label':'Marque','key':'brand'},
      {'label':'Stock','key':'stock'},
      {'label':'Garantie','key':'warranty'},
      {'label':'Boutique','key':'shop_name'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: MarketColors.white,
            padding: const EdgeInsets.symmetric(vertical:20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(width:100),
             ..._productsToCompare.map((p)=> _header(p)),
              if(_productsToCompare.length < _max) _addBtn(),
            ]),
          ),
          Container(height:1, color: MarketColors.cardBorder, width: 100 + 140.0 * (_productsToCompare.length + 1)),
         ...features.map((f)=> _featureRow(f)),
          const SizedBox(height:30),
        ]),
      ),
    );
  }

  Widget _header(Map<String,dynamic> product){
    final img = product['image_url'] as String?;
    return Container(
      width:140,
      padding: const EdgeInsets.symmetric(horizontal:8),
      child: Column(children: [
        Stack(alignment: Alignment.topRight, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height:120,
              color: MarketColors.lightBg,
              child: img==null || img.isEmpty
               ? const Icon(Icons.image_not_supported_outlined, color: MarketColors.mutedText)
                : Image.network(img, fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_,__,___)=> const Icon(Icons.broken_image_outlined)),
            ),
          ),
          GestureDetector(
            onTap: ()=> _removeProduct(product['id']),
            child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius:4)]), child: const Icon(Icons.close_rounded, size:14, color: MarketColors.red)),
          ),
        ]),
        const SizedBox(height:12),
        Text(product['title']?? 'Produit', textAlign: TextAlign.center, maxLines:2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize:12, fontWeight: FontWeight.w800, height:1.2)),
      ]),
    );
  }

  Widget _addBtn(){
    return Container(
      width:140,
      padding: const EdgeInsets.symmetric(horizontal:8),
      child: InkWell(
        onTap: _openSelector,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height:120,
          decoration: BoxDecoration(color: MarketColors.lightBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: MarketColors.cardBorder)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline_rounded, color: MarketColors.mutedText, size:32), SizedBox(height:8), Text('Ajouter', style: TextStyle(color: MarketColors.mutedText, fontSize:12, fontWeight: FontWeight.w600))]),
        ),
      ),
    );
  }

  Widget _featureRow(Map<String,String> feature){
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: MarketColors.cardBorder))),
      padding: const EdgeInsets.symmetric(vertical:16),
      child: Row(children: [
        SizedBox(width:100, child: Padding(padding: const EdgeInsets.only(left:16), child: Text(feature['label']!, style: const TextStyle(fontSize:12, fontWeight: FontWeight.w700, color: MarketColors.mutedText)))),
       ..._productsToCompare.map((product){
          final key = feature['key']!;
          String val = '';
          if(key=='price'){ val='${(product['price'] as num?)?.toInt()??0} ${product['currency']??'FC'}'; }
          else if(key=='shop_name'){ val=product['shop']?['name']?? product['shop_name']?? '-'; }
          else if(key=='stock'){ final s=int.tryParse(product['stock'].toString())??0; val=s>0? '$s dispo' : 'Épuisé'; }
          else { val=product[key]?.toString()?? '-'; }
          final isPrice = key=='price';
          final isOut = key=='stock' && val=='Épuisé';
          return SizedBox(width:140, child: Padding(padding: const EdgeInsets.symmetric(horizontal:8), child: Text(val, textAlign: TextAlign.center, maxLines:2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize:13, fontWeight: isPrice? FontWeight.w900 : FontWeight.w600, color: isPrice? MarketColors.red : (isOut? MarketColors.red : MarketColors.darkText)))));
        }),
        if(_productsToCompare.length < _max) const SizedBox(width:140),
      ]),
    );
  }
}

class ProductSelector extends ConsumerStatefulWidget {
  final List<String> excludeIds;
  final int maxSelect;
  const ProductSelector({super.key, required this.excludeIds, required this.maxSelect});
  @override ConsumerState<ProductSelector> createState()=> _ProductSelectorState();
}

class _ProductSelectorState extends ConsumerState<ProductSelector> {
  List<Map<String,dynamic>> _products=[];
  final List<String> _selected=[];
  bool _loading=true;
  String _query='';
  Timer? _debounce;

  @override void initState(){ super.initState(); _load(); }
  @override void dispose(){ _debounce?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(()=> _loading=true);
    try{
      final db = ref.read(supabaseClientProvider);
      var q = db.from('products').select('id,title,price,currency,image_url,shop:shops(name)').eq('status','active').limit(30);
      if(widget.excludeIds.isNotEmpty){ q = q.not('id','in', widget.excludeIds); }
      if(_query.isNotEmpty){ q = q.ilike('title', '%$_query%'); }
      final res = await q;
      if(mounted) setState((){ _products=List<Map<String,dynamic>>.from(res); _loading=false; });
    }catch(e){
      debugPrint('selector $e');
      if(mounted) setState(()=> _loading=false);
    }
  }

  void _onSearch(String v){
    _debounce?.cancel();
    _debounce=Timer(const Duration(milliseconds:400), (){
      _query=v;
      _load();
    });
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: MarketColors.lightBg,
      appBar: AppBar(
        backgroundColor: MarketColors.white,
        elevation:0,
        title: const Text('Ajouter au comparateur', style: TextStyle(color: MarketColors.darkText, fontWeight: FontWeight.w900, fontSize:16)),
        iconTheme: const IconThemeData(color: MarketColors.darkText),
        actions: [if(_selected.isNotEmpty) Padding(padding: const EdgeInsets.only(right:8), child: TextButton(onPressed: ()=> Navigator.pop(context, _selected), style: TextButton.styleFrom(backgroundColor: MarketColors.red.withValues(alpha:0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: Text('Ajouter (${_selected.length})', style: const TextStyle(color: MarketColors.red, fontWeight: FontWeight.w800))))],
      ),
      body: Column(children: [
        Container(
          color: MarketColors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText:'Rechercher un produit...',
              hintStyle: const TextStyle(color: MarketColors.mutedText, fontSize:14),
              prefixIcon: const Icon(Icons.search_rounded, color: MarketColors.mutedText),
              filled:true,
              fillColor: MarketColors.lightBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical:0),
            ),
          ),
        ),
        Expanded(
          child: _loading? const Center(child: CircularProgressIndicator(color: MarketColors.red))
          : _products.isEmpty? const Center(child: Text('Aucun produit trouvé', style: TextStyle(color: MarketColors.mutedText)))
          : ListView.separated(
              itemCount: _products.length,
              separatorBuilder: (_,__)=> const Divider(height:1, color: MarketColors.cardBorder),
              itemBuilder: (_,i){
                final p=_products[i];
                final isSel=_selected.contains(p['id']);
                final img=p['image_url'] as String?;
                return ListTile(
                  tileColor: MarketColors.white,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: img==null? Container(width:50,height:50,color: MarketColors.lightBg, child: const Icon(Icons.image_outlined)) : Image.network(img, width:50,height:50, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width:50,height:50,color: MarketColors.lightBg)),
                  ),
                  title: Text(p['title']??'', maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:14)),
                  subtitle: Text('${(p['price'] as num?)?.toInt()??0} ${p['currency']??'FC'}', style: const TextStyle(color: MarketColors.red, fontWeight: FontWeight.w800, fontSize:13)),
                  trailing: Checkbox(
                    value: isSel,
                    activeColor: MarketColors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (sel){
                      setState((){
                        if(sel==true && _selected.length < widget.maxSelect){ _selected.add(p['id']); }
                        else if(sel==false){ _selected.remove(p['id']); }
                        else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max ${widget.maxSelect} produits'), backgroundColor: MarketColors.gold)); }
                      });
                    },
                  ),
                  onTap: (){
                    setState((){
                      if(!isSel && _selected.length < widget.maxSelect) _selected.add(p['id']);
                      else if(isSel) _selected.remove(p['id']);
                    });
                  },
                );
              },
            ),
        ),
      ]),
    );
  }
}
