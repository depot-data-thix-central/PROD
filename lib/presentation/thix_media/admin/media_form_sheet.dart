import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/media_content.dart';
import '../../../services/media_service.dart';
import 'upload_progress.dart';

// Provider upload scalable
final mediaFormUploadProvider = StateNotifierProvider.autoDispose<MediaUploadNotifier, MediaUploadState>((ref)=> MediaUploadNotifier(ref));

class MediaUploadState {
  final bool saving;
  final double progress; // 0-1
  final String status;
  final String? error;
  const MediaUploadState({this.saving=false, this.progress=0, this.status='', this.error});
  MediaUploadState copyWith({bool? saving, double? progress, String? status, String? error})=> MediaUploadState(saving: saving??this.saving, progress: progress??this.progress, status: status??this.status, error: error);
}

class MediaUploadNotifier extends StateNotifier<MediaUploadState> {
  MediaUploadNotifier(this.ref): super(const MediaUploadState());
  final Ref ref;

  Future<void> save({
    required MediaContent base,
    PlatformFile? coverFile,
    PlatformFile? videoFile,
    required bool isNew,
    required VoidCallback onSaved,
  }) async {
    state = state.copyWith(saving: true, progress: 0, status: 'Préparation...', error: null);
    try{
      final service = MediaService(client: Supabase.instance.client, bucket: 'media');

      state = state.copyWith(status: 'Upload en cours...', progress: 0.2);

      if(isNew){
        await service.insertWithFiles(base, coverFile: coverFile, videoFile: videoFile, onProgress: (p){
          state = state.copyWith(progress: 0.2 + p*0.7, status: 'Upload ${(p*100).toInt()}%');
        });
      }else{
        await service.updateWithFiles(base, newCoverFile: coverFile, newVideoFile: videoFile, onProgress: (p){
          state = state.copyWith(progress: 0.2 + p*0.7, status: 'Mise à jour ${(p*100).toInt()}%');
        });
      }

      state = state.copyWith(progress: 1, status: 'Finalisation...');
      onSaved();
    }catch(e){
      state = state.copyWith(error: e.toString(), status: 'Erreur');
      rethrow;
    }finally{
      state = state.copyWith(saving: false);
    }
  }
}

class MediaFormSheet extends ConsumerStatefulWidget {
  final MediaContent? existing;
  final VoidCallback onSaved;
  const MediaFormSheet({super.key, this.existing, required this.onSaved});
  @override ConsumerState<MediaFormSheet> createState() => _MediaFormSheetState();
}

