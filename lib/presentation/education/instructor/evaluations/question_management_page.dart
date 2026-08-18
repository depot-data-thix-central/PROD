// lib/presentation/education/instructor/evaluations/question_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF2D6CDF);
  static const green = Color(0xFF10B981);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
}

class QuestionManagementPage extends ConsumerStatefulWidget {
  final String evaluationId;
  const QuestionManagementPage({super.key, required this.evaluationId});

  @override
  ConsumerState<QuestionManagementPage> createState() =>
      _QuestionManagementPageState();
}

class _QuestionManagementPageState
    extends ConsumerState<QuestionManagementPage> {
  final List<Map<String, dynamic>> _questions = [];

  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  int? _correctIndex;
  String _questionType = 'qcm';
  int? _editingIndex;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _optionControllers.addAll([
      TextEditingController(),
      TextEditingController(),
    ]);
    _loadExistingQuestions();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingQuestions() async {
    try {
      final res = await Supabase.instance.client
          .from('questions')
          .select('*')
          .eq('evaluation_id', widget.evaluationId);

      if (mounted) {
        setState(() {
          _questions.addAll((res as List).map((q) {
            return {
              'id': q['id'],
              'question': q['question'] ?? '',
              'type': q['type'] ?? 'qcm',
              'options': q['options'] != null
                  ? List<String>.from(q['options'])
                  : <String>[],
              'correctIndex': q['correct_index'] ?? 0,
            };
          }));
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement questions : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOptionField() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOptionField(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      if (_correctIndex == index) {
        _correctIndex = null;
      } else if (_correctIndex != null && _correctIndex! > index) {
        _correctIndex = _correctIndex! - 1;
      }
    });
  }

  void _submitQuestion() {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      _showSnackBar('Veuillez saisir une question.', isError: true);
      return;
    }

    List<String> options = [];
    int finalCorrectIndex = 0;

    if (_questionType == 'qcm') {
      options = _optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (options.length < 2) {
        _showSnackBar('Ajoutez au moins 2 options.', isError: true);
        return;
      }
      if (_correctIndex == null || _correctIndex! >= options.length) {
        _showSnackBar('Sélectionnez la bonne réponse.', isError: true);
        return;
      }
      finalCorrectIndex = _correctIndex!;
    } else if (_questionType == 'vrai_faux') {
      if (_correctIndex == null) {
        _showSnackBar('Choisissez Vrai ou Faux.', isError: true);
        return;
      }
      options = ['Vrai', 'Faux'];
      finalCorrectIndex = _correctIndex!;
    }

    final newQuestion = {
      'id': _editingIndex != null ? _questions[_editingIndex!]['id'] : null,
      'question': questionText,
      'type': _questionType,
      'options': options,
      'correctIndex': finalCorrectIndex,
    };

    setState(() {
      if (_editingIndex != null) {
        _questions[_editingIndex!] = newQuestion;
        _showSnackBar('Question mise à jour.', isError: false);
      } else {
        _questions.add(newQuestion);
        _showSnackBar('Question ajoutée à la liste.', isError: false);
      }
      _resetForm();
    });
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    setState(() {
      _editingIndex = index;
      _questionType = q['type'] ?? 'qcm';
      _questionController.text = q['question'] ?? '';

      for (final c in _optionControllers) {
        c.dispose();
      }
      _optionControllers.clear();

      if (_questionType == 'qcm') {
        for (final opt in (q['options'] as List)) {
          _optionControllers.add(TextEditingController(text: opt.toString()));
        }
      }
      _correctIndex = q['correctIndex'] as int?;
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      if (_editingIndex == index) _resetForm();
      _questions.removeAt(index);
    });
  }

  void _resetForm() {
    setState(() {
      _editingIndex = null;
      _questionController.clear();
      for (final c in _optionControllers) {
        c.dispose();
      }
      _optionControllers.clear();
      if (_questionType == 'qcm') {
        _optionControllers.addAll([
          TextEditingController(),
          TextEditingController(),
        ]);
      }
      _correctIndex = null;
    });
  }

  /// Sauvegarde adaptée au schéma réel :
  /// id, evaluation_id, question, options, correct_index, created_at
  Future<void> _saveQuestions() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('questions')
          .delete()
          .eq('evaluation_id', widget.evaluationId);

      if (_questions.isNotEmpty) {
        final payload = _questions.map((q) {
          return {
            'evaluation_id': widget.evaluationId,
            'question': q['question'],
            'options': q['options'] ?? [],
            'correct_index': q['correctIndex'] ?? 0,
          };
        }).toList();

        await Supabase.instance.client.from('questions').insert(payload);
      }

      if (!mounted) return;
      _showSnackBar('Questions sauvegardées avec succès !', isError: false);
      context.pop(_questions);
    } catch (e) {
      _showSnackBar('Erreur lors de la sauvegarde : $e', isError: true);
      debugPrint('❌ Quiz save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? _C.red : _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text(
          'Gérer les questions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _C.textMain,
            fontSize: 18,
          ),
        ),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, color: _C.primary),
            onPressed: _isSaving ? null : _saveQuestions,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _editingIndex != null
                            ? _C.primary.withOpacity(0.5)
                            : _C.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _editingIndex != null
                                  ? Icons.edit_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: _editingIndex != null
                                  ? _C.primary
                                  : _C.textMain,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _editingIndex != null
                                  ? 'Modifier la question'
                                  : 'Nouvelle question',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _editingIndex != null
                                    ? _C.primary
                                    : _C.textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _questionType,
                          dropdownColor: _C.surface,
                          style: const TextStyle(
                            color: _C.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'qcm',
                              child: Text('QCM (Choix multiples)'),
                            ),
                            DropdownMenuItem(
                              value: 'vrai_faux',
                              child: Text('Vrai / Faux'),
                            ),
                            DropdownMenuItem(
                              value: 'ouverte',
                              child: Text('Question ouverte'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _questionType = v!;
                              for (final c in _optionControllers) {
                                c.dispose();
                              }
                              _optionControllers.clear();
                              if (_questionType == 'qcm') {
                                _optionControllers.addAll([
                                  TextEditingController(),
                                  TextEditingController(),
                                ]);
                              }
                              _correctIndex = null;
                            });
                          },
                          decoration: _inputDecoration(
                            'Type de question',
                            Icons.category_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _questionController,
                          maxLines: 3,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: _inputDecoration(
                            'Intitulé de la question*',
                            Icons.help_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_questionType == 'qcm') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Options de réponse',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _C.textMain,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addOptionField,
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: _C.primary,
                                ),
                                label: const Text(
                                  'Ajouter',
                                  style: TextStyle(
                                    color: _C.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._optionControllers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: _inputDecoration(
                                        'Option ${index + 1}',
                                        Icons.list_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Radio<int>(
                                    value: index,
                                    groupValue: _correctIndex,
                                    activeColor: _C.green,
                                    onChanged: (v) =>
                                        setState(() => _correctIndex = v),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: _C.red,
                                    ),
                                    onPressed: () => _removeOptionField(index),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (_questionType == 'vrai_faux') ...[
                          const Text(
                            'Réponse correcte :',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _C.textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<int>(
                                  value: 0,
                                  groupValue: _correctIndex,
                                  activeColor: _C.green,
                                  title: const Text(
                                    'Vrai',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _correctIndex = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<int>(
                                  value: 1,
                                  groupValue: _correctIndex,
                                  activeColor: _C.green,
                                  title: const Text(
                                    'Faux',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _correctIndex = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (_editingIndex != null)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: OutlinedButton(
                                    onPressed: _resetForm,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Annuler',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _C.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _submitQuestion,
                                icon: Icon(
                                  _editingIndex != null
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _editingIndex != null
                                      ? 'Mettre à jour'
                                      : 'Ajouter à la liste',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  backgroundColor: _editingIndex != null
                                      ? _C.green
                                      : _C.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Questions configurées (${_questions.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _C.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_questions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucune question ajoutée pour le moment.',
                          style: TextStyle(
                            color: _C.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final isEditing = _editingIndex == index;
                        return Container(
                          decoration: BoxDecoration(
                            color: isEditing
                                ? _C.primary.withOpacity(0.05)
                                : _C.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEditing ? _C.primary : _C.border,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _C.primary.withOpacity(0.12),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: _C.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              q['question'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _C.textMain,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                q['type'] == 'qcm'
                                    ? 'QCM • ${(q['options'] as List).join(', ')}'
                                    : q['type'] == 'vrai_faux'
                                        ? 'Vrai / Faux • ${q['correctIndex'] == 0 ? 'Vrai' : 'Faux'}'
                                        : 'Question ouverte',
                                style: const TextStyle(
                                  color: _C.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: _C.textMuted,
                                    size: 20,
                                  ),
                                  onPressed: () => _editQuestion(index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_rounded,
                                    color: _C.red,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeQuestion(index),
                                ),
                              ],
                            ),
                            onTap: () => _editQuestion(index),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _C.textMuted,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _C.textMuted, size: 20),
      filled: true,
      fillColor: _C.bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.primary, width: 1.5),
      ),
    );
  }
}
