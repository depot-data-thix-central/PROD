import 'package:flutter/material.dart';
class EduImage extends StatelessWidget {
  final String? url; final double? width, height; final BoxFit fit; final BorderRadius? radius;
  const EduImage({super.key, this.url, this.width, this.height, this.fit = BoxFit.cover, this.radius});
  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(width: width, height: height, decoration: BoxDecoration(color: const Color(0xFFEFF5FF), borderRadius: radius), child: const Icon(Icons.image_rounded, color: Color(0xFF7386A8)));
    }
    final optimized = url!.contains('supabase')? '$url?width=${width?.toInt()?? 400}&quality=75' : url!;
    Widget img = Image.network(optimized, width: width, height: height, fit: fit, cacheWidth: (width?? 400).toInt(),
      loadingBuilder: (_, c, p) => p == null? c : Container(color: const Color(0xFFEFF5FF)),
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFF5FF), child: const Icon(Icons.broken_image_rounded)),
    );
    return radius!= null? ClipRRect(borderRadius: radius!, child: img) : img;
  }
}
