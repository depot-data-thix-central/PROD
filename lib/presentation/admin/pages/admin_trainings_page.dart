import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

class AdminTrainingsPage extends StatefulWidget {
  const AdminTrainingsPage({super.key});

  @override
  State<AdminTrainingsPage> createState() => _AdminTrainingsPageState();
}

class _AdminTrainingsPageState extends State<AdminTrainingsPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _trainings = [];
  List<dynamic> _modules = [];
  List<dynamic> _lessons = [];
  List<dynamic> _quizQuestions = [];
  List<dynamic> _resources = [];
  bool _loading = true;
  String? _selectedTrainingId;
  String? _selectedModuleId;
  String? _selectedLessonId;
  int _tabIndex = 0;

  // Dialog controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _levelCtrl = TextEditingController(text: 'Beginner');
  final _priceCtrl = TextEditingController(text: '0');
  final _moduleTitleCtrl = TextEditingController();
  final _moduleIndexCtrl = TextEditingController();
  final _lessonTitleCtrl = TextEditingController();
  final _lessonDescCtrl = TextEditingController();
  final _lessonIndexCtrl = TextEditingController();
  final _lessonDurationCtrl = TextEditingController();
  final _quizQuestionCtrl = TextEditingController();
  final _quizOptionsCtrl = TextEditingController();
  final _quizExplanationCtrl = TextEditingController();
  final _resourceTitleCtrl = TextEditingController();

  bool _isFree = true;
  bool _certIncluded = true;
  bool _isPublished = false;
  bool _isFeatured = false;
  String _contentType = 'video';
  int _quizCorrectIndex = 0;

  // Preview video
  VideoPlayerController? _previewController;
  bool _previewInitialized = false;

  static const _brandColor = Color(0xFF6366F1);
  static const _accentColor = Color(0xFFEEF2FF);
  static const _textDark = Color(0xFF1E293B);
  static const _textGrey = Color(0xFF64748B);
  static const _successColor = Color(0xFF10B981);
  static const _errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _levelCtrl.dispose();
    _priceCtrl.dispose();
    _moduleTitleCtrl.dispose();
    _moduleIndexCtrl.dispose();
    _lessonTitleCtrl.dispose();
    _lessonDescCtrl.dispose();
    _lessonIndexCtrl.dispose();
    _lessonDurationCtrl.dispose();
    _quizQuestionCtrl.dispose();
    _quizOptionsCtrl.dispose();
    _quizExplanationCtrl.dispose();
    _resourceTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrainings() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('thix_trainings')
          .select('*')
          .order('created_at', ascending: false);
      setState(() => _trainings = res is List ? res : []);
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadModules(String trainingId) async {
    try {
      final res = await _supabase
          .from('training_modules')
          .select('*')
          .eq('training_id', trainingId)
          .order('module_index');
      setState(() => _modules = res is List ? res : []);
    } catch (e) {
      debugPrint('Error loading modules: $e');
    }
  }

  Future<void> _loadLessons(String moduleId) async {
    try {
      final res = await _supabase
          .from('training_lessons')
          .select('*')
          .eq('module_id', moduleId)
          .order('lesson_index');
      setState(() => _lessons = res is List ? res : []);
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    }
  }

  Future<void> _loadQuiz(String lessonId) async {
    try {
      final res = await _supabase
          .from('quiz_questions')
          .select('*')
          .eq('lesson_id', lessonId);
      setState(() => _quizQuestions = res is List ? res : []);
    } catch (e) {
      debugPrint('Error loading quiz: $e');
    }
  }

  Future<void> _loadResources(String lessonId) async {
    try {
      final res = await _supabase
          .from('lesson_resources')
          .select('*')
          .eq('lesson_id', lessonId);
      setState(() => _resources = res is List ? res : []);
    } catch (e) {
      debugPrint('Error loading resources: $e');
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _errorColor : _successColor,
      ),
    );
  }

  void _showCreateTrainingDialog() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _categoryCtrl.clear();
    _levelCtrl.text = 'Beginner';
    _priceCtrl.text = '0';
    _isFree = true;
    _certIncluded = true;
    _isPublished = false;
    _isFeatured = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Créer une Formation', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titre *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryCtrl,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _levelCtrl.text,
                    items: const [
                      DropdownMenuItem(value: 'Beginner', child: Text('Débutant')),
                      DropdownMenuItem(value: 'Intermediate', child: Text('Intermédiaire')),
                      DropdownMenuItem(value: 'Advanced', child: Text('Avancé')),
                    ],
                    onChanged: (v) => setDialogState(() => _levelCtrl.text = v!),
                    decoration: const InputDecoration(labelText: 'Niveau'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _isFree,
                    onChanged: (v) => setDialogState(() => _isFree = v ?? false),
                    title: const Text('Formation Gratuite'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_isFree)
                    TextField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: 'Prix'),
                      keyboardType: TextInputType.number,
                    ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _certIncluded,
                    onChanged: (v) => setDialogState(() => _certIncluded = v ?? false),
                    title: const Text('Certificat Inclus'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isPublished,
                    onChanged: (v) => setDialogState(() => _isPublished = v),
                    title: const Text('Publié'),
                    activeColor: _successColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (_titleCtrl.text.trim().isEmpty) {
                  _showSnackBar('Titre requis', isError: true);
                  return;
                }
                try {
                  await _supabase.from('thix_trainings').insert({
                    'title': _titleCtrl.text.trim(),
                    'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                    'category': _categoryCtrl.text.trim().isEmpty ? 'General' : _categoryCtrl.text.trim(),
                    'level': _levelCtrl.text,
                    'language': 'FR',
                    'delivery_mode': 'online',
                    'is_free': _isFree,
                    'price_amount': _isFree ? 0 : double.tryParse(_priceCtrl.text) ?? 0,
                    'currency': 'USD',
                    'certification_included': _certIncluded,
                    'is_featured': _isFeatured,
                    'is_published': _isPublished,
                  });
                  Navigator.pop(context);
                  _loadTrainings();
                  _showSnackBar('Formation créée!');
                } catch (e) {
                  _showSnackBar('Erreur: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateModuleDialog() {
    if (_selectedTrainingId == null) return;
    _moduleTitleCtrl.clear();
    _moduleIndexCtrl.text = (_modules.length + 1).toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un Module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _moduleTitleCtrl,
              decoration: const InputDecoration(labelText: 'Titre du Module *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _moduleIndexCtrl,
              decoration: const InputDecoration(labelText: 'Position (Module #)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (_moduleTitleCtrl.text.trim().isEmpty) {
                _showSnackBar('Titre requis', isError: true);
                return;
              }
              try {
                await _supabase.from('training_modules').insert({
                  'training_id': _selectedTrainingId,
                  'title': _moduleTitleCtrl.text.trim(),
                  'module_index': int.tryParse(_moduleIndexCtrl.text) ?? (_modules.length + 1),
                });
                Navigator.pop(context);
                _loadModules(_selectedTrainingId!);
                _showSnackBar('Module ajouté!');
              } catch (e) {
                _showSnackBar('Erreur: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateLessonDialog() {
    if (_selectedModuleId == null) return;
    _lessonTitleCtrl.clear();
    _lessonDescCtrl.clear();
    _lessonIndexCtrl.text = (_lessons.length + 1).toString();
    _lessonDurationCtrl.text = '30';
    _contentType = 'video';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une Leçon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _lessonTitleCtrl,
                decoration: const InputDecoration(labelText: 'Titre de la Leçon *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lessonDescCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lessonIndexCtrl,
                      decoration: const InputDecoration(labelText: 'Position #'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lessonDurationCtrl,
                      decoration: const InputDecoration(labelText: 'Durée (min)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _contentType,
                items: const [
                  DropdownMenuItem(value: 'video', child: Text('🎬 Vidéo')),
                  DropdownMenuItem(value: 'document', child: Text('📄 Document')),
                  DropdownMenuItem(value: 'quiz', child: Text('❓ Quiz')),
                ],
                onChanged: (v) => setDialogState(() => _contentType = v!),
                decoration: const InputDecoration(labelText: 'Type de contenu'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (_lessonTitleCtrl.text.trim().isEmpty) {
                  _showSnackBar('Titre requis', isError: true);
                  return;
                }
                try {
                  await _supabase.from('training_lessons').insert({
                    'module_id': _selectedModuleId,
                    'title': _lessonTitleCtrl.text.trim(),
                    'description': _lessonDescCtrl.text.trim().isEmpty ? null : _lessonDescCtrl.text.trim(),
                    'lesson_index': int.tryParse(_lessonIndexCtrl.text) ?? (_lessons.length + 1),
                    'content_type': _contentType,
                    'duration_minutes': int.tryParse(_lessonDurationCtrl.text) ?? 30,
                    'is_preview': false,
                  });
                  Navigator.pop(context);
                  _loadLessons(_selectedModuleId!);
                  _showSnackBar('Leçon ajoutée!');
                } catch (e) {
                  _showSnackBar('Erreur: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
              child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadVideo(String lessonId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
      allowedExtensions: ['mp4', 'mov'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final ext = file.name.split('.').last;
    final path = 'training_videos/$lessonId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        await _supabase.storage.from('training_videos').uploadBinary(path, file.bytes!);
      } else {
        final fileBytes = await File(file.path!).readAsBytes();
        await _supabase.storage.from('training_videos').uploadBinary(path, fileBytes);
      }
      final videoUrl = _supabase.storage.from('training_videos').getPublicUrl(path);
      await _supabase.from('training_lessons').update({'content_url': videoUrl}).eq('id', lessonId);
      _loadLessons(_selectedModuleId!);
      _showSnackBar('Vidéo uploadée!');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _previewVideo(String url) {
    if (_previewController != null) {
      _previewController!.dispose();
    }
    _previewController = VideoPlayerController.networkUrl(Uri.parse(url));
    _previewController!.initialize().then((_) {
      setState(() => _previewInitialized = true);
      _previewController!.play();
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 640,
          height: 360,
          child: _previewInitialized
              ? VideoPlayer(_previewController!)
              : const Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _previewController?.pause();
              Navigator.pop(context);
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String table, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Supprimer définitivement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from(table).delete().eq('id', id);
      if (table == 'thix_trainings') {
        _loadTrainings();
      } else if (table == 'training_modules') {
        _loadModules(_selectedTrainingId!);
      } else if (table == 'training_lessons') {
        _loadLessons(_selectedModuleId!);
      }
      _showSnackBar('Supprimé');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  Future<void> _togglePublish(String id, bool currentValue) async {
    try {
      await _supabase.from('thix_trainings').update({'is_published': !currentValue}).eq('id', id);
      _loadTrainings();
      _showSnackBar(!currentValue ? 'Publiée !' : 'Dépubliée');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Formations'),
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadTrainings, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _showCreateTrainingDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Liste des formations
                Container(
                  width: 280,
                  color: const Color(0xFFF8FAFC),
                  child: ListView.builder(
                    itemCount: _trainings.length,
                    itemBuilder: (context, i) {
                      final t = _trainings[i];
                      final isSelected = t['id'] == _selectedTrainingId;
                      final isPublished = t['is_published'] ?? false;
                      return Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? _brandColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? _brandColor : Colors.grey.shade200),
                        ),
                        child: ListTile(
                          title: Text(
                            t['title'] ?? 'Sans titre',
                            style: TextStyle(color: isSelected ? Colors.white : _textDark),
                          ),
                          subtitle: Text(
                            t['is_free'] == true ? 'Gratuit' : '${t['price_amount'] ?? 0} USD',
                            style: TextStyle(color: isSelected ? Colors.white70 : _textGrey, fontSize: 12),
                          ),
                          trailing: GestureDetector(
                            onTap: () => _togglePublish(t['id'], isPublished),
                            child: Icon(
                              isPublished ? Icons.visibility : Icons.visibility_off,
                              color: isSelected ? Colors.white : (isPublished ? _successColor : _errorColor),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedTrainingId = t['id'];
                              _selectedModuleId = null;
                              _selectedLessonId = null;
                            });
                            _loadModules(t['id']);
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Détails
                Expanded(
                  child: _selectedTrainingId == null
                      ? const Center(child: Text('Sélectionnez une formation'))
                      : _buildDetailContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailContent() {
    if (_selectedTrainingId == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Tabs
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey))),
          child: Row(
            children: [
              _buildTab('Modules', 0),
              _buildTab('Quiz', 1),
              _buildTab('Ressources', 2),
            ],
          ),
        ),
        Expanded(
          child: _tabIndex == 0 ? _buildModulesTab() : (_tabIndex == 1 ? _buildQuizTab() : _buildResourcesTab()),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _tabIndex == index ? _brandColor : Colors.transparent, width: 2)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: _tabIndex == index ? _brandColor : _textGrey)),
          ),
        ),
      ),
    );
  }

  Widget _buildModulesTab() {
    return Row(
      children: [
        // Modules
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Modules (${_modules.length})'),
                      IconButton(onPressed: _showCreateModuleDialog, icon: const Icon(Icons.add)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _modules.length,
                    itemBuilder: (context, i) {
                      final m = _modules[i];
                      return ListTile(
                        title: Text('${m['module_index']}. ${m['title']}'),
                        selected: m['id'] == _selectedModuleId,
                        onTap: () {
                          setState(() {
                            _selectedModuleId = m['id'];
                            _selectedLessonId = null;
                          });
                          _loadLessons(m['id']);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: _errorColor),
                          onPressed: () => _deleteItem('training_modules', m['id']),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Leçons
        Expanded(
          child: _selectedModuleId == null
              ? const Center(child: Text('Sélectionnez un module'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Leçons (${_lessons.length})'),
                          ElevatedButton.icon(
                            onPressed: _showCreateLessonDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter'),
                            style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _lessons.length,
                        itemBuilder: (context, i) {
                          final l = _lessons[i];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text('${l['lesson_index']}. ${l['title']}'),
                              subtitle: Text('${l['duration_minutes']} min • ${l['content_type']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (l['content_type'] == 'video' && l['content_url'] == null)
                                    IconButton(
                                      icon: const Icon(Icons.cloud_upload, color: Colors.orange),
                                      onPressed: () => _uploadVideo(l['id']),
                                    ),
                                  if (l['content_url'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.play_circle, color: _brandColor),
                                      onPressed: () => _previewVideo(l['content_url']),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: _errorColor),
                                    onPressed: () => _deleteItem('training_lessons', l['id']),
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedLessonId = l['id'];
                                });
                                _loadQuiz(l['id']);
                                _loadResources(l['id']);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildQuizTab() {
    if (_selectedLessonId == null) {
      return const Center(child: Text('Sélectionnez d\'abord une leçon'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Questions (${_quizQuestions.length})'),
              ElevatedButton(
                onPressed: () => _showAddQuizDialog(),
                style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
                child: const Text('Ajouter Question'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _quizQuestions.length,
            itemBuilder: (context, i) {
              final q = _quizQuestions[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(q['question'] ?? ''),
                  subtitle: Text('Options: ${(q['options'] as List).join(' | ')}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: _errorColor),
                    onPressed: () => _deleteQuizQuestion(q['id']),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResourcesTab() {
    if (_selectedLessonId == null) {
      return const Center(child: Text('Sélectionnez d\'abord une leçon'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ressources (${_resources.length})'),
              ElevatedButton(
                onPressed: () => _uploadResource(),
                style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
                child: const Text('Ajouter Ressource'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _resources.length,
            itemBuilder: (context, i) {
              final r = _resources[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.attachment),
                  title: Text(r['title'] ?? ''),
                  subtitle: Text(r['type'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: _errorColor),
                    onPressed: () => _deleteResource(r['id']),
                  ),
                  onTap: () => _previewVideo(r['url']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddQuizDialog() {
    _quizQuestionCtrl.clear();
    _quizOptionsCtrl.clear();
    _quizExplanationCtrl.clear();
    _quizCorrectIndex = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une Question'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _quizQuestionCtrl,
                decoration: const InputDecoration(labelText: 'Question'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizOptionsCtrl,
                decoration: const InputDecoration(labelText: 'Options (séparées par |)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _quizCorrectIndex,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Option 1')),
                  DropdownMenuItem(value: 1, child: Text('Option 2')),
                  DropdownMenuItem(value: 2, child: Text('Option 3')),
                  DropdownMenuItem(value: 3, child: Text('Option 4')),
                ],
                onChanged: (v) => _quizCorrectIndex = v ?? 0,
                decoration: const InputDecoration(labelText: 'Bonne réponse'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizExplanationCtrl,
                decoration: const InputDecoration(labelText: 'Explication'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final options = _quizOptionsCtrl.text.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              try {
                await _supabase.from('quiz_questions').insert({
                  'lesson_id': _selectedLessonId,
                  'question': _quizQuestionCtrl.text,
                  'options': options,
                  'correct_option_index': _quizCorrectIndex,
                  'explanation': _quizExplanationCtrl.text,
                });
                Navigator.pop(context);
                _loadQuiz(_selectedLessonId!);
                _showSnackBar('Question ajoutée!');
              } catch (e) {
                _showSnackBar('Erreur: $e', isError: true);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadResource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: kIsWeb,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final ext = file.name.split('.').last;
    final path = 'training_resources/$_selectedLessonId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        await _supabase.storage.from('training_resources').uploadBinary(path, file.bytes!);
      } else {
        final fileBytes = await File(file.path!).readAsBytes();
        await _supabase.storage.from('training_resources').uploadBinary(path, fileBytes);
      }
      final resourceUrl = _supabase.storage.from('training_resources').getPublicUrl(path);
      await _supabase.from('lesson_resources').insert({
        'lesson_id': _selectedLessonId,
        'title': file.name,
        'type': ext,
        'url': resourceUrl,
        'file_size': file.size,
      });
      _loadResources(_selectedLessonId!);
      _showSnackBar('Ressource ajoutée!');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteQuizQuestion(String id) async {
    try {
      await _supabase.from('quiz_questions').delete().eq('id', id);
      _loadQuiz(_selectedLessonId!);
      _showSnackBar('Question supprimée');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  Future<void> _deleteResource(String id) async {
    try {
      await _supabase.from('lesson_resources').delete().eq('id', id);
      _loadResources(_selectedLessonId!);
      _showSnackBar('Ressource supprimée');
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }
}
