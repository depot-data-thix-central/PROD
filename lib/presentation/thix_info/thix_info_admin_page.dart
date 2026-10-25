// lib/presentation/thix_info/thix_info_admin_page.dart
// ============================================================================
// ADMIN THIX INFO — Gestion des articles (CORRIGÉ)
//  • ✅ Lisibilité : Champs de saisie BLANCS avec texte SOMBRE
//  • ✅ Vidéo : Support complet par URL (affichage miniature + sauvegarde)
//  • ✅ Création / Édition / Suppression d'articles
//  • ✅ Gestion des flags : featured, breaking, statut (draft/published)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/news_article.dart';

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (Pour le fond sombre)
// ============================================================================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANT : CHAMP DE SAISIE CLAIR (Fond blanc, texte sombre)
// ============================================================================
class ClearInputBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const ClearInputBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.borderRadius = ThixPolicy.rMd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white, // ✅ FOND BLANC OPAQUE
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: child,
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE : ADMIN THIX INFO
// ============================================================================
class ThixInfoAdminPage extends ConsumerStatefulWidget {
  const ThixInfoAdminPage({super.key});

  @override
  ConsumerState<ThixInfoAdminPage> createState() => _ThixInfoAdminPageState();
}

class _ThixInfoAdminPageState extends ConsumerState<ThixInfoAdminPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<NewsArticle> _articles = [];
  bool _loading = true;
  String _filterStatus = 'all';
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('news_articles')
          .select('*')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      final list = (res as List).map((e) {
        return NewsArticle(
          id: e['id']?.toString() ?? '',
          title: e['title']?.toString() ?? '',
          summary: e['summary']?.toString(),
          content: e['content']?.toString() ?? '',
          category: e['category']?.toString() ?? '',
          imageUrl: e['image_url']?.toString(),
          videoUrl: e['video_url']?.toString(),
          viewsCount: (e['views_count'] as num?)?.toInt() ?? 0,
          isFeatured: e['is_featured'] == true,
          isBreaking: e['is_breaking'] == true,
          status: e['status']?.toString() ?? 'published',
          publishedAt: e['published_at'] != null
              ? DateTime.tryParse(e['published_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
          createdAt: e['created_at'] != null
              ? DateTime.tryParse(e['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
          createdBy: e['created_by']?.toString(),
        );
      }).toList();

      setState(() {
        _articles = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ThixInfoAdmin] ❌ Load error: $e');
      setState(() => _loading = false);
      _showError('Erreur lors du chargement');
    }
  }

  List<NewsArticle> get _filteredArticles {
    var list = _articles;
    if (_filterStatus != 'all') list = list.where((a) => a.status == _filterStatus).toList();
    if (_filterCategory != 'all') list = list.where((a) => a.category.toLowerCase() == _filterCategory.toLowerCase()).toList();
    
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.summary?.toLowerCase().contains(q) == true ||
          a.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _deleteArticle(NewsArticle article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.inkDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text('"${article.title}"\n\nAction irréversible.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabase.from('news_articles').delete().eq('id', article.id).timeout(const Duration(seconds: 10));
      setState(() => _articles.removeWhere((a) => a.id == article.id));
      _showSuccess('Article supprimé');
    } catch (e) {
      _showError('Erreur suppression');
    }
  }

  Future<void> _toggleFlag(NewsArticle article, String field, bool value) async {
    try {
      await _supabase.from('news_articles').update({field: value}).eq('id', article.id).timeout(const Duration(seconds: 10));
      setState(() {
        final idx = _articles.indexWhere((a) => a.id == article.id);
        if (idx != -1) {
          final u = _articles[idx];
          _articles[idx] = NewsArticle(
            id: u.id, title: u.title, summary: u.summary, content: u.content, category: u.category,
            imageUrl: u.imageUrl, videoUrl: u.videoUrl, viewsCount: u.viewsCount,
            isFeatured: field == 'is_featured' ? value : u.isFeatured,
            isBreaking: field == 'is_breaking' ? value : u.isBreaking,
            status: u.status, publishedAt: u.publishedAt, createdAt: u.createdAt, createdBy: u.createdBy,
          );
        }
      });
      _showSuccess('Mis à jour');
    } catch (e) {
      _showError('Erreur mise à jour');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
  }

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(dt);

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredArticles;
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.danger.withOpacity(0.1), boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.15), blurRadius: 100, spreadRadius: 100)]))),
          CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(),
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),
              SliverToBoxAdapter(child: _buildFilters()),
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
              if (_loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Colors.white))))
              else if (filtered.isEmpty) SliverToBoxAdapter(child: _buildEmpty())
              else SliverPadding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => _buildArticleCard(filtered[i]), childCount: filtered.length))),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          Positioned(
            bottom: ThixPolicy.s24, right: ThixPolicy.s24,
            child: FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const _ArticleFormPage()));
                if (created == true) _loadArticles();
              },
              backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvel article', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: ThixPolicy.inkDeep.withOpacity(0.8), elevation: 0, pinned: true,
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(6)), child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))),
        const SizedBox(width: 8),
        Text('THIX INFO', style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
      ]),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _loadArticles)],
      flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Column(
        children: [
          // Recherche : Fond blanc, texte sombre
          ClearInputBox(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600), // ✅ TEXTE SOMBRE
              decoration: InputDecoration(
                hintText: 'Rechercher un article...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: ThixPolicy.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey), onPressed: () { _searchCtrl.clear(); setState(() {}); }) : null,
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _filterDropdown(label: 'Statut', value: _filterStatus, items: const [{'value': 'all', 'label': 'Tous'}, {'value': 'published', 'label': 'Publiés'}, {'value': 'draft', 'label': 'Brouillons'}], onChanged: (v) => setState(() => _filterStatus = v ?? 'all'))),
              const SizedBox(width: 8),
              Expanded(child: _filterDropdown(label: 'Catégorie', value: _filterCategory, items: const [{'value': 'all', 'label': 'Toutes'}, {'value': 'politique', 'label': 'Politique'}, {'value': 'economie', 'label': 'Économie'}, {'value': 'societe', 'label': 'Société'}, {'value': 'tech', 'label': 'Tech'}, {'value': 'sport', 'label': 'Sport'}, {'value': 'culture', 'label': 'Culture'}, {'value': 'international', 'label': 'International'}, {'value': 'Magazine', 'label': 'Magazine'}, {'value': 'Podcast', 'label': 'Podcast'}, {'value': 'Découverte', 'label': 'Découverte'}], onChanged: (v) => setState(() => _filterCategory = v ?? 'all'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({required String label, required String value, required List<Map<String, String>> items, required ValueChanged<String?> onChanged}) {
    return GlassBox(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: 8),
      borderRadius: ThixPolicy.rMd,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true, dropdownColor: ThixPolicy.inkDeep,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
          items: items.map((item) => DropdownMenuItem(value: item['value'], child: Text(item['label']!, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [Icon(Icons.article_rounded, size: 56, color: Colors.white.withOpacity(0.3)), const SizedBox(height: 16), Text('Aucun article trouvé', style: ThixPolicy.h3Style.copyWith(color: Colors.white70)), const SizedBox(height: 8), Text('Créez votre premier article avec le bouton +', style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white38))])));
  }

  Widget _buildArticleCard(NewsArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
      child: GlassBox(
        padding: const EdgeInsets.all(ThixPolicy.s12), borderRadius: ThixPolicy.rMd,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rSm), child: SizedBox(width: 80, height: 80, child: article.imageUrl != null ? Image.network(article.imageUrl!, fit: BoxFit.cover) : Container(color: Colors.white.withOpacity(0.08), child: const Icon(Icons.article_rounded, color: Colors.white24, size: 32)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(article.category.toUpperCase(), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(_formatDate(article.createdAt), style: ThixPolicy.microStyle.copyWith(color: Colors.white38)),
            ])),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _badge(article.status == 'published' ? 'Publié' : 'Brouillon', article.status == 'published' ? ThixPolicy.success : ThixPolicy.warning),
            if (article.isFeatured) _badge('À la une', ThixPolicy.primary),
            if (article.isBreaking) _badge('Flash', ThixPolicy.danger),
            _badge('${article.viewsCount} vues', Colors.white24),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _actionChip(icon: article.isFeatured ? Icons.star_rounded : Icons.star_border_rounded, label: 'À la une', color: article.isFeatured ? ThixPolicy.primary : Colors.white24, onTap: () => _toggleFlag(article, 'is_featured', !article.isFeatured)),
            const SizedBox(width: 8),
            _actionChip(icon: article.isBreaking ? Icons.flash_on_rounded : Icons.flash_off_rounded, label: 'Flash', color: article.isBreaking ? ThixPolicy.danger : Colors.white24, onTap: () => _toggleFlag(article, 'is_breaking', !article.isBreaking)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.edit_rounded, color: ThixPolicy.primary, size: 20), onPressed: () async { final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _ArticleFormPage(article: article))); if (updated == true) _loadArticles(); }),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 20), onPressed: () => _deleteArticle(article)),
          ]),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)));
  }

  Widget _actionChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))])));
  }
}

