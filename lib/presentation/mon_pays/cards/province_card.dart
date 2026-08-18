// ============================================================
// FICHIER 17 : cards/province_card.dart
// ============================================================
// lib/presentation/mon_pays/cards/province_card.dart

import 'package:flutter/material.dart';
import '../models/province.dart';

class ProvinceCard extends StatelessWidget {
  final Province province;
  final VoidCallback onTap;

  const ProvinceCard({required this.province, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Blason Web-Safe
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: province.coatOfArmsUrl != null && province.coatOfArmsUrl!.trim().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(province.coatOfArmsUrl!),
                          fit: BoxFit.contain,
                        )
                      : null,
                  color: Colors.grey.shade200,
                ),
                child: (province.coatOfArmsUrl == null || province.coatOfArmsUrl!.trim().isEmpty)
                    ? Center(
                        child: Text(
                          province.code.length >= 2
                              ? province.code.substring(0, 2).toUpperCase()
                              : province.code.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      province.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Capitale : ${province.capital}'),
                    Text('Région : ${province.region}'),
                    if (province.population != null)
                      Text('Population : ${province.population!.toString()}'),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
