// lib/presentation/thix_weeding/pages/provider_portal/suggestions/dg_suggestions_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — SUGGESTIONS DG (Chansons, Ambiance) (Production v2)
/// ✅ Suggestion de chansons par le DG
/// ✅ Validation/approbation par le staff
/// ✅ Statistiques des suggestions
/// ✅ Historique complet
/// ✅ Intégration avec le DJ
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

enum SuggestionStatus {
  pending,
  approved,
  rejected,
  played,
}

enum SuggestionType {
  song,
  playlist,
  ambiance,
  animation,
}

class DGSuggestion {
  final String id;
  final String orderId;
  final String suggestedBy;
  final String suggestedByName;
  final SuggestionType type;
  final String title;
  final String? artist;
  final String? notes;
  final String? youtubeUrl;
  final SuggestionStatus status;
  final String? staffComment;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final int priority; // 1-5

  const DGSuggestion({
    required this.id,
    required this.orderId,
    required this.suggestedBy,
    required this.suggestedByName,
    required this.type,
    required this.title,
    this.artist,
    this.notes,
    this.youtubeUrl,
    this.status = SuggestionStatus.pending,
    this.staffComment,
    required this.createdAt,
    this.reviewedAt,
    this.priority = 3,
  });

  String get statusDisplayName {
    switch (status) {
      case SuggestionStatus.pending:
        return 'En attente';
      case SuggestionStatus.approved:
        return 'Approuvée';
      case SuggestionStatus.rejected:
        return 'Rejetée';
      case SuggestionStatus.played:
        return 'Jouée';
    }
  }

  Color get statusColor {
    switch (status) {
      case SuggestionStatus.pending:
        return _P.amber;
      case SuggestionStatus.approved:
        return _P.green;
      case SuggestionStatus.rejected:
        return _P.red;
      case SuggestionStatus.played:
        return _P.purple;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case SuggestionType.song:
        return Icons.music_note_rounded;
      case SuggestionType.playlist:
        return Icons.queue_music_rounded;
      case SuggestionType.ambiance:
        return Icons.lightbulb_rounded;
      case SuggestionType.animation:
        return Icons.celebration_rounded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'suggested_by': suggestedBy,
      'suggested_by_name': suggestedByName,
      'type': type.name,
      'title': title,
      'artist': artist,
      'notes': notes,
      'youtube_url': youtubeUrl,
      'status': status.name,
      'staff_comment': staffComment,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'priority': priority,
    };
  }

