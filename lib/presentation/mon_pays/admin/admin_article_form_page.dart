// lib/presentation/mon_pays/admin/admin_article_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/article.dart';
import '../providers/articles_provider.dart';

class AdminArticleFormPage extends HookConsumerWidget {
  final Article? article;

  const AdminArticleFormPage({super.key, this.article});

  // ============================================================
  // CHARTE INSTITUTIONNELLE THIX ID
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color rdcRed = Color(0xFFCE1126);
  static const Color hairline = Color(0xFFE7EAF3);
  static const Color success = Color(0xFF1FA971);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = article != null;
    
    // ─── 1. INITIALISATION DES HOOKS (ÉTATS & CONTRÔLEURS) ────────
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isSubmitting = useState(false);

    // Méta-données
    final titleCtrl = useTextEditingController(text: article?.title ?? '');
    final chapterCtrl = useTextEditingController(text: article?.chapter ?? '');
    final articleNumCtrl = useTextEditingController(text: article?.articleNumber ?? '');
    
    // Type d'article (Enum ou String selon votre implémentation)
    final typeState = useState<String?>(
      article != null ? article!.type.toString().split('.').last : null,
    );

    // Textes - Français (FR)
    final contentFrCtrl = useTextEditingController(text: article?.content ?? '');
    final explanationFrCtrl = useTextEditingController(text: article?.explanation ?? '');
    
    // Textes - Lingala (LN) & Swahili (SW) (Préparés pour votre backend)
    final contentLnCtrl = useTextEditingController();
    final explanationLnCtrl = useTextEditingController();
    final contentSwCtrl = useTextEditingController();
    final explanationSwCtrl = useTextEditingController();

    // Publication & Onglet actif
    final isPublished = useState<bool>(article?.isPublished ?? false);
    final activeLangTab = useState<String>('FR');

