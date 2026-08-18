import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/shop_provider.dart';
import '../providers/market_providers.dart';

class CreateShopPage extends ConsumerStatefulWidget {
  const CreateShopPage({super.key});
  @override ConsumerState<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends ConsumerState<CreateShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  XFile? _logo;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if(file!=null) setState(()=> _logo=file);
  }

  Future<void> _submit() async {
    if(!_formKey.currentState!.validate()) return;
    setState(()=> _loading=true);
    try{
      final notifier = ref.read(currentShopProvider.notifier);
      final data = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };
      // Upload logo if web/mobile
      String? logoUrl;
      if(_logo!=null){
        final db = ref.read(supabaseClientProvider);
        final bytes = await _logo!.readAsBytes();
        final path = 'shop-logos/${DateTime.now().millisecondsSinceEpoch}_${_logo!.name}';
        await db.storage.from('shops').uploadBinary(path, bytes);
        logoUrl = db.storage.from('shops').getPublicUrl(path);
      }
      if(logoUrl!=null) data['logo_url']=logoUrl;

      await notifier.createShopFromMap(data);
      ref.invalidate(myShopsProvider);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boutique créée avec succès !'), backgroundColor: Colors.green));
        context.pop();
      }
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur ${e.toString()}'), backgroundColor: Colors.red));
    }finally{ if(mounted) setState(()=> _loading=false); }
  }

  @override void dispose(){
    _nameCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Créer une boutique', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1D29))), backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: ()=> context.pop())),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: GestureDetector(onTap: _pickImage, child: Container(
          height: 110, width: 110,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
          child: _logo==null? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey.shade600), const SizedBox(height: 6), Text('Logo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]) : ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_logo!.path, fit: BoxFit.cover, errorBuilder: (a,b,c)=> FutureBuilder(future: _logo!.readAsBytes(), builder: (c,s)=> s.hasData? Image.memory(s.data!, fit: BoxFit.cover) : const Icon(Icons.image)))),
        ))),
        const SizedBox(height: 20),
        TextFormField(controller: _nameCtrl, decoration: _input('Nom de la boutique *'), validator: (v)=> v!.trim().isEmpty? 'Requis' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _descCtrl, decoration: _input('Description'), maxLines: 3),
        const SizedBox(height: 12),
        TextFormField(controller: _addressCtrl, decoration: _input('Adresse')),
        const SizedBox(height: 12),
        TextFormField(controller: _phoneCtrl, decoration: _input('Téléphone'), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextFormField(controller: _emailCtrl, decoration: _input('Email'), keyboardType: TextInputType.emailAddress, validator: (v){ if(v!=null && v.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Email invalide'; return null; }),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _loading? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Créer la boutique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ])))),
    );
  }

  InputDecoration _input(String label)=> InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)));
}
