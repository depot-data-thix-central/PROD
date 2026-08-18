// lib/presentation/education/instructor/course_management_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/education/models/formation.dart';
import 'package:thix_id/presentation/education/widgets/common/formation_card.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
}

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  List<Map<String, dynamic>> _rawCourses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  Future<void> _loadMyCourses() async {
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      // Récupération brute pour gérer facilement les statuts et champs additionnels
      final response = await Supabase.instance.client
          .from('formations')
          .select('*, categories(*)')
          .eq('instructor_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rawCourses = List<Map<String, dynamic>>.from(response as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement de mes cours : $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // Changer le statut (Publié / Brouillon)
  Future<void> _toggleCourseStatus(String courseId, String currentStatus) async {
    final newStatus = currentStatus == 'draft' ? 'published' : 'draft';
    try {
      await Supabase.instance.client
          .from('formations')
          .update({'status': newStatus})
          .eq('id', courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'draft' ? 'Cours mis au brouillon' : 'Cours publié avec succès'),
            backgroundColor: _C.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadMyCourses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red),
        );
      }
    }
  }

  // Supprimer un cours avec confirmation de sécurité
  Future<void> _confirmAndDeleteCourse(String courseId, String courseTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Êtes-vous sûr de vouloir supprimer définitivement le cours "$courseTitle" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('formations').delete().eq('id', courseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cours supprimé avec succès'), backgroundColor: _C.green, behavior: SnackBarBehavior.floating),
          );
          _loadMyCourses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression : $e'), backgroundColor: _C.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Gestion des cours', style: TextStyle(fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18)),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _C.primary),
            tooltip: 'Nouveau cours',
            onPressed: () async {
              await context.push('/instructor/courses/create');
              _loadMyCourses(); 
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : RefreshIndicator(
              color: _C.primary,
              onRefresh: _loadMyCourses,
              child: _rawCourses.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_rounded, size: 64, color: _C.border),
                              SizedBox(height: 16),
                              Text(
                                'Aucun cours créé',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.textMain),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Créez votre premier cours en cliquant sur +',
                                style: TextStyle(color: _C.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rawCourses.length,
                      itemBuilder: (context, index) {
                        final courseData = _rawCourses[index];
                        final formation = Formation.fromJson(courseData);
                        final status = courseData['status'] ?? 'published'; // Valeur par défaut 'published'
                        final isDraft = status == 'draft';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Carte du cours cliquable pour l'édition
                              GestureDetector(
                                onTap: () async {
                                  await context.push('/instructor/courses/edit/${formation.id}');
                                  _loadMyCourses();
                                },
                                child: AbsorbPointer(
                                  child: FormationCard(formation: formation, onTap: () {}),
                                ),
                              ),
                              // Barre d'actions d'entreprise (Statut + Menu contextuel)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Badge de statut
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDraft ? _C.orange.withOpacity(0.1) : _C.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isDraft ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                                            size: 14,
                                            color: isDraft ? _C.orange : _C.green,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isDraft ? 'Brouillon' : 'Publié',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isDraft ? _C.orange : _C.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Menu d'actions rapides (Modifier, Brouillon/Publier, Supprimer)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: _C.textMuted),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await context.push('/instructor/courses/edit/${formation.id}');
                                          _loadMyCourses();
                                        } else if (value == 'toggle_status') {
                                          await _toggleCourseStatus(formation.id, status);
                                        } else if (value == 'delete') {
                                          await _confirmAndDeleteCourse(formation.id, formation.title);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_rounded, size: 18, color: _C.primary),
                                              SizedBox(width: 10),
                                              Text('Modifier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle_status',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isDraft ? Icons.publish_rounded : Icons.visibility_off_rounded,
                                                size: 18,
                                                color: _C.orange,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                isDraft ? 'Publier le cours' : 'Mettre au brouillon',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_rounded, size: 18, color: _C.red),
                                              SizedBox(width: 10),
                                              Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _C.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
