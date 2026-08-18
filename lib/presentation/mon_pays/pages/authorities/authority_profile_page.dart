// lib/presentation/mon_pays/pages/authorities/authority_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/authorities_provider.dart';
import '../../models/authority.dart';

class AuthorityProfilePage extends HookConsumerWidget {
  final String authorityId;
  
  const AuthorityProfilePage({required this.authorityId, super.key});

  // ─── Charte Graphique Institutionnelle ────────────────────────────
  static const Color primaryBlue = Color(0xFF0052A5);
  static const Color gold = Color(0xFFF7C948);
  static const Color rdcRed = Color(0xFFCE1126);
  static const Color lightBg = Color(0xFFF4F7FB);
  static const Color darkText = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF5A6B87);
  static const Color hairline = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorityAsync = ref.watch(authorityDetailProvider(authorityId));
    final scrollController = useScrollController();
    final isScrolled = useState(false);

    useEffect(() {
      void listener() {
        final scrolled = scrollController.offset > 200;
        if (isScrolled.value != scrolled) {
          isScrolled.value = scrolled;
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    return Scaffold(
      backgroundColor: lightBg,
      body: authorityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: primaryBlue)),
        error: (error, _) => _buildErrorState(context, ref, error),
        data: (authority) => CustomScrollView(
          controller: scrollController,
          slivers: [
            _buildSliverAppBar(context, authority, isScrolled.value),
            SliverToBoxAdapter(
              child: _buildProfileContent(context, authority),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Gestion des erreurs ──────────────────────────────────────────
  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: rdcRed, size: 56),
            const SizedBox(height: 16),
            const Text('Profil indisponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkText)),
            const SizedBox(height: 8),
            Text('Impossible de charger les informations. Vérifiez votre connexion.', textAlign: TextAlign.center, style: TextStyle(color: mutedText)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(authorityDetailProvider(authorityId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── En-tête (SliverAppBar Institutionnelle) ──────────────────────
  Widget _buildSliverAppBar(BuildContext context, Authority authority, bool isScrolled) {
    final bgImage = authority.coverImageUrl ?? authority.imageUrl;
    
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: primaryBlue,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: AnimatedOpacity(
        opacity: isScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(authority.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.all(20),
        title: AnimatedOpacity(
          opacity: isScrolled ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (authority.imageUrl != null) ...[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    // Utilisation de NetworkImage native, avec un fallback anti-crash
                    backgroundImage: NetworkImage(authority.imageUrl!),
                    onBackgroundImageError: (_, __) {}, 
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authority.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: gold, letterSpacing: 1.2, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authority.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (bgImage != null && bgImage.isNotEmpty)
              Image.network(
                bgImage,
                fit: BoxFit.cover,
                // Gestion native du chargement pour éviter les sauts visuels
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: primaryBlue);
                },
                // Fallback web-safe en cas d'erreur réseau ou CORS
                errorBuilder: (_, __, ___) => _buildFallbackHeader(),
              )
            else
              _buildFallbackHeader(),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.1), primaryBlue.withOpacity(0.95)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackHeader() => Container(
    color: primaryBlue,
    child: const Center(child: Icon(Icons.account_balance, size: 100, color: Colors.white12)),
  );

  // ─── Contenu Principal ────────────────────────────────────────────
  Widget _buildProfileContent(BuildContext context, Authority authority) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadges(authority),
          const SizedBox(height: 32),
          
          if (authority.biography.isNotEmpty) ...[
            _buildSectionTitle(Icons.history_edu_rounded, 'Biographie'),
            _buildTextCard(authority.biography),
            const SizedBox(height: 32),
          ],
          
          if (authority.education.isNotEmpty) ...[
            _buildSectionTitle(Icons.school_rounded, 'Études & Formations'),
            ...authority.education.map((edu) => _buildTimelineCard(
              title: edu.degree, subtitle: edu.institution,
              dateRange: '${edu.startYear ?? ''} - ${edu.endYear ?? 'Présent'}'.trim(), icon: Icons.school_outlined,
            )),
            const SizedBox(height: 32),
          ],
          
          if (authority.career.isNotEmpty) ...[
            _buildSectionTitle(Icons.work_rounded, 'Parcours Professionnel'),
            ...authority.career.map((career) => _buildTimelineCard(
              title: career.title, subtitle: career.organization,
              dateRange: '${career.startDate} - ${career.endDate ?? 'Présent'}'.trim(), icon: Icons.business_center_outlined,
            )),
            const SizedBox(height: 32),
          ],
          
          if (authority.achievements.isNotEmpty) ...[
            _buildSectionTitle(Icons.emoji_events_rounded, 'Réalisations'),
            ...authority.achievements.map((ach) => _buildAchievementCard(ach)),
            const SizedBox(height: 32),
          ],
          
          if (authority.photos.isNotEmpty) ...[
            _buildSectionTitle(Icons.photo_library_rounded, 'Galerie Photos'),
            _buildPhotoGallery(context, authority.photos),
            const SizedBox(height: 32),
          ],
          
          if (authority.videos.isNotEmpty) ...[
            _buildSectionTitle(Icons.video_library_rounded, 'Vidéos Officielles'),
            ...authority.videos.map((video) => _buildVideoCard(context, video)),
            const SizedBox(height: 32),
          ],
          
          if (authority.documents.isNotEmpty) ...[
            _buildSectionTitle(Icons.folder_rounded, 'Documents Publics'),
            ...authority.documents.map((doc) => _buildDocumentCard(context, doc)),
            const SizedBox(height: 48),
          ],
        ],
      ),
    );
  }

  // ─── Composants de Détail ─────────────────────────────────────────

  Widget _buildBadges(Authority authority) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        _buildBadgeItem(Icons.account_balance_rounded, authority.category ?? 'Non défini', primaryBlue),
        if (authority.party.isNotEmpty) _buildBadgeItem(Icons.people_alt_rounded, authority.party, const Color(0xFF1A5276)),
        if (authority.mandate.isNotEmpty) _buildBadgeItem(Icons.calendar_today_rounded, authority.mandate, Colors.orange.shade700),
        if (!authority.isCurrentlyActive) _buildBadgeItem(Icons.history_rounded, 'Mandat terminé', rdcRed),
      ],
    );
  }

  Widget _buildBadgeItem(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: gold.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: darkText))),
        ],
      ),
    );
  }

  Widget _buildTextCard(String text) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: hairline),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, color: darkText, height: 1.6, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTimelineCard({required String title, required String subtitle, required String dateRange, required IconData icon}) {
    final hasDate = dateRange.isNotEmpty && dateRange != '-' && dateRange != ' - Présent';
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: lightBg, shape: BoxShape.circle, border: Border.all(color: hairline)),
            child: Icon(icon, color: primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: darkText)), const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryBlue)),
                if (hasDate) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 12, color: mutedText), const SizedBox(width: 6),
                      Text(dateRange, style: const TextStyle(fontSize: 12, color: mutedText, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: hairline),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (achievement.imageUrl != null && achievement.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              // Remplacement Web-Safe
              child: Image.network(
                achievement.imageUrl!,
                height: 180, width: double.infinity, fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null ? child : Container(height: 180, color: lightBg),
                errorBuilder: (_, __, ___) => Container(height: 180, color: lightBg, child: const Icon(Icons.broken_image, color: mutedText)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (achievement.category != null && achievement.category!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(achievement.category!.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: primaryBlue, letterSpacing: 0.5)),
                      ),
                    const Spacer(),
                    if (achievement.date != null && achievement.date!.isNotEmpty)
                      Text(achievement.date!, style: const TextStyle(fontSize: 12, color: mutedText, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: darkText)),
                if (achievement.description != null && achievement.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(achievement.description!, style: const TextStyle(fontSize: 13, color: mutedText, height: 1.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Galerie & Médias ─────────────────────────────────────────────

  Widget _buildPhotoGallery(BuildContext context, List<AuthorityPhoto> photos) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => _showFullScreenPhoto(context, photo.url, photo.title),
            child: Container(
              width: 140,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Remplacement Web-Safe
                    Image.network(
                      photo.url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: lightBg),
                      errorBuilder: (_, __, ___) => Container(color: lightBg, child: const Icon(Icons.broken_image, color: mutedText)),
                    ),
                    if (photo.title != null && photo.title!.isNotEmpty)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent])),
                          child: Text(photo.title!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext context, String url, String? title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              // Remplacement Web-Safe
              child: Image.network(
                url, fit: BoxFit.contain, height: double.infinity, width: double.infinity,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64)),
              ),
            ),
            Positioned(
              top: 50, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (title != null && title.isNotEmpty)
              Positioned(
                bottom: 40, left: 20, right: 20,
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, AuthorityVideo video) {
    return GestureDetector(
      onTap: () => _launchUrl(context, video.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // L'image en arrière-plan remplace le DecorationImage pour pouvoir capter les erreurs
              if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
                Image.network(
                  video.thumbnailUrl!,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: rdcRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
                  ),
                  child: Text(video.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, AuthorityDocument doc) {
    return InkWell(
      onTap: () => _launchUrl(context, doc.url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: rdcRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_rounded, color: rdcRed, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: darkText))),
            const Icon(Icons.download_rounded, color: primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Utilitaire URL ───────────────────────────────────────────────

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossible d\'ouvrir le lien');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur: Lien invalide ou indisponible.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: rdcRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
