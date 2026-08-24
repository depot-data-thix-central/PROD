// lib/presentation/home/widgets/home_search.dart
import 'dart:ui'; // ✅ NÉCESSAIRE POUR LE GLASSMORPHISM
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThixPolicy.rXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 52, // Légèrement ajusté pour un rendu plus premium
          padding: const EdgeInsets.only(left: ThixPolicy.s16, right: ThixPolicy.s8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65), // Verre dépoli
            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04), 
                blurRadius: 12, 
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
              const SizedBox(width: ThixPolicy.s12),
              
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSearching,
                  textAlignVertical: TextAlignVertical.center,
                  style: ThixPolicy.bodyMediumStyle.copyWith(color: ThixPolicy.textMain),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                    hintText: 'Saisir un THIX ID ou Scanner...',
                    hintStyle: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // 🌟 BOUTON 1 : Scanner QR Code (Glassmorphism)
              GestureDetector(
                onTap: () {
                  context.push('/scanner_activation'); 
                },
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.primaryDeep, size: 18),
                ),
              ),
              
              const SizedBox(width: ThixPolicy.s8),
              
              // 🌟 BOUTON 2 : Vérifier (Glassmorphism)
              GestureDetector(
                onTap: isSearching ? null : onVerify,
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: isSearching
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primaryDeep)
                        )
                      : const Icon(Icons.person_search_rounded, color: ThixPolicy.primaryDeep, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
