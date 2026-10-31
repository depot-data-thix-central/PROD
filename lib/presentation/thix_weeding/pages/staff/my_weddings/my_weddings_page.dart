// lib/presentation/thix_weeding/pages/staff/my_weddings/my_weddings_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — MY WEDDINGS (PRODUCTION)
// Design royal + Countdown live + Badge publication + Navigation corrigée
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color roseSoft = Color(0xFFFFE4EC);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 20}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MyWeddingsPage extends ConsumerWidget {
  const MyWeddingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const _AuthRequiredView();
    }

    final weddingsAsync = ref.watch(myWeddingsProvider(user.id));

    return Scaffold(
      backgroundColor: _R.cream,
      body: weddingsAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(myWeddingsProvider(user.id)),
        ),
        data: (weddings) => _MyWeddingsContent(
          userId: user.id,
          weddings: weddings,
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _MyWeddingsContent extends StatelessWidget {
  final String userId;
  final List<WeddingModel> weddings;

  const _MyWeddingsContent({required this.userId, required this.weddings});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ROYALE ────────────────────────────────────────────
        _MyWeddingsAppBar(weddingCount: weddings.length),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (weddings.isEmpty)
                _EmptyState()
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: () async =>
                      ref.read(myWeddingsProvider(userId).future).then((_) {}),
                  child: Column(
                    children: weddings
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _WeddingCard(wedding: w),
                            ))
                        .toList(),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _MyWeddingsAppBar extends StatelessWidget {
  final int weddingCount;

  const _MyWeddingsAppBar({required this.weddingCount});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
            ],
          ),
          child:
              const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/thix-weeding/create'),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.add_circle_outline,
                  color: _R.rose, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.roseG,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _R.gold.withOpacity(0.15),
                ),
              ),
            ),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.favorite,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MES MARIAGES',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gérez vos événements',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$weddingCount mariage${weddingCount > 1 ? 's' : ''} créé${weddingCount > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WEDDING CARD (avec countdown live)
// ============================================================================
class _WeddingCard extends ConsumerWidget {
  final WeddingModel wedding;

  const _WeddingCard({required this.wedding});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    gradient: _R.roseG, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Supprimer ce mariage ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Cette action est irréversible. Tous les invités, prestataires, budget et galerie seront supprimés.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _R.text,
                        side: const BorderSide(color: _R.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _R.rose,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(weddingServiceProvider).delete(wedding.id);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) ref.invalidate(myWeddingsProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child:
                    const Icon(Icons.check, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            const Text('Mariage supprimé ✓'),
          ]),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _R.rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = wedding.weddingDate != null
        ? wedding.weddingDate!.difference(DateTime.now()).inDays.clamp(0, 9999)
        : null;
    final isPublished = wedding.invitationPublished;
    final isPast =
        wedding.weddingDate != null && wedding.weddingDate!.isBefore(DateTime.now());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/${wedding.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPublished ? _R.green.withOpacity(0.3) : _R.border,
              width: isPublished ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar / Icône
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: isPast
                      ? LinearGradient(colors: [_R.text2.withOpacity(0.2), _R.text2.withOpacity(0.1)])
                      : _R.roseG,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    isPast ? Icons.celebration_outlined : Icons.favorite,
                    color: isPast ? _R.text2 : Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + badge publication
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            wedding.coupleNames.isEmpty
                                ? 'Mariage sans nom'
                                : wedding.coupleNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _R.text,
                            ),
                          ),
                        ),
                        if (isPublished)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: _R.greenG,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  'Publié',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _R.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _R.amber.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Brouillon',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _R.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Date + Lieu
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: _R.text2),
                        const SizedBox(width: 4),
                        Text(
                          wedding.weddingDate != null
                              ? _fmtDate(wedding.weddingDate!)
                              : 'Date à définir',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _R.text2),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined,
                            size: 12, color: _R.text2),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            wedding.venue ?? 'Lieu à définir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _R.text2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // ID badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _R.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID: ${wedding.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _R.blue,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        // J-X badge
                        if (daysLeft != null && !isPast)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: _R.roseG,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'J−$daysLeft',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Célébré badge
                        if (isPast)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: _R.greenG,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Célébré ✨',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Code unique
                        if (wedding.uniqueCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _R.gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _R.gold.withOpacity(0.3)),
                            ),
                            child: Text(
                              wedding.uniqueCode,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _R.goldDark,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouton aperçu invitation
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push(
                          '/thix-weeding/staff/${wedding.id}/invitation/preview'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _R.blue.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_outlined,
                            size: 18, color: _R.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: _R.text2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'edit') {
                        context.push(
                            '/thix-weeding/edit/${wedding.id}');
                      }
                      if (v == 'delete') _delete(context, ref);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined,
                              size: 18, color: _R.blue),
                          const SizedBox(width: 10),
                          Text('Modifier',
                              style: GoogleFonts.inter(fontSize: 13)),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: _R.rose),
                          const SizedBox(width: 10),
                          Text('Supprimer',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: _R.rose)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _R.rose.withOpacity(0.15),
                  _R.purple.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded,
                size: 48, color: _R.rose),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun mariage créé',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier mariage pour accéder à l\'espace staff complet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/create'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer mon mariage'),
            style: FilledButton.styleFrom(
              backgroundColor: _R.rose,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AUTH REQUIRED VIEW
// ============================================================================
class _AuthRequiredView extends StatelessWidget {
  const _AuthRequiredView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _R.blue.withOpacity(0.15),
                      _R.purple.withOpacity(0.1)
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 48, color: _R.blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Connexion requise',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour voir et gérer vos mariages',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/thix-weeding/auth/login'),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Se connecter'),
                style: FilledButton.styleFrom(
                  backgroundColor: _R.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  gradient: _R.roseG, shape: BoxShape.circle),
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement de vos mariages...',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _R.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
