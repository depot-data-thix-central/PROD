import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/news_provider.dart';

const _kBorder = Color(0xFFECEEF4);
const _kGold = Color(0xFFFFB800);
const _kDark = Color(0xFF101840);
const _kBg = Color(0xFFF7F8FB);

class AdminArticlesListPage extends StatefulWidget {
  const AdminArticlesListPage({super.key});
  @override
  State<AdminArticlesListPage> createState() => _AdminArticlesListPageState();
}

class _AdminArticlesListPageState extends State<AdminArticlesListPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await context.read<NewsProvider>().fetchArticles(category: 'all');
    } catch (e) {
      debugPrint('❌ Erreur load admin: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final articles = context.watch<NewsProvider>().articles;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Gérer Articles', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: _kDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await context.push('/admin/articles/new');
              _load();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : RefreshIndicator(
              onRefresh: _load,
              color: _kGold,
              child: articles.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Icon(Icons.article_outlined, size: 64, color: Colors.grey)),
                        SizedBox(height: 16),
                        Center(child: Text('Aucun article - Clique + pour créer', style: TextStyle(color: Colors.grey))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: articles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final a = articles[i];
                        return Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
                          child: ListTile(
                            leading: a.imageUrl != null && a.imageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(a.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200], child: const Icon(Icons.image))),
                                  )
                                : Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.article)),
                            title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${a.category} ${a.isFeatured ? "• À la une" : ""} ${a.isBreaking ? "• Breaking" : ""}', style: const TextStyle(fontSize: 12)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await context.push('/admin/articles/${a.id}/edit');
                                  _load();
                                }
                                if (v == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Supprimer ?'),
                                      content: Text('Supprimer "${a.title}" ?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await context.read<NewsProvider>().deleteArticle(a.id);
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supprimé')));
                                    _load();
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Éditer')),
                                PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kGold,
        foregroundColor: Colors.black,
        onPressed: () async {
          await context.push('/admin/articles/new');
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
