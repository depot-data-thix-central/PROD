// lib/presentation/home/widgets/home_search.dart
import 'package:flutter/material.dart';
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
      height: ThixPolicy.searchBarHeight, 
      padding: const EdgeInsets.only(left: ThixPolicy.s16, right: ThixPolicy.s6),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
          const SizedBox(width: ThixPolicy.s8),
          
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSearching,
              textAlignVertical: TextAlignVertical.center,
              style: ThixPolicy.bodyMediumStyle,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                // 🌟 NOUVEAU : Texte incluant les deux services
                hintText: 'Saisir un THIX ID ou Scanner...',
                hintStyle: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // 🌟 BOUTON 1 : Scanner QR Code (Parrainage)
          GestureDetector(
            onTap: () {
              // 🌟 CORRECTION DE LA ROUTE : Chemin direct vers le scanner
              context.push('/scanner_activation'); 
            },
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: ThixPolicy.surface,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.textMain, size: 18),
            ),
          ),
          
          const SizedBox(width: ThixPolicy.s8),
          
          // 🌟 BOUTON 2 : Vérifier (Même design que le QR Code)
          GestureDetector(
            onTap: isSearching ? null : onVerify,
            child: Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: ThixPolicy.surface,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border),
              ),
              alignment: Alignment.center,
              child: isSearching
                  ? const SizedBox(
                      width: 14, 
                      height: 14, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textMain)
                    )
                  : const Icon(Icons.person_search_rounded, color: ThixPolicy.textMain, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
