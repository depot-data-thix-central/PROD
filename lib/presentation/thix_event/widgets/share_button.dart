import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/event_model.dart';

class _ThixColors {
  static const surface = Color(0xFF0C0C12);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class ShareButton extends StatelessWidget {
  final Event event;
  final bool isIconOnly;
  final double size;
  const ShareButton({super.key, required this.event, this.isIconOnly = true, this.size = 18});

  @override
  Widget build(BuildContext context) {
    if (isIconOnly) {
      return InkWell(
        onTap: () => _share(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)),
          child: Icon(Icons.share_rounded, size: size, color: _ThixColors.textSecondary),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _share(context),
      icon: Icon(Icons.share_rounded, size: size, color: Colors.white.withOpacity(0.9)),
      label: const Text('Partager', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _ThixColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        side: const BorderSide(color: _ThixColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final msg = '''
${event.title}

${event.formattedDate}
${event.location}
${event.formattedPrice}

${event.description}

Reserve sur THIX EVENEMENT
''';
    await Share.share(msg);
  }
}
