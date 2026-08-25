// lib/presentation/home/widgets/home_search.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart'; 
import 'package:thix_id/core/theme/thix_design_policy.dart';

class HomeSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onVerify;

  const HomeSearch({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, // Hauteur réduite (était 56)
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: Colors.white, // Blanc pur
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), 
            blurRadius: 8, 
            offset: const Offset(0, 3)
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: ThixPolicy.textSecondary),
          const SizedBox(width: 8),
          
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSearching,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                color: ThixPolicy.textMain, // Texte très sombre (Slate 900)
                fontSize: 12.5, 
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                hintText: 'Saisir un THIX ID ou Scanner...',
                hintStyle: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // 🌟 BOUTON 1 : Scanner QR Code (Style Propre)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/scanner_activation'); 
            },
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft, // Gris très clair
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThixPolicy.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.textMain, size: 15),
            ),
          ),
          
          const SizedBox(width: 6),
          
          // 🌟 BOUTON 2 : Vérifier (Accentué)
          GestureDetector(
            onTap: isSearching ? null : () {
              HapticFeedback.lightImpact();
              onVerify();
            },
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: ThixPolicy.tint, // Fond bleu très léger
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThixPolicy.primary.withOpacity(0.1)),
              ),
              alignment: Alignment.center,
              child: isSearching
                  ? const SizedBox(
                      width: 13, 
                      height: 13, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)
                    )
                  : const Icon(Icons.person_search_rounded, color: ThixPolicy.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
