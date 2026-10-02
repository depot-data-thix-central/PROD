import 'package:flutter/material.dart';
import '../../core/theme/thix_design_policy.dart';

class DocumentCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String docId;
  final String subtitle;
  final bool isPublic;
  final Future<String>? previewUrlFuture;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final VoidCallback? onShowQr;
  final VoidCallback? onShowId;

  const DocumentCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.docId,
    required this.subtitle,
    required this.isPublic,
    this.previewUrlFuture,
    this.onTap,
    this.onMore,
    this.onShowQr,
    this.onShowId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onMore,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview()),
                  if (isPublic)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThixPolicy.gold,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: ThixPolicy.gold.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'PUBLIC',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: ThixPolicy.textMain,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ThixPolicy.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onMore,
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: ThixPolicy.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                      onTap: onShowQr,
                      child: Center(
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: ThixPolicy.primary,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: ThixPolicy.border,
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10),
                      ),
                      onTap: onShowId,
                      child: Center(
                        child: Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: ThixPolicy.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (previewUrlFuture == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accentColor.withOpacity(0.08),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: accentColor, size: 40),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FutureBuilder<String>(
        future: previewUrlFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done ||
              !snap.hasData ||
              snap.data!.isEmpty) {
            return Container(
              color: accentColor.withOpacity(0.08),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 40),
            );
          }
          return Image.network(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: accentColor.withOpacity(0.08),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 40),
            ),
          );
        },
      ),
    );
  }
}
