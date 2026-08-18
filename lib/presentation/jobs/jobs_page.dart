import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/job_posting.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/job_service.dart';

// ============================================================
// CHARTE GRAPHIQUE UNIFIÉE — Style "Mon Pays" / Événement
// ============================================================
class _JobColors {
  static const Color primaryBlue = Color(0xFF0B3D91);
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color gold = Color(0xFFF7C948);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color cardBorder = Color(0xFFEEF1F7);
  static const Color darkText = Color(0xFF10182B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlue = Color(0xFFEEF1F7);
  static const Color success = Color(0xFF00B074);
}

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _service = JobService();
  final _searchCtrl = TextEditingController();
  
  bool _loading = true;
  String? _error;
  List<JobPosting> _jobs = const [];
  Set<String> _saved = const {};

  // Filtres
  String _selectedCategory = 'all';
  final Set<String> _typeFilters = {};
  final Set<String> _workModeFilters = {};

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'icon': Icons.apps_rounded, 'label': 'Toutes'},
    {'id': 'remote', 'icon': Icons.laptop_mac_rounded, 'label': 'Télétravail'},
    {'id': 'full_time', 'icon': Icons.work_rounded, 'label': 'Temps plein'},
    {'id': 'part_time', 'icon': Icons.schedule_rounded, 'label': 'Temps partiel'},
    {'id': 'internship', 'icon': Icons.school_rounded, 'label': 'Stage'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _service.listJobs();
      final saved = await _service.getSavedJobIdsRemote();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _saved = saved;
      });
    } catch (e) {
      debugPrint('JobsPage.load failed err=$e');
      if (mounted) setState(() => _error = 'Erreur de chargement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyCategoryFilter(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
      _typeFilters.clear();
      _workModeFilters.clear();

      if (categoryId == 'remote') {
        _workModeFilters.add('remote');
      } else if (categoryId != 'all') {
        _typeFilters.add(categoryId);
      }
    });
  }

  List<JobPosting> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _jobs.where((j) {
      if (q.isNotEmpty) {
        final hay = '${j.title} ${j.company} ${j.location} ${j.description} ${j.skills.join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_typeFilters.isNotEmpty && !_typeFilters.contains(j.type.toLowerCase())) return false;
      final wm = (j.workMode ?? '').trim().toLowerCase();
      if (_workModeFilters.isNotEmpty && (wm.isEmpty || !_workModeFilters.contains(wm))) return false;
      
      final st = (j.status ?? '').trim().toLowerCase();
      if (st.isNotEmpty && st != 'approved') return false;
      
      return true;
    }).toList(growable: false);
  }

  List<JobPosting> get _featured => _filtered.where((j) => j.isFeatured).toList(growable: false);

  List<JobPosting> get _suggestions {
    final approved = _filtered;
    final tagged = approved.where((j) => j.isSuggested).toList(growable: true);
    if (tagged.length < 3) {
      for (final j in approved) {
        if (tagged.length >= 3) break;
        if (tagged.any((e) => e.id == j.id)) continue;
        if (j.isFeatured) continue;
        tagged.add(j);
      }
    }
    return tagged.take(3).toList(growable: false);
  }

  void _openJob(JobPosting j) => context.push('/jobs/${j.id}');

  Future<void> _toggleSave(JobPosting j) async {
    final id = j.id;
    final shouldSave = !_saved.contains(id);
    setState(() {
      final next = _saved.toSet();
      if (shouldSave) {
        next.add(id);
      } else {
        next.remove(id);
      }
      _saved = next;
    });
    await _service.toggleSavedRemote(jobId: id, save: shouldSave);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filtered;
    final suggestions = _suggestions;
    final featured = _featured;
    final featuredIds = featured.map((e) => e.id).toSet();
    final suggestionIds = suggestions.map((e) => e.id).toSet();
    final otherJobs = jobs.where((j) => !featuredIds.contains(j.id) && !suggestionIds.contains(j.id)).toList(growable: false);

    return Scaffold(
      backgroundColor: _JobColors.lightBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildCategorySection(),
                const SizedBox(height: 20),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_JobColors.primaryBlue)),
                    ),
                  )
                : (_error != null)
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text(_error!, style: const TextStyle(color: _JobColors.mutedText))),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (featured.isNotEmpty) ...[
                            _buildSectionHeader('À la une', null),
                            const SizedBox(height: 12),
                            FeaturedJobsCarousel(
                              jobs: featured,
                              onOpen: _openJob,
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (suggestions.isNotEmpty) ...[
                            _buildSectionHeader('Suggestions pour vous', null),
                            const SizedBox(height: 12),
                            SuggestedJobsCarousel(
                              jobs: suggestions,
                              onOpen: _openJob,
                            ),
                            const SizedBox(height: 24),
                          ],

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildNotificationBanner(),
                          ),
                          const SizedBox(height: 24),

                          _buildSectionHeader('Toutes les offres (${otherJobs.length})', null),
                          const SizedBox(height: 12),

                          if (jobs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: _JobColors.pureWhite,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _JobColors.cardBorder),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: _JobColors.mutedText.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    const Text('Aucune offre trouvée.', style: TextStyle(color: _JobColors.mutedText, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: otherJobs.take(50).map((j) => _JobCard(
                                  job: j,
                                  saved: _saved.contains(j.id),
                                  onSave: () => _toggleSave(j),
                                  onOpen: () => _openJob(j),
                                )).toList(),
                              ),
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_JobColors.navyDeep, _JobColors.primaryBlue],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x332D6CDF), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.home),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIX EMPLOI',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Offres vérifiées, parcours sécurisé.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(AppRoutes.jobDashboard),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECHERCHE
  // ============================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _JobColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _JobColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: _JobColors.mutedText),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: _JobColors.darkText, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Titre, entreprise, ville...',
                  hintStyle: TextStyle(fontSize: 12.5, color: _JobColors.mutedText, fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
                child: const Icon(Icons.close_rounded, size: 16, color: _JobColors.mutedText),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATÉGORIES (Quick Access)
  // ============================================================
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Catégories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _JobColors.primaryBlue),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat['id'];
              
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _applyCategoryFilter(cat['id']);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 75,
                  decoration: BoxDecoration(
                    color: isSelected ? _JobColors.primaryBlue : _JobColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.transparent : _JobColors.cardBorder),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: _JobColors.primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                      : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'] as IconData, color: isSelected ? _JobColors.gold : _JobColors.primaryBlue, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        cat['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : _JobColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EN-TÊTE DE SECTION
  // ============================================================
  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _JobColors.primaryBlue)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Row(
                children: [
                  Text('Voir tout', style: TextStyle(fontSize: 12, color: Color(0xFF5B8DEF), fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF5B8DEF)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BANNIÈRE
  // ============================================================
  Widget _buildNotificationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _JobColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _JobColors.primaryBlue.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: _JobColors.gold, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alerte Emploi', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Soyez notifié des nouvelles offres.', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _JobColors.gold,
              foregroundColor: _JobColors.primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Activer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE EMPLOI (Liste verticale)
// ============================================================
class _JobCard extends StatelessWidget {
  final JobPosting job;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  const _JobCard({required this.job, required this.saved, required this.onSave, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (job.companyLogoUrl ?? '').trim().startsWith('http');
    final borderCol = job.isVerifiedEmployer ? _JobColors.primaryBlue.withOpacity(0.3) : _JobColors.cardBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _JobColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _JobColors.softBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _JobColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? Image.network(job.companyLogoUrl!, fit: BoxFit.cover)
                    : Center(child: Icon(job.isVerifiedEmployer ? Icons.verified_rounded : Icons.business_rounded, color: _JobColors.primaryBlue)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(fontSize: 14.5, color: _JobColors.darkText, fontWeight: FontWeight.w900, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job.company} • ${job.location}',
                      style: const TextStyle(fontSize: 11.5, color: _JobColors.mutedText, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(icon: Icons.payments_rounded, label: job.salary),
                        _MetaPill(icon: Icons.category_rounded, label: job.type),
                        if (job.isSuggested) _MetaPill(icon: Icons.auto_awesome_rounded, label: 'Suggéré', highlight: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onSave,
                icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: saved ? _JobColors.gold : _JobColors.mutedText, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _MetaPill({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? _JobColors.gold.withOpacity(0.15) : _JobColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: highlight ? _JobColors.navyDeep : _JobColors.mutedText),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: highlight ? _JobColors.navyDeep : _JobColors.mutedText)),
        ],
      ),
    );
  }
}

// ============================================================
// CARROUSEL "À LA UNE"
// ============================================================
class FeaturedJobsCarousel extends StatefulWidget {
  final List<JobPosting> jobs;
  final ValueChanged<JobPosting> onOpen;

  const FeaturedJobsCarousel({super.key, required this.jobs, required this.onOpen});

  @override
  State<FeaturedJobsCarousel> createState() => _FeaturedJobsCarouselState();
}

class _FeaturedJobsCarouselState extends State<FeaturedJobsCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.jobs.isEmpty) return;
      final next = (_index + 1) % widget.jobs.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.jobs.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final j = widget.jobs[i];
                return Padding(
                  padding: EdgeInsets.only(right: i == widget.jobs.length - 1 ? 0 : 12, left: i == 0 ? 16 : 4),
                  child: _FeaturedJobCard(job: j, onTap: () => widget.onOpen(j)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.jobs.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? _JobColors.primaryBlue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeaturedJobCard extends StatelessWidget {
  final JobPosting job;
  final VoidCallback onTap;

  const _FeaturedJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (job.companyLogoUrl ?? '').trim().startsWith('http');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _JobColors.navyDeep.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              Image.network(job.companyLogoUrl!, fit: BoxFit.cover)
            else
              Container(color: _JobColors.navyDeep),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_JobColors.primaryBlue.withOpacity(0.95), Colors.transparent],
                  stops: const [0, 0.7],
                ),
              ),
            ),
            
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _JobColors.gold, borderRadius: BorderRadius.circular(8)),
                child: const Text('À LA UNE', style: TextStyle(fontSize: 9, color: _JobColors.navyDeep, fontWeight: FontWeight.w900)),
              ),
            ),
            
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 16, color: _JobColors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${job.company} • ${job.location}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _JobColors.gold, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARROUSEL "SUGGESTIONS"
// ============================================================
class SuggestedJobsCarousel extends StatelessWidget {
  final List<JobPosting> jobs;
  final ValueChanged<JobPosting> onOpen;

  const SuggestedJobsCarousel({super.key, required this.jobs, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final j = jobs[i];
          final hasPhoto = (j.companyLogoUrl ?? '').trim().startsWith('http');
          
          return GestureDetector(
            onTap: () => onOpen(j),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _JobColors.pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _JobColors.cardBorder),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _JobColors.softBlue, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Suggéré pour vous', style: TextStyle(fontSize: 9, color: _JobColors.primaryBlue, fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      if (hasPhoto)
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(j.companyLogoUrl!, width: 24, height: 24, fit: BoxFit.cover))
                      else
                        const Icon(Icons.business_rounded, color: _JobColors.mutedText, size: 20),
                    ],
                  ),
                  const Spacer(),
                  Text(j.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _JobColors.darkText), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('${j.company} • ${j.location}', style: const TextStyle(fontSize: 11, color: _JobColors.mutedText, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
