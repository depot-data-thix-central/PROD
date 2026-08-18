// lib/presentation/network/widgets/story_highlights.dart
import 'package:flutter/material.dart';
import 'package:thix_id/theme.dart';
import 'package:go_router/go_router.dart';

class Highlight {
  final String id;
  final String name;
  final String? coverImage;
  final List<String> storyIds;
  final DateTime createdAt;
  Highlight({required this.id, required this.name, this.coverImage, required this.storyIds, required this.createdAt});
}

class StoryHighlights extends StatelessWidget {
  final List<Highlight> highlights;
  final VoidCallback? onAddHighlight;
  final void Function(Highlight)? onHighlightTap;

  const StoryHighlights({super.key, required this.highlights, this.onAddHighlight, this.onHighlightTap});

  @override Widget build(BuildContext context) {
    if (highlights.isEmpty && onAddHighlight == null) return SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('📌 En vedette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ThixHomeColors.darkNavy))),
        SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: highlights.length + (onAddHighlight != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (onAddHighlight != null && index == 0) return _buildAddButton();
              final hi = highlights[onAddHighlight != null ? index - 1 : index];
              return _buildItem(context, hi);
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddHighlight,
      child: Container(width: 56, margin: EdgeInsets.only(right: 10), child: Column(children: [
        Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixHomeColors.primaryBlue, width: 2)), child: CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.add, size: 22, color: ThixHomeColors.primaryBlue))),
        SizedBox(height: 4),
        Text('Nouveau', style: TextStyle(fontSize: 9, color: ThixHomeColors.darkNavy)),
      ])),
    );
  }

  Widget _buildItem(BuildContext context, Highlight h) {
    return GestureDetector(
      onTap: () => onHighlightTap != null ? onHighlightTap!(h) : context.push('/network/highlight/${h.id}'),
      child: Container(width: 56, margin: EdgeInsets.only(right: 10), child: Column(children: [
        Stack(children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [ThixHomeColors.primaryBlue, ThixHomeColors.darkNavy]), border: Border.all(color: Colors.white, width: 2)),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: ClipOval(child: h.coverImage != null && h.coverImage!.isNotEmpty
                ? Image.network(h.coverImage!, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.star, size: 22, color: ThixHomeColors.primaryBlue))
                : Icon(Icons.star, size: 22, color: ThixHomeColors.primaryBlue)),
            ),
          ),
          Positioned(bottom: 0, right: 0, child: Container(padding: EdgeInsets.all(2), decoration: BoxDecoration(color: ThixHomeColors.primaryBlue, shape: BoxShape.circle), child: Icon(Icons.lock_clock, size: 10, color: Colors.white))),
        ]),
        SizedBox(height: 4),
        Text(h.name, style: TextStyle(fontSize: 9, color: ThixHomeColors.darkNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    );
  }
}
