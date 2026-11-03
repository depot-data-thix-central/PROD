// lib/presentation/thix_weeding/pages/provider_portal/traiteur/guest_voting_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'menu_models.dart';
import 'traiteur_menu_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — STATISTIQUES VOTES INVITÉS (Production v2)
/// ✅ Statistiques en temps réel
/// ✅ Graphiques interactifs
/// ✅ Répartition par catégorie
/// ✅ Top plats par votes
/// ✅ Taux de participation
/// ✅ Filtres et recherche
/// ═══════════════════════════════════════════════════════════════════════

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

class GuestVotingPage extends ConsumerStatefulWidget {
  final String menuId;

  const GuestVotingPage({
    super.key,
    required this.menuId,
  });

  @override
  ConsumerState<GuestVotingPage> createState() => _GuestVotingPageState();
}

class _GuestVotingPageState extends ConsumerState<GuestVotingPage> {
  String _selectedCategory = 'all';
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final votesAsync = ref.watch(guestVotesProvider(widget.menuId));
    final statsAsync = ref.watch(menuStatsProvider(widget.menuId));
    final menuAsync = ref.watch(menuProviderByMenuId(widget.menuId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          'Statistiques des votes',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDetails ? Icons.list_rounded : Icons.analytics_rounded,
              color: _P.ink,
            ),
            onPressed: () => setState(() => _showDetails = !_showDetails),
            tooltip: _showDetails ? 'Vue graphique' : 'Vue détaillée',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre par catégorie
          _CategoryFilter(
            selectedCategory: _selectedCategory,
            onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
          ),

          Expanded(
            child: votesAsync.when(
              data: (votes) {
                return statsAsync.when(
                  data: (stats) {
                    return menuAsync.when(
                      data: (menu) {
                        if (menu == null) {
                          return const Center(child: Text('Menu non trouvé'));
                        }

                        return _buildStatsContent(votes, stats, menu);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
                      error: (_, __) => const Center(child: Text('Erreur')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
                  error: (_, __) => const Center(child: Text('Erreur stats')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 60, color: _P.red),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(
    List<GuestVote> votes,
    MenuStatistics stats,
    WeddingMenu menu,
  ) {
    if (votes.isEmpty) {
      return _EmptyVotesState(menuId: widget.menuId);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(guestVotesProvider(widget.menuId));
        ref.invalidate(menuStatsProvider(widget.menuId));
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════ STATS GLOBALES ═══════════════
          _GlobalStatsCard(stats: stats),
          const SizedBox(height: 16),

          // ═══════════════ GRAPHIQUE PARTICIPATION ═══════════════
          _ParticipationChart(stats: stats),
          const SizedBox(height: 16),

          // ═══════════════ RÉPARTITION PAR CATÉGORIE ═══════════════
          _CategoryBreakdown(
            stats: stats,
            menu: menu,
            selectedCategory: _selectedCategory,
          ),
          const SizedBox(height: 16),

          // ═══════════════ TOP PLATS ═══════════════
          _TopItemsSection(
            stats: stats,
            menu: menu,
            selectedCategory: _selectedCategory,
          ),
          const SizedBox(height: 16),

          // ═══════════════ VOTES RÉCENTS ═══════════════
          if (_showDetails)
            _RecentVotesSection(votes: votes),
          if (_showDetails) const SizedBox(height: 16),

          // ═══════════════ DIETARY RESTRICTIONS ═══════════════
          _DietaryStatsSection(votes: votes),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVIDER MENU PAR ID
// ═══════════════════════════════════════════════════════════════════════

final menuProviderByMenuId = FutureProvider.autoDispose.family<WeddingMenu?, String>((ref, menuId) async {
  final client = ref.read(supabaseClient);

  try {
    final response = await client
        .from('wedding_menus')
        .select()
        .eq('id', menuId)
        .maybeSingle();

    if (response == null) return null;
    return WeddingMenu.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Erreur: $e');
  }
});

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _CategoryFilter extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _CategoryFilter({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('all', 'Tous'),
      ('aperitif', 'Apéritif'),
      ('entree', 'Entrée'),
      ('plat', 'Plat'),
      ('dessert', 'Dessert'),
      ('boisson', 'Boisson'),
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = categories[index];
          final isSelected = selectedCategory == value;

          return GestureDetector(
            onTap: () => onCategorySelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _P.rose : _P.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _P.rose : _P.line),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _P.ink,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlobalStatsCard extends StatelessWidget {
  final MenuStatistics stats;

  const _GlobalStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final participationRate = stats.participationRate * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.rose, _P.roseLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _P.rose.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vue d\'ensemble',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '${stats.totalVotes}',
                  label: 'Votes',
                  icon: Icons.how_to_vote_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: '${stats.totalGuests}',
                  label: 'Invités',
                  icon: Icons.people_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: '${participationRate.toStringAsFixed(0)}%',
                  label: 'Taux',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats.mostVotedItem.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Plat le plus voté: ${stats.mostVotedItem}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipationChart extends StatelessWidget {
  final MenuStatistics stats;

  const _ParticipationChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final voted = stats.totalVotes;
    final notVoted = stats.totalGuests - stats.totalVotes;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: _P.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Taux de participation',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: voted.toDouble(),
                    color: _P.green,
                    title: '$voted',
                    titleStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    radius: 60,
                  ),
                  PieChartSectionData(
                    value: notVoted.toDouble(),
                    color: _P.line,
                    title: '$notVoted',
                    titleStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _P.inkSoft,
                    ),
                    radius: 60,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: _P.green, label: 'Ont voté ($voted)'),
              const SizedBox(width: 20),
              _LegendItem(color: _P.line, label: 'N\'ont pas voté ($notVoted)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final MenuStatistics stats;
  final WeddingMenu menu;
  final String selectedCategory;

  const _CategoryBreakdown({
    required this.stats,
    required this.menu,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Votes par catégorie',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...MenuItemCategory.values.map((category) {
            final categoryKey = category.name;
            final votes = stats.votesByCategory[categoryKey] ?? 0;
            final totalItems = menu.getItemsByCategory(category).length;
            final maxVotes = stats.totalVotes > 0 ? stats.totalVotes : 1;
            final percentage = (votes / maxVotes * 100).clamp(0.0, 100.0);

            if (selectedCategory != 'all' && selectedCategory != categoryKey) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(category.icon, size: 16, color: category.color),
                      const SizedBox(width: 8),
                      Text(
                        category.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$votes votes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _P.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: _P.line,
                      valueColor: AlwaysStoppedAnimation<Color>(category.color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopItemsSection extends StatelessWidget {
  final MenuStatistics stats;
  final WeddingMenu menu;
  final String selectedCategory;

  const _TopItemsSection({
    required this.stats,
    required this.menu,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Top plats',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (selectedCategory == 'all')
            ...MenuItemCategory.values.map((category) {
              return _buildCategoryTopItems(category, stats, menu);
            })
          else
            _buildCategoryTopItems(
              MenuItemCategory.values.firstWhere((c) => c.name == selectedCategory),
              stats,
              menu,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTopItems(
    MenuItemCategory category,
    MenuStatistics stats,
    WeddingMenu menu,
  ) {
    final categoryItems = menu.getItemsByCategory(category);
    final itemVotes = stats.itemVotes[category.name] ?? {};

    // Trier par nombre de votes
    final sortedItems = categoryItems.toList()
      ..sort((a, b) {
        final votesA = itemVotes[a.id] ?? 0;
        final votesB = itemVotes[b.id] ?? 0;
        return votesB.compareTo(votesA);
      });

    if (sortedItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 16, color: category.color),
            const SizedBox(width: 8),
            Text(
              category.displayName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _P.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final votes = itemVotes[item.id] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: index == 0 ? _P.amber.withOpacity(0.05) : _P.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: index == 0 ? _P.amber.withOpacity(0.3) : _P.line,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? _P.amber
                        : index == 1
                            ? _P.inkSoft
                            : _P.line,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: index < 2 ? Colors.white : _P.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _P.ink,
                        ),
                      ),
                      if (item.dietaryOptions.isNotEmpty)
                        Row(
                          children: item.dietaryOptions.take(2).map((option) {
                            return Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _P.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _P.green,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$votes',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: category.color,
                      ),
                    ),
                    Text(
                      'votes',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _P.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RecentVotesSection extends StatelessWidget {
  final List<GuestVote> votes;

  const _RecentVotesSection({required this.votes});

  @override
  Widget build(BuildContext context) {
    final recentVotes = votes.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: _P.green, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Votes récents',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentVotes.map((vote) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _P.rose.withOpacity(0.1),
                    child: Text(
                      vote.guestName[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: _P.rose,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vote.guestName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _P.ink,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy HH:mm', 'fr_FR').format(vote.votedAt),
                          style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _P.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${vote.choices.values.fold<int>(0, (sum, list) => sum + list.length)} choix',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _P.green,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DietaryStatsSection extends StatelessWidget {
  final List<GuestVote> votes;

  const _DietaryStatsSection({required this.votes});

  @override
  Widget build(BuildContext context) {
    final dietaryCounts = <String, int>{};

    for (var vote in votes) {
      if (vote.dietaryRestrictions != null) {
        for (var restriction in vote.dietaryRestrictions!) {
          dietaryCounts[restriction] = (dietaryCounts[restriction] ?? 0) + 1;
        }
      }
    }

    if (dietaryCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_rounded, color: _P.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Régimes alimentaires',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dietaryCounts.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _P.purple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _P.purple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _P.purple,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyVotesState extends StatelessWidget {
  final String menuId;

  const _EmptyVotesState({required this.menuId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _P.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.poll_outlined, size: 56, color: _P.purple),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun vote pour le moment',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les invités voteront lorsque le menu sera rendu public.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _P.inkSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════



extension DietaryRestrictionExtension on DietaryRestriction {
  String get displayName {
    switch (this) {
      case DietaryRestriction.vegetarian:
        return 'Végétarien';
      case DietaryRestriction.vegan:
        return 'Vegan';
      case DietaryRestriction.halal:
        return 'Halal';
      case DietaryRestriction.kosher:
        return 'Casher';
      case DietaryRestriction.glutenFree:
        return 'Sans gluten';
      case DietaryRestriction.lactoseFree:
        return 'Sans lactose';
      case DietaryRestriction.nutFree:
        return 'Sans noix';
    }
  }
}