    // ─── 2. FONCTION DE SAUVEGARDE ────────────────────────────────
    Future<void> save() async {
      if (!formKey.currentState!.validate() || typeState.value == null) {
        _showSnackBar(context, 'Veuillez remplir tous les champs obligatoires.', isError: true);
        return;
      }

      isSubmitting.value = true;

      try {
        // ⚠️ TODO: Adaptez si votre modèle Article gère désormais contentLn, contentSw, etc.
        final newArticle = Article(
          id: article?.id ?? '', // Chaîne vide gérée par le backend/modèle pour création
          type: ArticleType.values.firstWhere((e) => e.toString().split('.').last == typeState.value),
          title: titleCtrl.text.trim(),
          chapter: chapterCtrl.text.trim().isEmpty ? null : chapterCtrl.text.trim(),
          articleNumber: articleNumCtrl.text.trim().isEmpty ? null : articleNumCtrl.text.trim(),
          content: contentFrCtrl.text.trim(),
          explanation: explanationFrCtrl.text.trim().isEmpty ? null : explanationFrCtrl.text.trim(),
          isPublished: isPublished.value,
        );

        final notifier = ref.read(adminArticlesProvider.notifier);
        
        if (isEditing) {
          await notifier.updateArticle(newArticle);
          _showSnackBar(context, 'Article modifié avec succès.');
        } else {
          await notifier.createArticle(newArticle);
          _showSnackBar(context, 'Article créé avec succès.');
        }

        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) _showSnackBar(context, 'Erreur: ${e.toString()}', isError: true);
      } finally {
        isSubmitting.value = false;
      }
    }

    // ─── 3. INTERFACE UTILISATEUR (UI) ────────────────────────────
    return Scaffold(
      backgroundColor: ivory,
      appBar: _buildAppBar(isEditing),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1 : Informations Générales
                      _buildSectionTitle(Icons.info_outline_rounded, 'Informations Générales'),
                      _buildCard(
                        child: Column(
                          children: [
                            _buildDropdown(typeState),
                            const SizedBox(height: 16),
                            _buildTextField(titleCtrl, 'Titre de l\'article *', isRequired: true),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(chapterCtrl, 'Chapitre (ex: I, II)')),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTextField(articleNumCtrl, 'N° Article (ex: 14)')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 2 : Contenu & Traductions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(Icons.translate_rounded, 'Contenu & Traductions'),
                          _buildLanguageTabs(activeLangTab),
                        ],
                      ),
                      _buildCard(
                        child: Column(
                          children: [
                            // Affichage conditionnel des contrôleurs selon la langue
                            if (activeLangTab.value == 'FR') ...[
                              _buildTextField(contentFrCtrl, 'Contenu (Français) *', isRequired: true, maxLines: 8),
                              const SizedBox(height: 16),
                              _buildTextField(explanationFrCtrl, 'Explication (Français)', maxLines: 4),
                            ] else if (activeLangTab.value == 'LN') ...[
                              _buildTextField(contentLnCtrl, 'Contenu (Lingala)', maxLines: 8),
                              const SizedBox(height: 16),
                              _buildTextField(explanationLnCtrl, 'Explication (Lingala)', maxLines: 4),
                            ] else ...[
                              _buildTextField(contentSwCtrl, 'Contenu (Swahili)', maxLines: 8),
                              const SizedBox(height: 16),
                              _buildTextField(explanationSwCtrl, 'Explication (Swahili)', maxLines: 4),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 3 : Paramètres de publication
                      _buildSectionTitle(Icons.settings_rounded, 'Paramètres'),
                      _buildCard(
                        padding: const EdgeInsets.all(8),
                        child: SwitchListTile(
                          title: const Text('Statut de publication', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(
                            isPublished.value ? 'Visible par le public' : 'Enregistré comme brouillon',
                            style: TextStyle(color: isPublished.value ? success : mutedText, fontSize: 12),
                          ),
                          activeColor: success,
                          value: isPublished.value,
                          onChanged: (val) => isPublished.value = val,
                        ),
                      ),
                      const SizedBox(height: 100), // Espace pour le bouton collé en bas
                    ],
                  ),
                ),
              ),
            ),
            
            // ─── BOUTON DE SAUVEGARDE COLLÉ EN BAS ────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pureWhite,
                border: Border(top: BorderSide(color: hairline)),
                boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: ElevatedButton(
                onPressed: isSubmitting.value ? null : save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: navyDeep,
                  foregroundColor: gold,
                  disabledBackgroundColor: navyDeep.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: isSubmitting.value
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: gold, strokeWidth: 2.5))
                    : Text(
                        isEditing ? 'ENREGISTRER LES MODIFICATIONS' : 'PUBLIER L\'ARTICLE',
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPOSANTS UI RÉUTILISABLES (Enterprise Pattern)
  // ============================================================

  PreferredSizeWidget _buildAppBar(bool isEditing) {
    return AppBar(
      backgroundColor: navyDeep,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        isEditing ? 'Modifier l\'article' : 'Nouvel Article',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      actions: [
        if (isEditing)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gold),
            ),
            child: const Center(
              child: Text('MODE ÉDITION', style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: navy),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navyDeep)),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
        boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildLanguageTabs(ValueNotifier<String> activeTab) {
    return Container(
      decoration: BoxDecoration(color: hairline, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['FR', 'LN', 'SW'].map((lang) {
          final isSelected = activeTab.value == lang;
          return GestureDetector(
            onTap: () => activeTab.value = lang,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? navyDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? gold : mutedText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: darkText, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: mutedText, fontSize: 13),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: ivory,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: rdcRed)),
      ),
      validator: isRequired ? (v) => v?.trim().isEmpty ?? true ? 'Ce champ est obligatoire' : null : null,
    );
  }

  Widget _buildDropdown(ValueNotifier<String?> typeState) {
    return DropdownButtonFormField<String>(
      value: typeState.value,
      style: const TextStyle(fontSize: 14, color: darkText, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Type de document *',
        labelStyle: const TextStyle(color: mutedText, fontSize: 13),
        filled: true,
        fillColor: ivory,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy, width: 1.5)),
      ),
      items: ArticleType.values.map((type) {
        return DropdownMenuItem(
          value: type.toString().split('.').last,
          child: Text(type.label),
        );
      }).toList(),
      onChanged: (value) => typeState.value = value,
      validator: (v) => v == null ? 'Veuillez sélectionner un type' : null,
    );
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: isError ? rdcRed : success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
