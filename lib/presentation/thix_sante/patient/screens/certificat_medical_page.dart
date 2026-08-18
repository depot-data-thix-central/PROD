// lib/presentation/thix_sante/patient/screens/certificat_medical_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/thix_sante_colors.dart';
import 'package:pdf/pdf.dart';


class CertificatMedicalPage extends StatefulWidget {
  const CertificatMedicalPage({super.key});
  @override State<CertificatMedicalPage> createState() => _CertificatMedicalPageState();
}

class _CertificatMedicalPageState extends State<CertificatMedicalPage> {
  final _db = Supabase.instance.client;
  String _type = 'Aptitude physique';
  final _motifCtrl = TextEditingController(text: 'Aptitude sportive');
  bool _loading = false;
  List<Map<String,dynamic>> _history = [];

  @override
  void initState(){
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = _db.auth.currentUser?.id;
    if(uid==null) return;
    try{
      final res = await _db.from('certificats_medicaux').select('*').eq('patient_id', uid).order('created_at', ascending:false).limit(20);
      if(mounted) setState(()=> _history = List<Map<String,dynamic>>.from(res));
    }catch(_){}
  }

  Future<Uint8List> _buildPdf(String type, String motif, String patientNom) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    pdf.addPage(pw.Page(
      build: (c)=> pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start, children:[
        pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween, children:[
          pw.Text('THIX SANTE', style: pw.TextStyle(fontWeight:pw.FontWeight.bold, fontSize:18)),
          pw.Text('THIX ID: THIX-MED-001', style: const pw.TextStyle(fontSize:10)),
        ]),
        pw.SizedBox(height:20),
        pw.Center(child: pw.Text('CERTIFICAT MEDICAL', style: pw.TextStyle(fontWeight:pw.FontWeight.bold, fontSize:20))),
        pw.SizedBox(height:6),
        pw.Center(child: pw.Text(type.toUpperCase(), style: const pw.TextStyle(fontSize:12))),
        pw.SizedBox(height:30),
        pw.Text('Je soussigne Dr Medecin Traitant, certifie avoir examine ce jour :', style: const pw.TextStyle(fontSize:12)),
        pw.SizedBox(height:12),
        pw.Text('Patient : $patientNom', style: pw.TextStyle(fontWeight:pw.FontWeight.bold, fontSize:13)),
        pw.SizedBox(height:8),
        pw.Text('Motif : $motif', style: const pw.TextStyle(fontSize:12)),
        pw.SizedBox(height:20),
        pw.Text('Ne presente aucune contre-indication medicale cliniquement decelable a la pratique de l\'activite mentionnee.', style: const pw.TextStyle(fontSize:12, lineSpacing:2)),
        pw.SizedBox(height:40),
        pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween, children:[
          pw.Text('Fait a Dakar le ${now.day}/${now.month}/${now.year}', style: const pw.TextStyle(fontSize:11)),
          pw.Column(children:[
            pw.Text('Signature et Cachet', style: const pw.TextStyle(fontSize:11)),
            pw.SizedBox(height:30),
            pw.Text('Dr Traitant', style: pw.TextStyle(fontWeight:pw.FontWeight.bold)),
          ])
        ]),
        pw.Spacer(),
        pw.Divider(),
        pw.Text('Document genere via THIX SANTE - Verifiable par QR code THIX ID', style:  pw.TextStyle(fontSize:8, color: PdfColors.grey)),
      ])
    ));
    return pdf.save();
  }

  Future<void> _generer() async {
    final uid = _db.auth.currentUser?.id;
    if(uid==null) return;
    setState(()=>_loading=true);
    try{
      final profile = await _db.from('profiles').select('full_name').eq('id', uid).maybeSingle();
      final nom = profile?['full_name'] ?? 'Patient THIX';
      final bytes = await _buildPdf(_type, _motifCtrl.text.trim(), nom);

      // Upload storage
      final fileName = '${uid}/${DateTime.now().millisecondsSinceEpoch}.pdf';
      await _db.storage.from('thix-certificats').uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType:'application/pdf', upsert:true));

      // Save DB - utilise patient_id pas patient_uid
      await _db.from('certificats_medicaux').insert({
        'patient_id': uid,
        'type': _type,
        'motif': _motifCtrl.text.trim(),
        'file_path': fileName,
        'statut': 'delivre',
      });

      await _loadHistory();
      if(mounted){
        await Printing.sharePdf(bytes: bytes, filename: 'certificat_$_type.pdf');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Certificat genere et sauvegarde')));
      }
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Erreur: $e')));
    }finally{ if(mounted) setState(()=>_loading=false); }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: ThixSanteColors.background,
      appBar: AppBar(backgroundColor:Colors.white, elevation:0, leading:IconButton(icon:const Icon(Icons.arrow_back_rounded,color:Color(0xFF0F172A)),onPressed:()=>Navigator.pop(context)), title:const Text('Certificat medical',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:Color(0xFF0F172A)))),
      body: ListView(padding:const EdgeInsets.all(16), children:[
        Container(padding:const EdgeInsets.all(16), decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE2E8F0))), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          const Text('Type de certificat',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:_type, decoration:InputDecoration(filled:true,fillColor:const Color(0xFFF8FAFC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none)), items:const[
            DropdownMenuItem(value:'Aptitude physique',child:Text('Aptitude physique')),
            DropdownMenuItem(value:'Arret de travail',child:Text('Arret de travail')),
            DropdownMenuItem(value:'Absence scolaire',child:Text('Absence scolaire')),
            DropdownMenuItem(value:'Vaccination',child:Text('Vaccination')),
          ], onChanged:(v){if(v!=null) setState(()=>_type=v);}),
          const SizedBox(height:14),
          const Text('Motif / Description',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          const SizedBox(height:8),
          TextField(controller:_motifCtrl, maxLines:3, decoration:InputDecoration(hintText:'Ex: Aptitude a la pratique du football', filled:true,fillColor:const Color(0xFFF8FAFC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none))),
          const SizedBox(height:16),
          SizedBox(width:double.infinity, child:ElevatedButton.icon(onPressed:_loading?null: _generer, icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.picture_as_pdf_rounded), label:Text(_loading?'Generation...':'Generer le certificat'), style:ElevatedButton.styleFrom(backgroundColor:ThixSanteColors.primary,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),
        ])),
        const SizedBox(height:20),
        const Text('Mes certificats recents',style:TextStyle(fontWeight:FontWeight.w800,fontSize:14)),
        const SizedBox(height:10),
        if(_history.isEmpty) Container(padding:const EdgeInsets.all(20), decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE2E8F0))), child:const Center(child:Text('Aucun certificat',style:TextStyle(color:Color(0xFF64748B))))),
        ..._history.map((c)=> Container(margin:const EdgeInsets.only(bottom:10), padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE2E8F0))), child:Row(children:[
          Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFFDBEAFE),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.description_rounded,color:ThixSanteColors.primary)),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(c['type']??'Certificat',style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),Text('${c['motif']??''} • ${c['statut']??''}',style:const TextStyle(fontSize:11,color:Color(0xFF64748B)),maxLines:1,overflow:TextOverflow.ellipsis)])),
          IconButton(icon:const Icon(Icons.share_rounded,size:18), onPressed:() async {
            try{
              final bytes = await _db.storage.from('thix-certificats').download(c['file_path']);
              await Printing.sharePdf(bytes: bytes, filename: 'certificat.pdf');
            }catch(_){}
          })
        ]))),
      ]),
    );
  }
}