class _MediaFormSheetState extends ConsumerState<MediaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title, _subtitle, _year;
  String _type = 'Films';
  bool _isPublished = true, _isNew = true, _isTrending = false, _isFeedOnly = false;
  int _rank = 1;
  PlatformFile? _coverFile, _videoFile;

  @override void initState(){
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title??'');
    _subtitle = TextEditingController(text: e?.subtitle??'');
    _year = TextEditingController(text: e?.year?? DateTime.now().year.toString());
    _type = e?.type??'Films';
    _isPublished = e?.isPublished??true;
    _isNew = e?.isNewRelease??true;
    _isTrending = e?.rankPosition!=null;
    _rank = e?.rankPosition??1;
    
    // Si vous avez ajouté isFeedOnly dans le modèle, vous pouvez faire : _isFeedOnly = e?.isFeedOnly ?? false;
    // Pour l'instant, initialisé à false par défaut.
  }

  @override void dispose(){ _title.dispose(); _subtitle.dispose(); _year.dispose(); super.dispose(); }

  Future<void> _pickCover() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image, 
        withData: true,
      );
      
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'image est trop lourde pour ce navigateur.'), backgroundColor: Colors.red));
          }
          return;
        }
        setState(() => _coverFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur mémoire : Fichier trop volumineux. Compressez l\'image.'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video, 
        withData: true, 
      );
      
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La vidéo est trop lourde pour ce navigateur.'), backgroundColor: Colors.red));
          }
          return;
        }
        setState(() => _videoFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mémoire saturée : Vidéo trop lourde pour un navigateur mobile.'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
      }
    }
  }

  Future<void> _save() async {
    if(!_formKey.currentState!.validate()) return;
    
    final baseItem = MediaContent(
      id: widget.existing?.id??'',
      title: _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      type: _type,
      year: _year.text.trim(),
      coverUrl: widget.existing?.coverUrl??'',
      videoUrl: widget.existing?.videoUrl??'',
      viewCount: widget.existing?.viewCount??0,
      rankPosition: _isTrending? _rank : null,
      isTrending: _isTrending,
      isNewRelease: _isNew,
      isRecommended: !_isFeedOnly, // Si exclusif au fil, on le retire des recommandations classiques
      isPublished: _isPublished,
      // isFeedOnly: _isFeedOnly, // ⚠️ Décommentez ceci une fois que vous avez ajouté le paramètre dans media_content.dart
      createdAt: widget.existing?.createdAt?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try{
      await ref.read(mediaFormUploadProvider.notifier).save(
        base: baseItem,
        coverFile: _coverFile,
        videoFile: _videoFile,
        isNew: widget.existing==null,
        onSaved: widget.onSaved,
      );
      if(mounted) Navigator.pop(context);
    }catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context){
    final upload = ref.watch(mediaFormUploadProvider);
    return Container(
      height: MediaQuery.of(context).size.height*0.94,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      padding: EdgeInsets.fromLTRB(18,10,18,MediaQuery.of(context).viewInsets.bottom+18),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFE7EEFC), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(widget.existing==null? 'Nouvelle vidéo' : 'Modifier', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0A1F44))),
            if(_isTrending) DropdownButton<int>(value: _rank, items: List.generate(10, (i)=> DropdownMenuItem(value: i+1, child: Text('Top ${i+1}'))), onChanged: (v)=> setState(()=> _rank=v??1)),
          ]),
          const SizedBox(height: 14),
          if(upload.saving)...[
            UploadProgress(progress: upload.progress, status: upload.status),
            const SizedBox(height: 14),
          ],
          if(upload.error!=null) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Text(upload.error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12))),
          
          Row(children: [
            Expanded(child: InkWell(onTap: upload.saving? null : _pickCover, child: Container(height: 110, decoration: BoxDecoration(color: const Color(0xFFF7FAFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: _coverFile!=null? Colors.green : const Color(0xFFE7EEFC), width: _coverFile!=null? 2:1)), child: _coverFile!=null? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle_rounded, color: Colors.green), const SizedBox(height: 4), Text('${(_coverFile!.size/1024/1024).toStringAsFixed(1)} Mo', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]) : widget.existing!=null && widget.existing!.coverUrl.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(widget.existing!.coverUrl, fit: BoxFit.cover, width: double.infinity)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_rounded, color: Color(0xFF2D6CDF)), SizedBox(height: 4), Text('Cover (Optionnel)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])))),
            const SizedBox(width: 12),
            Expanded(child: InkWell(onTap: upload.saving? null : _pickVideo, child: Container(height: 110, decoration: BoxDecoration(color: const Color(0xFFF7FAFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: _videoFile!=null? Colors.green : const Color(0xFFE7EEFC), width: _videoFile!=null? 2:1)), child: _videoFile!=null? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle_rounded, color: Colors.green), const SizedBox(height: 4), Text('${(_videoFile!.size/1024/1024).toStringAsFixed(1)} Mo', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))])) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_library_rounded, color: Color(0xFF2D6CDF)), SizedBox(height: 4), Text('Vidéo (Optionnel)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])))),
          ]),
          
          const SizedBox(height: 16),
          TextFormField(controller: _title, validator: (v)=> v==null||v.trim().isEmpty? 'Titre requis' : v.trim().length<3? 'Min 3 caractères' : null, decoration: _dec('Titre *'), textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 12),
          TextFormField(controller: _subtitle, maxLength: 120, decoration: _dec('Sous-titre')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField(value: _type, items: ['Films','Séries','Vidéos','Musique','En direct','Playlists'].map((e)=> DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=> setState(()=> _type=v!), decoration: _dec('Type'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _year, keyboardType: TextInputType.number, validator: (v){ final y=int.tryParse(v??''); if(y==null|| y<1900|| y>2035) return 'Année invalide'; return null; }, decoration: _dec('Année'))),
          ]),
          const SizedBox(height: 8),

          // --- OPTIONS DE PUBLICATION INTELLIGENTES ---
          SwitchListTile(
            value: _isPublished, 
            title: const Text('Publié (Visible pour les utilisateurs)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), 
            activeColor: const Color(0xFF2D6CDF), 
            contentPadding: EdgeInsets.zero,
            onChanged: (v)=> setState(()=> _isPublished=v)
          ),
          
          SwitchListTile(
            value: _isFeedOnly, 
            title: const Text('Uniquement dans le Fil (TikTok Style)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0A1F44))), 
            subtitle: const Text('Masquera ce contenu des carrousels de l\'accueil', style: TextStyle(fontSize: 11, color: Colors.grey)),
            activeColor: const Color(0xFF10B981), // Vert pour différencier
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              setState(() {
                _isFeedOnly = v;
                // Logique intelligente : Si exclusif au fil, on désactive les banners/top10
                if(v) {
                  _isNew = false;
                  _isTrending = false;
                }
              });
            }
          ),

          SwitchListTile(
            value: _isNew, 
            title: Text('Nouveauté (Banner Accueil)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _isFeedOnly ? Colors.grey : Colors.black)), 
            activeColor: const Color(0xFF2D6CDF), 
            contentPadding: EdgeInsets.zero,
            // Désactivé si "Uniquement dans le fil" est coché
            onChanged: _isFeedOnly ? null : (v)=> setState(()=> _isNew=v)
          ),
          
          SwitchListTile(
            value: _isTrending, 
            title: Text('Tendance Top 10', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _isFeedOnly ? Colors.grey : Colors.black)), 
            activeColor: const Color(0xFF2D6CDF), 
            contentPadding: EdgeInsets.zero,
            // Désactivé si "Uniquement dans le fil" est coché
            onChanged: _isFeedOnly ? null : (v)=> setState(()=> _isTrending=v)
          ),
          
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: upload.saving? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A1F44), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            child: upload.saving? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white, value: upload.progress>0? upload.progress : null)) : Text(widget.existing==null? 'Créer le média' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.w800)),
          )),
        ]))),
    );
  }

  InputDecoration _dec(String label)=> InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF7FAFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D6CDF), width: 1.5)));
}
