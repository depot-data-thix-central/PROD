import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});
  static const gold = Color(0xFFFFB800);
  static const dark = Color(0xFF101840);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NewsProvider>();
    final total = p.articles.length;
    final featured = p.articles.where((a) => a.isFeatured).length;
    final breaking = p.articles.where((a) => a.isBreaking).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: const Text('THIX ADMIN - OUVERT', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: dark,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              _stat('Total', '$total', Icons.article),
              const SizedBox(width: 12),
              _stat('À la une', '$featured', Icons.star),
              const SizedBox(width: 12),
              _stat('Breaking', '$breaking', Icons.bolt),
            ]),
            const SizedBox(height: 24),
            _btn(context, '＋ Nouvel Article', gold, () => context.push('/admin/articles/new'), Colors.black),
            const SizedBox(height: 12),
            _btn(context, 'Gérer les Articles', dark, () => context.push('/admin/articles'), Colors.white),
            const SizedBox(height: 12),
            _btn(context, 'Retour THIX INFO', Colors.white, () => context.go('/thix-info'), dark, border: true),
          ],
        ),
      ),
    );
  }

  Widget _stat(String l, String v, IconData i) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECEEF4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(i, color: gold),
        const SizedBox(height: 8),
        Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    ),
  );

  Widget _btn(BuildContext c, String t, Color bg, VoidCallback tap, Color txt, {bool border = false}) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: tap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: txt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: border ? const BorderSide(color: Color(0xFFECEEF4)) : BorderSide.none),
      ),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}
