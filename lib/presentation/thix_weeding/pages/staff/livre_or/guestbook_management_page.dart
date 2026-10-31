// lib/presentation/thix_weeding/pages/staff/livre_or/guestbook_management_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — LIVRE D'OR (PRODUCTION)
// Design royal + Modération + Stats live + ApproveAll + Animations
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
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
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class GuestbookManagementPage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestbookManagementPage({super.key, required this.weddingId});

  @override
  ConsumerState<GuestbookManagementPage> createState() =>
      _GuestbookManagementPageState();
}

class _GuestbookManagementPageState
    extends ConsumerState<GuestbookManagementPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  String _search = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _approveAll() async {
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
                  gradient: _R.greenG,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.done_all, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Approuver tous les messages ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Tous les messages en attente seront publiés dans le livre d\'or.',
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
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Tout approuver'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _R.green,
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
      await ref.read(guestbookServiceProvider).approveAll(widget.weddingId);
      ref.invalidate(guestbookProvider(widget.weddingId));
      if (mounted) _showSuccess('Tous les messages approuvés ✓');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _toggleApproval(GuestbookModel m) async {
    try {
      await ref
          .read(guestbookServiceProvider)
          .toggleApproval(m.id, !m.isApproved);
      ref.invalidate(guestbookProvider(widget.weddingId));
      if (mounted) {
        _showSuccess(m.isApproved ? 'Message masqué' : 'Message approuvé ✓');
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _deleteMessage(GuestbookModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _DeleteDialog(guestName: m.guestName),
    );
    if (ok != true) return;

    try {
      await ref.read(guestbookServiceProvider).delete(m.id);
      ref.invalidate(guestbookProvider(widget.weddingId));
      if (mounted) _showSuccess('Message supprimé ✓');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration:
                  const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final guestbookAsync = ref.watch(guestbookProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: guestbookAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(guestbookProvider(widget.weddingId)),
        ),
        data: (messages) => FadeTransition(
          opacity: _fadeAnim,
          child: _GuestbookContent(
            weddingId: widget.weddingId,
            messages: messages,
            filter: _filter,
            search: _search,
            onFilterChanged: (f) => setState(() => _filter = f),
            onSearchChanged: (s) => setState(() => _search = s),
            onToggle: _toggleApproval,
            onDelete: _deleteMessage,
            onApproveAll: _approveAll,
            onRefresh: () async =>
                ref.invalidate(guestbookProvider(widget.weddingId)),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _GuestbookContent extends StatelessWidget {
  final String weddingId;
  final List<GuestbookModel> messages;
  final String filter;
  final String search;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final Function(GuestbookModel) onToggle;
  final Function(GuestbookModel) onDelete;
  final VoidCallback onApproveAll;
  final Future<void> Function() onRefresh;

  const _GuestbookContent({
    required this.weddingId,
    required this.messages,
    required this.filter,
    required this.search,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onDelete,
    required this.onApproveAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final total = messages.length;
    final approved = messages.where((m) => m.isApproved).length;
    final pending = total - approved;

    final filtered = messages.where((m) {
      final matchFilter = switch (filter) {
        'approved' => m.isApproved,
        'pending' => !m.isApproved,
        _ => true,
      };
      final matchSearch = search.isEmpty ||
          m.guestName.toLowerCase().contains(search.toLowerCase()) ||
          m.message.toLowerCase().contains(search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList()
      ..sort((a, b) {
        // Non approuvés en premier pour modération rapide
        if (a.isApproved != b.isApproved) return a.isApproved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ───────────────────────────────────────────────────
        _GuestbookAppBar(
          total: total,
          approved: approved,
          pending: pending,
          onApproveAll: pending > 0 ? onApproveAll : null,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── STATS HERO ─────────────────────────────────────────
              _StatsHero(
                total: total,
                approved: approved,
                pending: pending,
              ),
              const SizedBox(height: 16),

              // ── SEARCH ─────────────────────────────────────────────
              _SearchField(value: search, onChanged: onSearchChanged),
              const SizedBox(height: 12),

              // ── FILTRES ────────────────────────────────────────────
              _FilterRow(
                filter: filter,
                onChanged: onFilterChanged,
                pendingCount: pending,
              ),
              const SizedBox(height: 16),

              // ── HEADER LISTE ───────────────────────────────────────
              _ListHeader(count: filtered.length, total: total, filter: filter),
              const SizedBox(height: 10),

              // ── LISTE / EMPTY ──────────────────────────────────────
              if (filtered.isEmpty)
                _EmptyState(filter: filter, search: search)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MessageCard(
                                message: m,
                                onToggle: () => onToggle(m),
                                onDelete: () => onDelete(m),
                              ),
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
class _GuestbookAppBar extends StatelessWidget {
  final int total;
  final int approved;
  final int pending;
  final VoidCallback? onApproveAll;

  const _GuestbookAppBar({
    required this.total,
    required this.approved,
    required this.pending,
    required this.onApproveAll,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
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
        if (onApproveAll != null)
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onApproveAll,
              child: Container(
                padding: const EdgeInsets.all(10),
                child:
                    const Icon(Icons.done_all, color: _R.green, size: 20),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {}, // Export futur
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.file_download_outlined,
                  color: _R.blue, size: 20),
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
                            child: const Icon(Icons.menu_book_outlined,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVRE D\'OR',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          if (pending > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pending_actions,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$pending en attente',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Messages des invités',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$total message${total > 1 ? 's' : ''} • $approved publié${approved > 1 ? 's' : ''}',
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
// STATS HERO
// ============================================================================
class _StatsHero extends StatelessWidget {
  final int total;
  final int approved;
  final int pending;

  const _StatsHero({
    required this.total,
    required this.approved,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? approved / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Text(
                '${(ratio * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _HeroStat(
                  icon: Icons.mail_outline,
                  label: 'Total',
                  value: '$total',
                ),
                const SizedBox(width: 12),
                _HeroStat(
                  icon: Icons.check_circle_outline,
                  label: 'Publiés',
                  value: '$approved',
                ),
                const SizedBox(width: 12),
                _HeroStat(
                  icon: Icons.hourglass_empty,
                  label: 'Attente',
                  value: '$pending',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEARCH FIELD
// ============================================================================
class _SearchField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: _R.text),
      decoration: InputDecoration(
        hintText: 'Rechercher un message ou un nom...',
        hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _R.blue, size: 20),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: _R.text2),
                onPressed: () => onChanged(''),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.blue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ============================================================================
// FILTER ROW
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;
  final int pendingCount;

  const _FilterRow({
    required this.filter,
    required this.onChanged,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Tous',
            icon: Icons.all_inbox,
            selected: filter == 'all',
            color: _R.blue,
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Publiés',
            icon: Icons.check_circle_outline,
            selected: filter == 'approved',
            color: _R.green,
            onTap: () => onChanged('approved'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'En attente',
            icon: Icons.hourglass_empty,
            selected: filter == 'pending',
            color: _R.amber,
            badge: pendingCount,
            onTap: () => onChanged('pending'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : _R.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// LIST HEADER
// ============================================================================
class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String filter;

  const _ListHeader({
    required this.count,
    required this.total,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'approved' => 'Messages publiés',
      'pending' => 'Messages en attente',
      _ => 'Tous les messages',
    };

    return Row(
      children: [
        Icon(Icons.format_quote, size: 16, color: _R.rose),
        const SizedBox(width: 6),
        Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _R.rose.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            filter == 'all' ? '$total' : '$count / $total',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _R.rose,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MESSAGE CARD
// ============================================================================
class _MessageCard extends StatelessWidget {
  final GuestbookModel message;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _MessageCard({
    required this.message,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = message.isApproved;
    final initial =
        message.guestName.isNotEmpty ? message.guestName[0].toUpperCase() : '?';
    final accentColor = isApproved ? _R.green : _R.amber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved ? _R.green.withOpacity(0.3) : _R.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec avatar + nom + statut
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.2),
                        accentColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accentColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nom + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.guestName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _R.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmtDateTime(message.createdAt),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _R.text2),
                      ),
                    ],
                  ),
                ),

                // Badge statut
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isApproved ? Icons.check_circle : Icons.pending,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isApproved ? 'Publié' : 'En attente',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: _R.text2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'toggle') onToggle();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isApproved
                                ? Icons.visibility_off_outlined
                                : Icons.check_circle_outline,
                            size: 18,
                            color: isApproved ? _R.amber : _R.green,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isApproved ? 'Masquer' : 'Approuver',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: _R.rose),
                          const SizedBox(width: 10),
                          Text(
                            'Supprimer',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _R.rose),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message avec guillemets décoratifs
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _R.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Guillemet décoratif
                  Positioned(
                    top: -4,
                    left: 4,
                    child: Icon(
                      Icons.format_quote,
                      size: 24,
                      color: accentColor.withOpacity(0.15),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _R.text,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions rapides en bas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _R.border.withOpacity(0.5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _QuickAction(
                  icon: isApproved
                      ? Icons.visibility_off_outlined
                      : Icons.check_circle_outline,
                  label: isApproved ? 'Masquer' : 'Approuver',
                  color: isApproved ? _R.amber : _R.green,
                  onTap: onToggle,
                ),
                const SizedBox(width: 6),
                _QuickAction(
                  icon: Icons.delete_outline,
                  label: 'Supprimer',
                  color: _R.rose,
                  onTap: onDelete,
                  danger: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String filter;
  final String search;

  const _EmptyState({required this.filter, required this.search});

  @override
  Widget build(BuildContext context) {
    final icon = search.isNotEmpty
        ? Icons.search_off
        : filter == 'approved'
            ? Icons.check_circle_outline
            : filter == 'pending'
                ? Icons.celebration_outlined
                : Icons.menu_book_outlined;
    final title = search.isNotEmpty
        ? 'Aucun résultat'
        : filter == 'approved'
            ? 'Aucun message publié'
            : filter == 'pending'
                ? 'Tout est approuvé ! 🎉'
                : 'Aucun message dans le livre d\'or';
    final subtitle = search.isNotEmpty
        ? 'Essayez avec d\'autres termes'
        : filter == 'pending'
            ? 'Tous les messages ont été modérés'
            : 'Les messages des invités apparaîtront ici';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _R.rose.withOpacity(0.15),
                  _R.purple.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: _R.rose),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DELETE DIALOG
// ============================================================================
class _DeleteDialog extends StatelessWidget {
  final String guestName;

  const _DeleteDialog({required this.guestName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer ce message ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _R.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Le message de "$guestName" sera définitivement supprimé du livre d\'or.',
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
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  gradient: _R.roseG, shape: BoxShape.circle),
              child: const Icon(Icons.menu_book_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement du livre d\'or...',
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
      backgroundColor: _R.surface,
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
String _fmtDateTime(DateTime dt) {
  const months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $month ${dt.year} à $h:$m';
}