// ============================================================================
// FORMULAIRE CRÉATION / ÉDITION (CORRIGÉ : LISIBILITÉ + VIDÉO)
// ============================================================================
class _ArticleFormPage extends ConsumerStatefulWidget {
  final NewsArticle? article;
  const _ArticleFormPage({this.article});

  @override
  ConsumerState<_ArticleFormPage> createState() => _ArticleFormPageState();
}

class _ArticleFormPageState extends ConsumerState<_ArticleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();

  String _category = 'politique';
  String _status = 'published';
  bool _isFeatured = false;
  bool _isBreaking = false;
  bool _saving = false;
  String? _imageBase64;

  bool get _isEditing => widget.article != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.article!;
      _titleCtrl.text = a.title;
      _summaryCtrl.text = a.summary ?? '';
      _contentCtrl.text = a.content;
      _category = a.category;
      _imageUrlCtrl.text = a.imageUrl ?? '';
      _videoUrlCtrl.text = a.videoUrl ?? ''; // ✅ Chargement URL vidéo existante
      _status = a.status;
      _isFeatured = a.isFeatured;
      _isBreaking = a.isBreaking;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _summaryCtrl.dispose(); _contentCtrl.dispose(); _imageUrlCtrl.dispose(); _videoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    } catch (e) { debugPrint('[ArticleForm] ❌ Pick image error: $e'); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('Non authentifié');

      final payload = {
        'title': _titleCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'category': _category,
        'image_url': _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim(),
        'video_url': _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(), // ✅ Sauvegarde URL vidéo
        'status': _status,
        'is_featured': _isFeatured,
        'is_breaking': _isBreaking,
        'published_at': _status == 'published' ? DateTime.now().toIso8601String() : null,
      };

      if (_isEditing) {
        await _supabase.from('news_articles').update(payload).eq('id', widget.article!.id).timeout(const Duration(seconds: 20));
      } else {
        payload['id'] = const Uuid().v4();
        payload['created_by'] = uid;
        payload['created_at'] = DateTime.now().toIso8601String();
        payload['views_count'] = 0;
        await _supabase.from('news_articles').insert(payload).timeout(const Duration(seconds: 20));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Article mis à jour ✅' : 'Article créé ✅'), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[ArticleForm] ❌ Save error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString().split('\n').first}'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context, false)),
        title: Text(_isEditing ? 'Modifier l\'article' : 'Nouvel article', style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        actions: [TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement...' : 'Enregistrer', style: TextStyle(color: _saving ? Colors.white38 : ThixPolicy.primary, fontWeight: FontWeight.w800)))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(ThixPolicy.s16), children: [
          _buildMediaSection(), // ✅ Section combinée Image + Vidéo
          const SizedBox(height: 20),
          _buildField(controller: _titleCtrl, label: 'Titre *', hint: 'Titre de l\'article', maxLines: 2, validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis' : null),
          const SizedBox(height: 16),
          _buildField(controller: _summaryCtrl, label: 'Résumé', hint: 'Résumé court (optionnel)', maxLines: 3),
          const SizedBox(height: 16),
          _buildField(controller: _contentCtrl, label: 'Contenu *', hint: 'Contenu complet de l\'article', maxLines: 12, validator: (v) => (v == null || v.trim().isEmpty) ? 'Contenu requis' : null),
          const SizedBox(height: 16),
          _buildDropdown(label: 'Catégorie *', value: _category, items: const ['politique', 'economie', 'societe', 'tech', 'sport', 'culture', 'international', 'Magazine', 'Podcast', 'Découverte'], onChanged: (v) => setState(() => _category = v ?? 'politique')),
          const SizedBox(height: 16),
          // Les champs URL sont désormais gérés dans _buildMediaSection pour plus de clarté, 
          // mais on garde les contrôleurs synchronisés si besoin d'édition directe.
          // Ici on affiche juste un indicateur ou on laisse l'utilisateur éditer dans la section média.
          // Pour simplifier, on retire les champs texte URL bruts ici et on les met dans la section visuelle.
          
          const SizedBox(height: 16),
          _buildDropdown(label: 'Statut', value: _status, items: const ['published', 'draft'], onChanged: (v) => setState(() => _status = v ?? 'published')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildToggle(label: 'À la une', value: _isFeatured, onChanged: (v) => setState(() => _isFeatured = v))),
            const SizedBox(width: 12),
            Expanded(child: _buildToggle(label: 'Flash info', value: _isBreaking, onChanged: (v) => setState(() => _isBreaking = v))),
          ]),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ✅ SECTION MÉDIA UNIFIÉE (IMAGE + VIDÉO URL)
  Widget _buildMediaSection() {
    final hasImage = _imageBase64 != null || (_isEditing && widget.article!.imageUrl != null);
    final hasVideo = _videoUrlCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Médias (Image & Vidéo)', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        
        // Zone principale : Affiche l'image ou la vidéo
        GestureDetector(
          onTap: _pickImage, // Tap pour changer l'image
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, // ✅ Fond blanc pour la zone média aussi
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imageBase64 != null)
                  ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rMd), child: Image.memory(base64Decode(_imageBase64!.split(',').last), fit: BoxFit.cover))
                else if (_isEditing && widget.article!.imageUrl != null && _imageBase64 == null)
                  ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rMd), child: Image.network(widget.article!.imageUrl!, fit: BoxFit.cover))
                else if (hasVideo)
                  // ✅ Affichage miniature vidéo si URL présente
                  Container(
                    color: Colors.black12,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, size: 48, color: ThixPolicy.primary),
                          const SizedBox(height: 8),
                          Text('Vidéo chargée', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_videoUrlCtrl.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                  )
                else
                  const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 40), SizedBox(height: 8), Text('Toucher pour ajouter une image', style: TextStyle(color: Colors.grey, fontSize: 12))])),
                
                // Badge type
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: hasVideo ? Colors.orange : Colors.blue, borderRadius: BorderRadius.circular(6)),
                    child: Text(hasVideo ? 'VIDÉO' : 'IMAGE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Champ URL Vidéo dédié
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('URL de la vidéo (YouTube, Vimeo, MP4...)', style: ThixPolicy.captionStyle.copyWith(color: Colors.white70)),
            const SizedBox(height: 6),
            ClearInputBox( // ✅ Fond blanc, texte sombre
              child: TextField(
                controller: _videoUrlCtrl,
                style: const TextStyle(color: Colors.black87, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.video_library_rounded, size: 18, color: ThixPolicy.primary),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}), // Rafraîchir l'aperçu
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClearInputBox( // ✅ Fond blanc, texte sombre
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600), // ✅ TEXTE SOMBRE
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GlassBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          borderRadius: ThixPolicy.rMd,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value, isExpanded: true, dropdownColor: ThixPolicy.inkDeep,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? ThixPolicy.primary.withOpacity(0.2) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: value ? ThixPolicy.primary : Colors.white.withOpacity(0.15)),
        ),
        child: Row(children: [
          Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: value ? ThixPolicy.primary : Colors.white38, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: value ? Colors.white : Colors.white54, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}
