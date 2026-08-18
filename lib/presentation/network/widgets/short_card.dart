import 'package:flutter/material.dart';
import 'package:thix_id/models/network_post.dart';

class ShortCard extends StatelessWidget {
  final NetworkPost short;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  const ShortCard({super.key, required this.short, this.onTap, this.onLike});

  @override
  Widget build(BuildContext context) {
    final hasThumb = short.imageUrl.isNotEmpty;
    final thumb = short.imageUrl; // ou short.thumbnailUrl?? short.videoThumbnail

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 9/16,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              hasThumb
               ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(color: Colors.grey.shade900, child: Icon(Icons.play_circle, color: Colors.white54, size: 48)))
                : Container(color: Colors.grey.shade900, child: Center(child: Text(short.content.isNotEmpty? short.content : 'Short', style: TextStyle(color: Colors.white), maxLines: 3))),

              // Gradient bottom
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)])))),

              // Play icon
              Center(child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(Icons.play_arrow, color: Colors.white, size: 32))),

              // Infos bas
              Positioned(
                left: 10, right: 10, bottom: 10,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 12, backgroundColor: Colors.white24, backgroundImage: short.userAvatar!=null && short.userAvatar!.isNotEmpty? NetworkImage(short.userAvatar!) : null, child: short.userAvatar==null? Text(short.userName.isNotEmpty? short.userName[0]: '?', style: TextStyle(fontSize: 10)): null),
                    SizedBox(width: 6),
                    Expanded(child: Text(short.userName, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Icon(Icons.favorite, size: 14, color: Colors.white70),
                    SizedBox(width: 2),
                    Text('${short.likesCount}', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                  if(short.content.isNotEmpty)...[
                    SizedBox(height: 4),
                    Text(short.content, style: TextStyle(color: Colors.white, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
