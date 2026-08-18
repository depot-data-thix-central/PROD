// lib/presentation/mon_pays/admin/admin_articles_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/articles_provider.dart';
import '../models/article.dart';

// Import de la page du formulaire (doit être dans le même dossier)
import 'admin_article_form_page.dart';

class AdminArticlesPage extends ConsumerStatefulWidget {
  const AdminArticlesPage({super.key});

  @override
  ConsumerState<AdminArticlesPage> createState() => _AdminArticlesPageState();
}

class _AdminArticlesPageState extends ConsumerState<AdminArticlesPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration des articles'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(adminArticlesProvider.notifier).loadArticles();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminArticleFormPage()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedType,
                  hint: const Text('Type'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    ...ArticleType.values.map((type) {
                      return DropdownMenuItem(
                        value: type.toString().split('.').last,
                        child: Text(type.label),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                    final type = value != null ? ArticleType.fromString(value) : null;
                    ref.read(adminArticlesProvider.notifier).loadArticles(
                      type: type,
                      search: _searchQuery,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: adminState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(child: Text('Aucun article. Créez-en un !'));
          }
          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (_, i) {
              final a = articles[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    a.isPublished ? Icons.public : Icons.lock,
                    color: a.isPublished ? Colors.green : Colors.orange,
                  ),
                  title: Text(a.title),
                  subtitle: Text('${a.type.label} ${a.articleNumber ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          a.isPublished ? Icons.visibility : Icons.visibility_off,
                          color: a.isPublished ? Colors.green : Colors.grey,
                        ),
                        onPressed: () {
                          if (a.isPublished) {
                            ref.read(adminArticlesProvider.notifier).unpublishArticle(a.id);
                          } else {
                            ref.read(adminArticlesProvider.notifier).publishArticle(a.id);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminArticleFormPage(article: a),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteConfirmation(a.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous supprimer cet article ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminArticlesProvider.notifier).deleteArticle(id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
