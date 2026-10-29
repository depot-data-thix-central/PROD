// lib/presentation/education/instructor/content/module_management_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/education/models/module.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';
import 'package:thix_id/presentation/education/instructor/content/lesson_management_page.dart';
import 'package:thix_id/presentation/education/instructor/evaluations/question_management_page.dart';

class ModuleManagementPage extends StatefulWidget {
  final Module? module;
  final String? courseId;
  const ModuleManagementPage({super.key, this.module, this.courseId});

  @override
  State<ModuleManagementPage> createState() => _ModuleManagementPageState();
}

class _ModuleManagementPageState extends State<ModuleManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isSavingModule = false;
  List<Lesson> _lessons = [];
  String? _savedModuleId;

  @override
  void initState() {
    super.initState();
    if (widget.module != null) {
      _titleController.text = widget.module!.title;
      _descriptionController.text = widget.module!.description ?? '';
      _lessons = List.from(widget.module!.lessons ?? []);
      if (widget.module!.id.isNotEmpty) {
        _savedModuleId = widget.module!.id;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _validModuleId {
    final id = _savedModuleId ?? widget.module?.id;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingModule = true);

    try {
      final formationId =
          widget.courseId ?? widget.module?.formationId ?? '';
      if (formationId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formation parent manquante.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = {
        'formation_id': formationId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'order': widget.module?.order ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      String moduleId = _validModuleId ?? '';

      if (moduleId.isEmpty) {
        data['created_at'] = DateTime.now().toIso8601String();
        final res = await Supabase.instance.client
            .from('modules')
            .insert(data)
            .select()
            .single();
        moduleId = res['id'] as String;
      } else {
        await Supabase.instance.client
            .from('modules')
            .update(data)
            .eq('id', moduleId);
      }

      setState(() => _savedModuleId = moduleId);

      final moduleToSave = Module(
        id: moduleId,
        formationId: formationId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        order: widget.module?.order ?? 0,
        lessons: _lessons,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Module enregistré !'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.pop(moduleToSave);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingModule = false);
    }
  }

  void _addLesson() async {
    if (_validModuleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enregistrez d\'abord le module (icône disquette), puis ajoutez des leçons.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newLesson = await context.push<Lesson>(
      '/education/instructor/lesson',
      extra: {
        'moduleId': _validModuleId,
        'formationId': widget.courseId ?? widget.module?.formationId,
      },
    );

    if (newLesson != null && mounted) {
      setState(() => _lessons.add(newLesson));
    }
  }

  void _editLesson(Lesson lesson) async {
    if (lesson.type == 'quiz' || lesson.type == 'evaluation') {
      setState(() => _isLoading = true);
      String currentLessonId = lesson.id;

      try {
        if (currentLessonId.isEmpty) {
          final targetModuleId = _validModuleId;
          if (targetModuleId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enregistrez d\'abord le module parent.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          final newLessonRes = await Supabase.instance.client
              .from('lessons')
              .insert({
                'module_id': targetModuleId,
                'title': lesson.title,
                'description': lesson.description ?? '',
                'type': lesson.type,
                'duration_minutes': lesson.durationMinutes,
                'content': lesson.content ?? '',
                'order': lesson.order,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select('id')
              .single();

          currentLessonId = newLessonRes['id'] as String;
          final index = _lessons.indexWhere(
            (l) =>
                (l.id.isEmpty && l.title == lesson.title) ||
                identical(l, lesson),
          );
          if (index != -1) {
            setState(() {
              _lessons[index] = lesson.copyWith(id: currentLessonId);
            });
          }
        }

        String? targetEvaluationId;
        final evalList = await Supabase.instance.client
            .from('evaluations')
            .select('id')
            .eq('lesson_id', currentLessonId)
            .maybeSingle();

        if (evalList != null) {
          targetEvaluationId = evalList['id'] as String;
        } else {
          final evalRes = await Supabase.instance.client
              .from('evaluations')
              .insert({
                'lesson_id': currentLessonId,
                'title': 'Quiz - ${lesson.title}',
                'passing_score': 50,
              })
              .select('id')
              .single();
          targetEvaluationId = evalRes['id'] as String;
        }

        if (targetEvaluationId != null && mounted) {
          await context.push(
            '/education/instructor/questions/$targetEvaluationId',
          );
        }
      } catch (e) {
        debugPrint('Erreur init quiz: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'initialiser le quiz : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      final updatedLesson = await context.push<Lesson>(
        '/education/instructor/lesson',
        extra: {
          'moduleId': _validModuleId,
          'formationId': widget.courseId ?? widget.module?.formationId,
          'lesson': lesson,
        },
      );

      if (updatedLesson != null && mounted) {
        final index = _lessons.indexWhere(
          (l) =>
              (l.id.isNotEmpty && l.id == lesson.id) || identical(l, lesson),
        );
        if (index != -1) {
          setState(() => _lessons[index] = updatedLesson);
        }
      }
    }
  }

  // ✅ CORRIGÉ : Supprime aussi de Supabase
  Future<void> _deleteLesson(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la leçon ?'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${lesson.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Supprimer de Supabase si la leçon a un ID
      if (lesson.id.isNotEmpty) {
        await Supabase.instance.client
            .from('lessons')
            .delete()
            .eq('id', lesson.id);
        
        // Supprimer aussi l'évaluation associée si elle existe
        final evalRes = await Supabase.instance.client
            .from('evaluations')
            .select('id')
            .eq('lesson_id', lesson.id)
            .maybeSingle();
        
        if (evalRes != null) {
          await Supabase.instance.client
              .from('evaluations')
              .delete()
              .eq('id', evalRes['id'] as String);
        }
      }

      // Supprimer de la liste locale
      if (mounted) {
        setState(() => _lessons.remove(lesson));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leçon supprimée'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ NOUVEAU : Réorganiser les leçons
  void _reorderLessons(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final lesson = _lessons.removeAt(oldIndex);
      _lessons.insert(newIndex, lesson);
      
      // Mettre à jour l'ordre de toutes les leçons
      for (int i = 0; i < _lessons.length; i++) {
        _lessons[i] = _lessons[i].copyWith(order: i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.module == null ? 'Ajouter un module' : 'Modifier le module',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: _isSavingModule
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2D6CDF),
                    ),
                  )
                : const Icon(Icons.save_rounded, color: Color(0xFF2D6CDF)),
            onPressed: _isSavingModule ? null : _saveModule,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D6CDF)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuration',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Titre du module*',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (_validModuleId != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Color(0xFF10B981), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Module enregistré — vous pouvez ajouter des leçons',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Leçons',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addLesson,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6CDF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _lessons.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune leçon. Enregistrez le module puis ajoutez-en.',
                              style: TextStyle(color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ReorderableListView.builder(
                            itemCount: _lessons.length,
                            onReorder: _reorderLessons,
                            itemBuilder: (context, index) {
                              final lesson = _lessons[index];
                              final isQuiz = lesson.type == 'quiz' ||
                                  lesson.type == 'evaluation';
                              return Container(
                                key: ValueKey(lesson.id),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.drag_indicator,
                                        color: const Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        backgroundColor: isQuiz
                                            ? const Color(0xFFF59E0B)
                                                .withOpacity(0.1)
                                            : const Color(0xFF2D6CDF)
                                                .withOpacity(0.1),
                                        radius: 18,
                                        child: Icon(
                                          isQuiz
                                              ? Icons.quiz_rounded
                                              : Icons.play_arrow_rounded,
                                          color: isQuiz
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF2D6CDF),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    lesson.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isQuiz
                                        ? 'Évaluation (Quiz)'
                                        : 'Leçon standard',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded),
                                        onPressed: () => _editLesson(lesson),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                        ),
                                        onPressed: () =>
                                            _deleteLesson(lesson),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _editLesson(lesson),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
