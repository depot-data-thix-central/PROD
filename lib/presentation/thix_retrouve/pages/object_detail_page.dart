import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ObjectDetailPage extends StatelessWidget {
  final String title;
  final String status;
  final String location;
  final String time;
  final String description;
  final String reward;
  final String? imageUrl; // ← AJOUTÉ

  const ObjectDetailPage({
    super.key,
    this.title = 'Sac à dos noir',
    this.status = 'PERDU',
    this.location = 'THIX Center, Kiswahili',
    this.time = "Aujourd'hui, 14h",
    this.description = 'Grand sac à dos noir avec 2 poches latérales et un logo blanc.',
    this.reward = '20 000 FC',
    this.imageUrl, // ← AJOUTÉ
  });

  @override
  Widget build(BuildContext context) {
    final isLost = status == 'PERDU';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Détail de l'objet",
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 240,
                    color: Colors.grey.shade100,
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 240,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isLost ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              title,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              '$status • $time',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isLost ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              location,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 20),

            // Récompense
            if (reward.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Text(
                      'Récompense',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      reward,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Boutons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {},
                child: Text(
                  'Contacter le propriétaire',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {},
                child: Text(
                  'Partager',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
