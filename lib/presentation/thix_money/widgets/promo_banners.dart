// lib/presentation/thix_money/widgets/promo_banners.dart
import 'package:flutter/material.dart';

class PromoBanners extends StatelessWidget {
  const PromoBanners({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _Banner(color: const Color(0xFF0A2A8A), title: 'Besoin d\'argent?', subtitle: 'Jusqu\'à 5 000 000 FC', button: 'Demander', icon: '💰')),
          const SizedBox(width: 10),
          Expanded(child: _Banner(color: const Color(0xFFE8F5E9), title: 'Vous pouvez épargner 150 000 FC ce mois.', button: 'Voir plan', icon: '🤖', darkText: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Banner(color: const Color(0xFFF3E5F5), title: 'Cashback 10%', subtitle: 'Paiement chez partenaires', button: 'Utiliser', icon: '🎁', darkText: true)),
          const SizedBox(width: 10),
          Expanded(child: _Banner(color: const Color(0xFFFFF8E1), title: 'Envoyez de l\'argent partout', subtitle: '🌍 International', button: 'Envoyer', icon: '🌐', darkText: true)),
        ]),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color; final String title; final String? subtitle; final String button; final String icon; final bool darkText;
  const _Banner({required this.color, required this.title, this.subtitle, required this.button, required this.icon, this.darkText = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: darkText? Colors.black87 : Colors.white)),
        if (subtitle!= null) Text(subtitle!, style: TextStyle(fontSize: 10, color: darkText? Colors.black54 : Colors.white70)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: darkText? Colors.white : Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(button, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: darkText? Colors.black87 : Colors.white))),
      ]),
    );
  }
}
