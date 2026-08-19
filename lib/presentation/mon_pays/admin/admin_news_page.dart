// lib/presentation/mon_pays/admin/admin_news_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../providers/news_provider.dart';
import 'admin_news_form_page.dart';

class AdminNewsPage extends ConsumerWidget {
  const AdminNewsPage({super.key});

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color redThix = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Gestion des Actualités'),
        backgroundColor: redThix,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(newsProvider),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: navyDeep,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Rédiger', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminNewsFormPage()),
          );
        },
      ),
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: navyDeep)),
        error: (err, stack) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.red))),
        data: (newsList) {
          if (newsList.isEmpty) {
            return const Center(child: Text('Aucune actualité enregistrée.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16).copyWith(bottom: 80),
            itemCount: newsList.length,
            itemBuilder: (context, index) {
              final article = newsList[index];
              final dateStr = article.publishedAt != null 
                  ? DateFormat('dd/MM/yyyy').format(article.publishedAt!) 
                  : 'Récemment';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: article.coverImageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey.shade200, width: 60, height: 60),
                            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200, width: 60, height: 60, child: const Icon(Icons.broken_image)),
                          )
                        : Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.newspaper)),
                  ),
                  title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('${article.category} • $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AdminNewsFormPage(article: article)),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, article.id),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'article ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(newsServiceProvider).deleteNews(id);
                ref.invalidate(newsProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Article supprimé')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur : $e')));
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
