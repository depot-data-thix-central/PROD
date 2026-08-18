// lib/presentation/thix_weeding/widgets/home/id_search_card_widget.dart
import 'package:flutter/material.dart';

class IdSearchCardWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const IdSearchCardWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSearch,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vous avez un ID de mariage?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('Accédez à tous les détails de l’événement', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Entrez votre ID de mariage',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isLoading? null : onSearch,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE25A6A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isLoading
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Rechercher'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OU', style: TextStyle(color: Colors.grey, fontSize: 12))), Expanded(child: Divider())]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: onScanQr, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scanner un QR Code'))),
        ],
      ),
    );
  }
}
