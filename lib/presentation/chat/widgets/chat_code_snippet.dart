import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

class ChatCodeSnippet extends StatelessWidget {
  final String code;
  final String language;

  const ChatCodeSnippet({
    super.key,
    required this.code,
    this.language = 'text',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _C.searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _C.primaryLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.primary.withOpacity(0.15))),
                  child: Text(
                    language.toUpperCase(),
                    style: const TextStyle(color: _C.primary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié !', style: TextStyle(fontSize: 12)), backgroundColor: _C.textMain, duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Row(children: [Icon(Icons.copy_rounded, color: _C.textMuted, size: 14), SizedBox(width: 4), Text('Copier', style: TextStyle(fontSize: 11, color: _C.textMuted, fontWeight: FontWeight.w600))]),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code,
              language: language == 'text' ? 'plaintext' : language,
              theme: githubTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4, color: _C.textMain),
            ),
          ),
        ],
      ),
    );
  }
}