  factory DGSuggestion.fromJson(Map<String, dynamic> json) {
    return DGSuggestion(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      suggestedBy: json['suggested_by'] as String,
      suggestedByName: json['suggested_by_name'] as String,
      type: SuggestionType.values.firstWhere((t) => t.name == json['type']),
      title: json['title'] as String,
      artist: json['artist'] as String?,
      notes: json['notes'] as String?,
      youtubeUrl: json['youtube_url'] as String?,
      status: SuggestionStatus.values.firstWhere((s) => s.name == json['status']),
      staffComment: json['staff_comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
      priority: json['priority'] as int? ?? 3,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════

final supabaseClient = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final suggestionsProvider = AsyncNotifierProvider.autoDispose.family<SuggestionsNotifier, List<DGSuggestion>, String>(
  SuggestionsNotifier.new,
);

class SuggestionsNotifier extends AutoDisposeFamilyAsyncNotifier<List<DGSuggestion>, String> {
  SupabaseClient get _client => ref.read(supabaseClient);

  @override
  Future<List<DGSuggestion>> build(String orderId) async {
    return _fetchSuggestions(orderId);
  }

  Future<List<DGSuggestion>> _fetchSuggestions(String orderId) async {
    try {
      final response = await _client
          .from('dg_suggestions')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return response
          .map((json) => DGSuggestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des suggestions: $e');
    }
  }

  Future<void> createSuggestion({
    required String orderId,
    required String suggestedBy,
    required String suggestedByName,
    required SuggestionType type,
    required String title,
    String? artist,
    String? notes,
    String? youtubeUrl,
    int priority = 3,
  }) async {
    try {
      final suggestion = DGSuggestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: orderId,
        suggestedBy: suggestedBy,
        suggestedByName: suggestedByName,
        type: type,
        title: title,
        artist: artist,
        notes: notes,
        youtubeUrl: youtubeUrl,
        priority: priority,
        createdAt: DateTime.now(),
      );

      await _client.from('dg_suggestions').insert(suggestion.toJson());

      final suggestions = await _fetchSuggestions(orderId);
      state = AsyncValue.data(suggestions);
    } catch (e) {
      throw Exception('Erreur lors de la création: $e');
    }
  }

  Future<void> updateStatus({
    required String suggestionId,
    required SuggestionStatus newStatus,
    String? staffComment,
  }) async {
    try {
      await _client
          .from('dg_suggestions')
          .update({
            'status': newStatus.name,
            'staff_comment': staffComment,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', suggestionId);

      final suggestions = await _fetchSuggestions(arg);
      state = AsyncValue.data(suggestions);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  Future<void> deleteSuggestion(String suggestionId) async {
    try {
      await _client.from('dg_suggestions').delete().eq('id', suggestionId);

      final suggestions = await _fetchSuggestions(arg);
      state = AsyncValue.data(suggestions);
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }
}

final suggestionStatsProvider = Provider.autoDispose.family<SuggestionStats, String>((ref, orderId) {
  final suggestionsAsync = ref.watch(suggestionsProvider(orderId));
  final suggestions = suggestionsAsync.value ?? [];

  return SuggestionStats(
    total: suggestions.length,
    pending: suggestions.where((s) => s.status == SuggestionStatus.pending).length,
    approved: suggestions.where((s) => s.status == SuggestionStatus.approved).length,
    rejected: suggestions.where((s) => s.status == SuggestionStatus.rejected).length,
    played: suggestions.where((s) => s.status == SuggestionStatus.played).length,
  );
});

class SuggestionStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int played;

  const SuggestionStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.played,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════

class DGSuggestionsPage extends ConsumerStatefulWidget {
  final String orderId;
  final String userId;
  final String userName;
  final bool isStaff;

  const DGSuggestionsPage({
    super.key,
    required this.orderId,
    required this.userId,
    required this.userName,
    this.isStaff = false,
  });

  @override
  ConsumerState<DGSuggestionsPage> createState() => _DGSuggestionsPageState();
}

class _DGSuggestionsPageState extends ConsumerState<DGSuggestionsPage> {
  SuggestionStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(suggestionsProvider(widget.orderId));
    final stats = ref.watch(suggestionStatsProvider(widget.orderId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          'Suggestions DG',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        actions: [
          if (_statusFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: _P.ink),
              onPressed: () => setState(() => _statusFilter = null),
              tooltip: 'Réinitialiser filtre',
            ),
          PopupMenuButton<SuggestionStatus?>(
            icon: const Icon(Icons.filter_list_rounded, color: _P.ink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (status) => setState(() => _statusFilter = status),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text('Toutes', style: GoogleFonts.inter(fontSize: 13)),
              ),
              ...SuggestionStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Text(status.statusDisplayName, style: GoogleFonts.inter(fontSize: 13)),
                );
              }),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSuggestionDialog(),
        backgroundColor: _P.rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Suggérer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // Stats rapides
          _QuickStats(stats: stats),

          Expanded(
            child: suggestionsAsync.when(
              data: (suggestions) {
                final filtered = _statusFilter != null
                    ? suggestions.where((s) => s.status == _statusFilter).toList()
                    : suggestions;

                if (filtered.isEmpty) {
                  return _EmptyState(hasSuggestions: suggestions.isNotEmpty);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    ref.invalidate(suggestionsProvider(widget.orderId));
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _SuggestionCard(
                        suggestion: filtered[index],
                        isStaff: widget.isStaff,
                        onApprove: () => _updateStatus(filtered[index], SuggestionStatus.approved),
                        onReject: () => _showRejectDialog(filtered[index]),
                        onMarkPlayed: () => _updateStatus(filtered[index], SuggestionStatus.played),
                        onDelete: () => _deleteSuggestion(filtered[index]),
                      );
                    },
                  ),
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

  Future<void> _showAddSuggestionDialog() async {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final youtubeCtrl = TextEditingController();

    SuggestionType selectedType = SuggestionType.song;
    int selectedPriority = 3;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Nouvelle suggestion',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type
                Text(
                  'Type de suggestion',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: SuggestionType.values.map((type) {
                    final selected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? _P.purple : _P.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? _P.purple : _P.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type.icon,
                              size: 16,
                              color: selected ? Colors.white : _P.inkSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : _P.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Titre
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: selectedType == SuggestionType.song ? 'Titre de la chanson *' : 'Titre *',
                    hintText: selectedType == SuggestionType.song ? 'Ex: Conga Party' : 'Ex: Ambiance tropicale',
                    prefixIcon: Icon(selectedType.icon, color: _P.inkSoft),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Artiste (si chanson)
                if (selectedType == SuggestionType.song || selectedType == SuggestionType.playlist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: artistCtrl,
                      decoration: InputDecoration(
                        labelText: 'Artiste',
                        hintText: 'Ex: Fally Ipupa',
                        prefixIcon: const Icon(Icons.person_rounded, color: _P.inkSoft),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                // Lien YouTube
                TextField(
                  controller: youtubeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Lien YouTube (optionnel)',
                    hintText: 'https://youtube.com/...',
                    prefixIcon: const Icon(Icons.play_circle_outline_rounded, color: _P.inkSoft),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Ex: Pour l\'ouverture de bal',
                    prefixIcon: const Icon(Icons.note_rounded, color: _P.inkSoft),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Priorité
                Text(
                  'Priorité: $selectedPriority/5',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: selectedPriority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: _P.rose,
                  onChanged: (v) => setState(() => selectedPriority = v.toInt()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;

                Navigator.pop(context);

                try {
                  await ref.read(suggestionsProvider(widget.orderId).notifier).createSuggestion(
                        orderId: widget.orderId,
                        suggestedBy: widget.userId,
                        suggestedByName: widget.userName,
                        type: selectedType,
                        title: titleCtrl.text,
                        artist: artistCtrl.text.isNotEmpty ? artistCtrl.text : null,
                        notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                        youtubeUrl: youtubeCtrl.text.isNotEmpty ? youtubeCtrl.text : null,
                        priority: selectedPriority,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Suggestion créée ✓',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: _P.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: _P.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Envoyer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(DGSuggestion suggestion, SuggestionStatus newStatus) async {
    try {
      await ref.read(suggestionsProvider(widget.orderId).notifier).updateStatus(
            suggestionId: suggestion.id,
            newStatus: newStatus,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Suggestion ${newStatus.statusDisplayName.toLowerCase()}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(DGSuggestion suggestion) async {
    final commentCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rejeter la suggestion',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Raison du rejet (optionnel)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await ref.read(suggestionsProvider(widget.orderId).notifier).updateStatus(
                      suggestionId: suggestion.id,
                      newStatus: SuggestionStatus.rejected,
                      staffComment: commentCtrl.text.isNotEmpty ? commentCtrl.text : null,
                    );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: _P.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Rejeter',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSuggestion(DGSuggestion suggestion) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Supprimer cette suggestion ?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            content: Text(
              '"${suggestion.title}" sera définitivement supprimée.',
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler', style: GoogleFonts.inter(color: _P.inkSoft)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        await ref.read(suggestionsProvider(widget.orderId).notifier).deleteSuggestion(suggestion.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: _P.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _QuickStats extends StatelessWidget {
  final SuggestionStats stats;

  const _QuickStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.purple, Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _P.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${stats.total}',
            label: 'Total',
            icon: Icons.list_rounded,
          ),
          _StatItem(
            value: '${stats.pending}',
            label: 'En attente',
            icon: Icons.hourglass_empty_rounded,
          ),
          _StatItem(
            value: '${stats.approved}',
            label: 'Approuvées',
            icon: Icons.check_circle_rounded,
          ),
          _StatItem(
            value: '${stats.played}',
            label: 'Jouées',
            icon: Icons.play_circle_filled_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
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
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final DGSuggestion suggestion;
  final bool isStaff;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMarkPlayed;
  final VoidCallback onDelete;

  const _SuggestionCard({
    required this.suggestion,
    required this.isStaff,
    required this.onApprove,
    required this.onReject,
    required this.onMarkPlayed,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: suggestion.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(suggestion.typeIcon, color: suggestion.statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _P.ink,
                        ),
                      ),
                      if (suggestion.artist != null)
                        Text(
                          suggestion.artist!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _P.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: suggestion.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    suggestion.statusDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: suggestion.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Métadonnées
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14, color: _P.inkSoft),
                const SizedBox(width: 4),
                Text(
                  suggestion.suggestedByName,
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time_rounded, size: 14, color: _P.inkSoft),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM HH:mm', 'fr_FR').format(suggestion.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                ),
                const Spacer(),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: index < suggestion.priority ? _P.amber : _P.line,
                    ),
                  ),
                ),
              ],
            ),

            if (suggestion.notes != null && suggestion.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note_rounded, size: 14, color: _P.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.notes!,
                        style: GoogleFonts.inter(fontSize: 12, color: _P.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (suggestion.staffComment != null && suggestion.staffComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_rounded, size: 14, color: _P.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.staffComment!,
                        style: GoogleFonts.inter(fontSize: 12, color: _P.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (suggestion.youtubeUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 14, color: _P.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      suggestion.youtubeUrl!,
                      style: GoogleFonts.inter(fontSize: 11, color: _P.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Actions staff
            if (isStaff && suggestion.status == SuggestionStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approuver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Rejeter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _P.red,
                        side: const BorderSide(color: _P.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Actions staff pour suggestions approuvées
            if (isStaff && suggestion.status == SuggestionStatus.approved) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMarkPlayed,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Marquer comme jouée'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _P.red),
                  ),
                ],
              ),
            ],

            // Suppression pour le propriétaire
            if (!isStaff && suggestion.status == SuggestionStatus.pending) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _P.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSuggestions;

  const _EmptyState({required this.hasSuggestions});

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
              child: const Icon(Icons.music_note_rounded, size: 56, color: _P.purple),
            ),
            const SizedBox(height: 20),
            Text(
              hasSuggestions ? 'Aucune suggestion filtrée' : 'Aucune suggestion',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSuggestions
                  ? 'Modifiez vos filtres pour voir plus de suggestions'
                  : 'Le DG peut suggérer des chansons et ambiances pour l\'événement',
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

extension SuggestionTypeExtension on SuggestionType {
  String get displayName {
    switch (this) {
      case SuggestionType.song:
        return 'Chanson';
      case SuggestionType.playlist:
        return 'Playlist';
      case SuggestionType.ambiance:
        return 'Ambiance';
      case SuggestionType.animation:
        return 'Animation';
    }
  }

  IconData get icon {
    switch (this) {
      case SuggestionType.song:
        return Icons.music_note_rounded;
      case SuggestionType.playlist:
        return Icons.queue_music_rounded;
      case SuggestionType.ambiance:
        return Icons.lightbulb_rounded;
      case SuggestionType.animation:
        return Icons.celebration_rounded;
    }
  }
}

extension SuggestionStatusExtension on SuggestionStatus {
  String get statusDisplayName {
    switch (this) {
      case SuggestionStatus.pending:
        return 'En attente';
      case SuggestionStatus.approved:
        return 'Approuvée';
      case SuggestionStatus.rejected:
        return 'Rejetée';
      case SuggestionStatus.played:
        return 'Jouée';
    }
  }

  Color get statusColor {
    switch (this) {
      case SuggestionStatus.pending:
        return _P.amber;
      case SuggestionStatus.approved:
        return _P.green;
      case SuggestionStatus.rejected:
        return _P.red;
      case SuggestionStatus.played:
        return _P.purple;
    }
  }
}
