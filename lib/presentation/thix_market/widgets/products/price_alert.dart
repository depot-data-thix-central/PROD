import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/market_colors.dart';
import '../providers/market_providers.dart';

class PriceAlert extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;
  final double currentPrice;
  final String? currency;

  const PriceAlert({
    super.key,
    required this.productId,
    required this.productTitle,
    required this.currentPrice,
    this.currency,
  });

  @override ConsumerState<PriceAlert> createState() => _PriceAlertState();
}

class _PriceAlertState extends ConsumerState<PriceAlert> {
  final TextEditingController _targetCtrl = TextEditingController();
  bool _isLoading = false;
  bool _hasAlert = false;
  Map<String,dynamic>? _existing;

  @override void initState() { super.initState(); Future.microtask(_checkExisting); }
  @override void dispose() { _targetCtrl.dispose(); super.dispose(); }

  Future<void> _checkExisting() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null) return;
    try{
      final res = await db.from('price_alerts').select().match({'user_id':uid,'product_id':widget.productId,'is_active':true}).maybeSingle();
      if(res!=null && mounted){
        setState((){
          _existing=res;
          _hasAlert=true;
          _targetCtrl.text=(res['target_price'] as num).toString();
        });
      }
    }catch(e){ debugPrint('checkAlert $e'); }
  }

  Future<void> _create() async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null){ _showLogin(); return; }

    final target = double.tryParse(_targetCtrl.text);
    if(target==null || target<=0){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un prix valide')));
      return;
    }
    if(target >= widget.currentPrice){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le prix cible doit être inférieur au prix actuel'), backgroundColor: MarketColors.red));
      return;
    }
    setState(()=> _isLoading=true);
    try{
      await db.from('price_alerts').insert({
        'user_id':uid,
        'product_id':widget.productId,
        'product_title':widget.productTitle,
        'current_price':widget.currentPrice,
        'target_price':target,
        'is_active':true,
      });
      if(mounted){
        setState((){ _hasAlert=true; _isLoading=false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerte de prix créée'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    }catch(e){
      debugPrint('createAlert $e');
      if(mounted) setState(()=> _isLoading=false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la création')));
    }
  }

  Future<void> _delete() async {
    if(_existing==null) return;
    setState(()=> _isLoading=true);
    try{
      final db = ref.read(supabaseClientProvider);
      await db.from('price_alerts').update({'is_active':false}).eq('id', _existing!['id']);
      if(mounted){
        setState((){ _hasAlert=false; _existing=null; _targetCtrl.clear(); _isLoading=false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerte supprimée'), backgroundColor: Colors.grey));
        Navigator.pop(context);
      }
    }catch(e){
      debugPrint('deleteAlert $e');
      if(mounted) setState(()=> _isLoading=false);
    }
  }

  void _showLogin(){
    showDialog(context: context, builder: (_)=> AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Connexion requise', style: TextStyle(color: MarketColors.darkText)),
      content: const Text('Connectez-vous pour créer une alerte de prix'),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: MarketColors.mutedText))),
        ElevatedButton(onPressed: (){ Navigator.pop(context); context.push('/login'); }, style: ElevatedButton.styleFrom(backgroundColor: MarketColors.red, foregroundColor: Colors.white), child: const Text('Se connecter')),
      ],
    ));
  }

  String _formatDate(String? s){
    if(s==null) return '';
    try{
      final d=DateTime.parse(s);
      return '${d.day}/${d.month}/${d.year} à ${d.hour}h${d.minute.toString().padLeft(2,'0')}';
    }catch(_){ return s; }
  }

  @override Widget build(BuildContext context){
    return GestureDetector(
      onTap: _showDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:12,vertical:6),
        decoration: BoxDecoration(
          color: _hasAlert? Colors.green.withValues(alpha:0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hasAlert? Colors.green : Colors.grey.shade300, width:1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_active_rounded, size:16, color: _hasAlert? Colors.green : MarketColors.mutedText),
          const SizedBox(width:4),
          Text(_hasAlert? 'Alerte active' : 'Alerte prix', style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: _hasAlert? Colors.green : MarketColors.mutedText)),
        ]),
      ),
    );
  }

  void _showDialog(){
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if(uid==null){ _showLogin(); return; }
    final symbol = widget.currency=='USD'? '\$' : 'FC';

    showDialog(
      context: context,
      builder: (ctx)=> AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_hasAlert? 'Gérer l\'alerte' : 'Créer une alerte de prix', style: const TextStyle(color: MarketColors.darkText, fontWeight: FontWeight.bold, fontSize:18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Produit: ${widget.productTitle}', style: const TextStyle(fontWeight: FontWeight.w600, color: MarketColors.darkText)),
          const SizedBox(height:4),
          Text('Prix actuel: ${widget.currentPrice.toInt()} $symbol', style: const TextStyle(color: MarketColors.mutedText, fontSize:13)),
          const SizedBox(height:16),
          if(!_hasAlert)...[
            const Text('Recevez une notif quand le prix descend en dessous de :', style: TextStyle(fontSize:13, color: MarketColors.darkText)),
            const SizedBox(height:8),
            TextField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText:'Prix cible',
                suffixText:symbol,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MarketColors.red, width:2)),
              ),
            ),
          ] else ...[
            _info('Prix cible','${_existing?['target_price']} $symbol'),
            const SizedBox(height:6),
            _info('Créée le', _formatDate(_existing?['created_at'])),
          ],
        ]),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: MarketColors.mutedText))),
          if(_hasAlert) TextButton(onPressed: (){ Navigator.pop(ctx); _delete(); }, style: TextButton.styleFrom(foregroundColor: MarketColors.red), child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600))),
          if(!_hasAlert) ElevatedButton(
            onPressed: _isLoading? null : _create,
            style: ElevatedButton.styleFrom(backgroundColor: MarketColors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal:24,vertical:12)),
            child: _isLoading? const SizedBox(width:20,height:20, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white)) : const Text('Créer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value){
    return Row(children: [Text(label, style: const TextStyle(fontSize:13, color: MarketColors.mutedText)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize:13, color: MarketColors.darkText))]);
  }
}
