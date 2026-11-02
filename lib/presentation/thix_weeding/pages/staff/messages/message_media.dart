// lib/presentation/thix_weeding/pages/staff/messages/message_media.dart
// ============================================================================
// THIX WEDDING — Médias des messages (photos), tags, visionneuse
// ============================================================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kChatBucket = 'thix-weeding-chat';
const int kMaxMessagePhotos = 4;

const List<String> kInfoTags = [
  'INFO',
  'PARKING',
  'DRESS CODE',
  'TRANSPORT',
  'PROGRAMME',
  'MENU',
  'URGENT',
];

Color tagColor(String t) {
  switch (t.toUpperCase()) {
    case 'URGENT':
      return const Color(0xFFE31C4E);
    case 'PARKING':
      return const Color(0xFF0B3B8F);
    case 'DRESS CODE':
      return const Color(0xFF6B46C1);
    case 'TRANSPORT':
      return const Color(0xFF059669);
    case 'PROGRAMME':
      return const Color(0xFFD97706);
    case 'MENU':
      return const Color(0xFFB8860B);
    default:
      return const Color(0xFF241521);
  }
}

List<String> parseImageUrls(dynamic v) {
  if (v is List) {
    return v.map((e) => '$e').where((e) => e.isNotEmpty && e != 'null').toList();
  }
  return const [];
}

class PickedPhoto {
  final Uint8List bytes;
  final String ext;
  const PickedPhoto(this.bytes, this.ext);
}

Future<List<PickedPhoto>> pickPhotos({int max = kMaxMessagePhotos}) async {
  if (max <= 0) return [];
  final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 82);
  final out = <PickedPhoto>[];
  for (final x in picked.take(max)) {
    final bytes = await x.readAsBytes();
    var ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
    out.add(PickedPhoto(bytes, ext));
  }
  return out;
}

String _mime(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

Future<List<String>> uploadPhotos(String weddingId, List<PickedPhoto> photos) async {
  final supa = Supabase.instance.client;
  final urls = <String>[];
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    final path = '$weddingId/${DateTime.now().millisecondsSinceEpoch}_$i.${p.ext}';
    await supa.storage.from(kChatBucket).uploadBinary(
          path,
          p.bytes,
          fileOptions: FileOptions(contentType: _mime(p.ext), upsert: false),
        );
    urls.add(supa.storage.from(kChatBucket).getPublicUrl(path));
  }
  return urls;
}

// ───────────────────────── Visionneuse plein écran ─────────────────────────
void showPhotoViewer(BuildContext context, List<String> urls, [int start = 0]) {
  if (urls.isEmpty) return;
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black.withOpacity(0.92),
    pageBuilder: (_, __, ___) => _PhotoViewer(urls: urls, start: start),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int start;
  const _PhotoViewer({required this.urls, required this.start});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _c = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _c,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 50),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Text(
                '${_i + 1} / ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Photos d'un message ─────────────────────────
class MessageImages extends StatelessWidget {
  final List<String> urls;
  final double radius;
  const MessageImages({super.key, required this.urls, this.radius = 14});

  Widget _img(BuildContext context, int i, {double? aspect}) {
    final child = Image.network(
      urls[i],
      fit: BoxFit.cover,
      loadingBuilder: (_, w, p) => p == null
          ? w
          : Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (_, __, ___) => Container(
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      ),
    );
    return GestureDetector(
      onTap: () => showPhotoViewer(context, urls, i),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: aspect == null ? child : AspectRatio(aspectRatio: aspect, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) return _img(context, 0, aspect: 4 / 3);
    return LayoutBuilder(builder: (context, c) {
      final w = ((c.maxWidth.isFinite ? c.maxWidth : 240) - 6) / 2;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(
          urls.length,
          (i) => SizedBox(width: w, height: w, child: _img(context, i)),
        ),
      );
    });
  }
}

// ───────────────────────── Aperçu des photos choisies ─────────────────────────
class PickedPhotoStrip extends StatelessWidget {
  final List<PickedPhoto> photos;
  final void Function(int) onRemove;
  const PickedPhotoStrip({super.key, required this.photos, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(photos[i].bytes, width: 66, height: 66, fit: BoxFit.cover),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Color(0xFFE31C4E), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
