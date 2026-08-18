import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/network_story.dart';
import 'features/network/presentation/providers/stories_provider.dart';

class StoriesList extends ConsumerWidget {
  final Function(NetworkStory)? onStoryTap;
  final VoidCallback? onCreateStory;
  const StoriesList({super.key, this.onStoryTap, this.onCreateStory});

  String _remaining(DateTime exp){
    final d = exp.difference(DateTime.now());
    if(d.isNegative) return 'expirée';
    if(d.inHours>0) return '${d.inHours}h';
    return '${d.inMinutes}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(activeStoriesProvider);

    return async.when(
      loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e,_ ) => Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [Icon(Icons.error_outline, color: Colors.red, size: 18), SizedBox(width: 8), Expanded(child: Text('Erreur: $e', style: TextStyle(fontSize: 12, color: Colors.red))), TextButton(onPressed: ()=> ref.invalidate(activeStoriesProvider), child: Text('Réessayer'))])),
      data: (stories){
        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_,__)=> SizedBox(width: 12),
            itemCount: stories.length + 1, // toujours +1 pour le bouton add
            itemBuilder: (context, index){
              if(index==0) return _addButton(context);
              final s = stories[index-1];
              return _item(context, s);
            },
          ),
        );
      },
    );
  }

  Widget _addButton(BuildContext context){
    return GestureDetector(onTap: onCreateStory, child: Column(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2), color: Colors.white), child: Icon(Icons.add, size: 28, color: Color(0xFF2B5CFF))),
      SizedBox(height: 4),
      Text('Ma Story', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    ]));
  }

  Widget _item(BuildContext context, NetworkStory s){
    final isViewed = s.isViewed?? false;
    final hasAvatar = s.userAvatar!=null && s.userAvatar!.isNotEmpty;
    return GestureDetector(
      onTap: ()=> onStoryTap?.call(s),
      child: Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: isViewed? null : LinearGradient(colors: [Color(0xFF2B5CFF), Colors.purple]), border: isViewed? Border.all(color: Colors.grey.shade300, width: 2): null),
          child: Padding(padding: EdgeInsets.all(2), child: CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade200, child: ClipOval(child: hasAvatar? Image.network(s.userAvatar!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Text(s.userName.isNotEmpty? s.userName[0].toUpperCase():'?')) : Text(s.userName.isNotEmpty? s.userName[0].toUpperCase():'?')))),
        ),
        SizedBox(height: 4),
        SizedBox(width: 60, child: Text(s.userName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
        Text(_remaining(s.expiresAt), style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
      ]),
    );
  }
}
