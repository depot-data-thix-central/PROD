import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

const _kGold = Color(0xFFFFB800);
const _kDark = Color(0xFF101840);
const _kBorder = Color(0xFFECEEF4);

class AdminArticleFormPage extends StatefulWidget {
  final String? articleId;
  const AdminArticleFormPage({super.key, this.articleId});
  @override State<AdminArticleFormPage> createState() => _AdminArticleFormPageState();
}

class _AdminArticleFormPageState extends State<AdminArticleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _content = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  String _category = 'politique';
  bool _isFeatured = false, _isBreaking = false;
  String? _imageUrl; String? _videoUrl;
  XFile? _pickedImage; XFile? _pickedVideo;
  Uint8List? _imgBytes; Uint8List? _vidBytes;
  bool _loading = false;
  NewsArticle? _edit;
  final cats = ['politique','economie','societe','tech','sport','culture','international'];

  @override void initState(){super.initState(); if(widget.articleId!=null)_load();}
  Future<void> _load() async {
    final a=await context.read<NewsProvider>().fetchArticleById(widget.articleId!);
    if(a!=null&&mounted){
      setState((){
        _edit=a; _title.text=a.title; _summary.text=a.summary??''; _content.text=a.content;
        _category=a.category; _isFeatured=a.isFeatured; _isBreaking=a.isBreaking;
        _imageUrl=a.imageUrl; _videoUrl=a.videoUrl; _videoUrlCtrl.text=a.videoUrl??'';
      });
    }
  }

  Future<void> _pickImage() async {
    final f=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:75);
    if(f!=null){
      final bytes = await f.readAsBytes();
      setState(()=>{ _pickedImage=f, _imgBytes=bytes });
    }
  }

  Future<void> _pickVideo() async {
    final f=await ImagePicker().pickVideo(source:ImageSource.gallery);
    if(f!=null){
      final bytes = await f.readAsBytes();
      setState(()=>{ _pickedVideo=f, _vidBytes=bytes });
    }
  }

  Future<void> _save() async {
    if(!_formKey.currentState!.validate()) return;
    setState(()=>_loading=true);
    final prov=context.read<NewsProvider>();
    try{
      String? finalImg=_imageUrl;
      String? finalVideo=_videoUrlCtrl.text.trim().isNotEmpty ? _videoUrlCtrl.text.trim() : _videoUrl;

      // FIX WEB : upload en bytes
      if(_imgBytes!=null && _pickedImage!=null){
        finalImg = await prov.uploadImageBytes(_imgBytes!, _pickedImage!.name);
      }
      if(_vidBytes!=null && _pickedVideo!=null){
        finalVideo = await prov.uploadVideoBytes(_vidBytes!, _pickedVideo!.name);
      }

      if(finalImg==null && _pickedImage!=null){ throw Exception('Upload image échoué - vérifie bucket news public'); }

      if(_edit==null){
        await prov.createArticle(title:_title.text.trim(),summary:_summary.text.trim(),content:_content.text.trim(),category:_category,imageUrl:finalImg,videoUrl:finalVideo,isFeatured:_isFeatured,isBreaking:_isBreaking);
      } else {
        await prov.updateArticle(_edit!.id,{'title':_title.text.trim(),'summary':_summary.text.trim(),'content':_content.text.trim(),'category':_category,'image_url':finalImg,'video_url':finalVideo,'is_featured':_isFeatured,'is_breaking':_isBreaking,'is_published':true});
      }
      await prov.fetchArticles(category:'all');
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('✅ Publié avec succès'))); context.go('/admin/articles'); }
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Erreur: $e'),backgroundColor:Colors.red, duration: const Duration(seconds:5)));
    }finally{ if(mounted) setState(()=>_loading=false); }
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title:Text(_edit==null?'Nouvel Article':'Modifier',style:const TextStyle(fontWeight:FontWeight.w800)),backgroundColor:_kDark,foregroundColor:Colors.white),
      body: Form(key:_formKey, child: ListView(padding:const EdgeInsets.all(14), children:[
        TextFormField(controller:_title,decoration:_d('Titre *'),validator:(v)=>v==null||v.isEmpty?'Requis':null),
        const SizedBox(height:10),
        DropdownButtonFormField(value:_category,items:cats.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>setState(()=>_category=v!),decoration:_d('Catégorie')),
        const SizedBox(height:10),
        TextFormField(controller:_summary,maxLines:2,decoration:_d('Résumé *'),validator:(v)=>v==null||v.isEmpty?'Requis':null),
        const SizedBox(height:10),
        TextFormField(controller:_content,maxLines:6,decoration:_d('Contenu *'),validator:(v)=>v==null||v.length<20?'Min 20':null),

        const SizedBox(height:16),
        const Text('PHOTO - PREVIEW',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1)), const SizedBox(height:6),
        Container(
          height:180,
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:_kBorder)),
          clipBehavior:Clip.antiAlias,
          child: Stack(children:[
            Positioned.fill(child: _imgBytes!=null ? Image.memory(_imgBytes!,fit:BoxFit.cover) : _imageUrl!=null && _imageUrl!.isNotEmpty ? Image.network(_imageUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))) : const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.add_a_photo,size:28,color:Colors.grey),SizedBox(height:6),Text('Aucune photo',style:TextStyle(fontSize:12,color:Colors.grey))]))),
            Positioned(bottom:8,right:8,child:ElevatedButton.icon(onPressed:_pickImage,icon:const Icon(Icons.photo,size:16),label:Text(_imgBytes!=null||_imageUrl!=null?'Changer':'Choisir',style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800)),style:ElevatedButton.styleFrom(backgroundColor:_kGold,foregroundColor:Colors.black,minimumSize:const Size(0,32)))),
          ]),
        ),
        if(_imgBytes!=null) Padding(padding:const EdgeInsets.only(top:6),child:Text('Preview: ${_pickedImage!.name} • ${(_imgBytes!.length/1024).toStringAsFixed(0)} KB',style:const TextStyle(fontSize:10,color:Colors.green))),

        const SizedBox(height:16),
        const Text('VIDÉO',style:TextStyle(fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1)), const SizedBox(height:6),
        Container(
          height:100,
          decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(12),border:Border.all(color:_kBorder)),
          clipBehavior:Clip.antiAlias,
          child: Stack(alignment:Alignment.center,children:[
            Center(child: _vidBytes!=null ? Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.check_circle,color:Colors.green,size:28),const SizedBox(height:4),Text('${_pickedVideo!.name}',style:const TextStyle(color:Colors.white,fontSize:10),maxLines:1,overflow:TextOverflow.ellipsis),Text('${(_vidBytes!.length/1024/1024).toStringAsFixed(1)} MB prêt',style:const TextStyle(color:Colors.white54,fontSize:9))]) : _videoUrl!=null&&_videoUrl!.isNotEmpty ? const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.play_circle_fill,size:36,color:Colors.white70),Text('Vidéo existante',style:TextStyle(color:Colors.white70,fontSize:10))]) : const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.videocam_off,size:24,color:Colors.white38),Text('Aucune vidéo',style:TextStyle(color:Colors.white38,fontSize:11))])),
            Positioned(bottom:8,left:8,right:8,child:Row(children:[Expanded(child:ElevatedButton.icon(onPressed:_pickVideo,icon:const Icon(Icons.video_library,size:16),label:const Text('Choisir vidéo',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800)),style:ElevatedButton.styleFrom(backgroundColor:Colors.white,foregroundColor:_kDark,minimumSize:const Size(0,34))))])),
          ]),
        ),
        const SizedBox(height:8),
        TextFormField(controller:_videoUrlCtrl,decoration:_d('Ou coller lien YouTube / MP4 (optionnel)'),style:const TextStyle(fontSize:12)),

        const SizedBox(height:14),
        SwitchListTile(value:_isFeatured,onChanged:(v)=>setState(()=>_isFeatured=v),title:const Text('À la une',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),activeColor:_kGold,dense:true,contentPadding:EdgeInsets.zero),
        SwitchListTile(value:_isBreaking,onChanged:(v)=>setState(()=>_isBreaking=v),title:const Text('Breaking News',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),activeColor:Colors.red,dense:true,contentPadding:EdgeInsets.zero),

        const SizedBox(height:12),
        SizedBox(height:50,child:ElevatedButton(onPressed:_loading?null:_save,style:ElevatedButton.styleFrom(backgroundColor:_kGold,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:_loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black)):Text(_edit==null?'PUBLIER MAINTENANT':'METTRE À JOUR',style:const TextStyle(fontWeight:FontWeight.w900)))),
        const SizedBox(height:20),
      ])),
    );
  }
  InputDecoration _d(String l)=>InputDecoration(labelText:l,isDense:true,filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:_kBorder)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:_kBorder)));
}
