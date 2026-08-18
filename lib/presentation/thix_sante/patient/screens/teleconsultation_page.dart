// lib/presentation/thix_sante/patient/screens/teleconsultation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/thix_sante_colors.dart';

class TeleconsultationPage extends ConsumerStatefulWidget {
  const TeleconsultationPage({super.key});
  @override ConsumerState<TeleconsultationPage> createState() => _TeleconsultationPageState();
}
class _TeleconsultationPageState extends ConsumerState<TeleconsultationPage> {
  bool micOn = true; bool camOn = true;
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=>Navigator.pop(context)), title: const Text('Téléconsultation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), actions: [Container(margin: const EdgeInsets.only(right:16), padding: const EdgeInsets.symmetric(horizontal:10, vertical:4), decoration: BoxDecoration(color: ThixSanteColors.danger, borderRadius: BorderRadius.circular(20)), child: const Text('● LIVE 12:34', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:12)))],),
      body: Stack(children: [
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircleAvatar(radius: 60, backgroundColor: Color(0xFF1F2937), child: Text('👨‍⚕️', style: TextStyle(fontSize:48))), const SizedBox(height:12), const Text('Dr. Médecin Traitant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:18)), Text('Connexion sécurisée E2E', style: TextStyle(color: Colors.white.withOpacity(0.6)))])),
        Positioned(top:16, right:16, child: Container(width:110, height:150, decoration: BoxDecoration(color: const Color(0xFF374151), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)), child: const Icon(Icons.person, color: Colors.white54, size:40))),
        Positioned(bottom:0, left:0, right:0, child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _btn(Icons.mic, micOn, ()=>setState(()=>micOn=!micOn)), const SizedBox(width:16),
            _btn(Icons.videocam, camOn, ()=>setState(()=>camOn=!camOn)), const SizedBox(width:16),
            _btn(Icons.chat_bubble, true, (){}), const SizedBox(width:16),
            _btn(Icons.call_end, true, ()=>Navigator.pop(context), bg: ThixSanteColors.danger),
          ]),
          const SizedBox(height:12),
          Row(children: [Expanded(child: ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.description), label: const Text('Partager dossier'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white))), const SizedBox(width:10), Expanded(child: ElevatedButton.icon(onPressed: (){}, icon: const Icon(Icons.local_pharmacy), label: const Text('Ordonnance'), style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary)))]),
        ]))),
      ]),
    );
  }
  Widget _btn(IconData i, bool on, VoidCallback tap, {Color? bg}) => InkWell(onTap: tap, child: CircleAvatar(radius: 26, backgroundColor: bg?? (on? Colors.white : Colors.white24), child: Icon(i, color: bg!=null? Colors.white : on? Colors.black : Colors.white)));
}
