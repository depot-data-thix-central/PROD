// lib/presentation/education/screens/book_chapters_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; 

import '../models/book_chapter.dart';
import '../models/book_section.dart';
import '../services/book_content_service.dart';

final bookChaptersProvider =
    FutureProvider.family<List<BookChapter>, String>((ref, bookId) async {
  return BookContentService().getChapters(bookId);
});

final bookSectionsByChapterProvider =
    FutureProvider.family<List<BookSection>, String>((ref, chapterId) async {
  return BookContentService().getSectionsByChapter(chapterId);
});

class BookChaptersPage extends ConsumerWidget {
  final String bookId;
  final String? bookTitle;

  const BookChaptersPage({
    required this.bookId,
    this.bookTitle,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(bookChaptersProvider(bookId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: ThixPolicy.onBrand),
        title: Text(
          bookTitle ?? 'Chapitres',
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.onBrand,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (chapters) {
          if (chapters.isEmpty) {
            return Center(
              child: Text(
                'Aucun chapitre disponible pour ce livre.',
                style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              ThixPolicy.s16,
              ThixPolicy.s16,
              ThixPolicy.s16,
              ThixPolicy.s32,
            ),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              return _ChapterCard(
                chapter: chapter,
                bookId: bookId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChapterCard extends ConsumerWidget {
  final BookChapter chapter;
  final String bookId;

  const _ChapterCard({required this.chapter, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync =
        ref.watch(bookSectionsByChapterProvider(chapter.id));

    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s14),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s16,
            vertical: ThixPolicy.s4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            ThixPolicy.s12,
            0,
            ThixPolicy.s12,
            ThixPolicy.s12,
          ),
          leading: Container(
            width: ThixPolicy.s40,
            height: ThixPolicy.s40,
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            ),
            child: Center(
              child: Text(
                '${chapter.chapterNumber}',
                style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.inkDeep,
                ),
              ),
            ),
          ),
          title: Text(
            chapter.title,
            style: ThixPolicy.titleStyle,
          ),
          subtitle: Text(
            'Chapitre ${chapter.chapterNumber}',
            style: ThixPolicy.captionStyle,
          ),
          children: [
            sectionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(ThixPolicy.s12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text('Erreur : $e'),
              data: (sections) {
                if (sections.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    child: Text(
                      'Aucune section dans ce chapitre.',
                      style: ThixPolicy.bodySmallStyle,
                    ),
                  );
                }

                return Column(
                  children: sections.map((section) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s8,
                        vertical: ThixPolicy.s2,
                      ),
                      leading: const Icon(
                        Icons.article_outlined,
                        size: ThixPolicy.s20,
                        color: ThixPolicy.primary,
                      ),
                      title: Text(
                        section.title ??
                            'Section ${section.sectionNumber ?? ''}',
                        style: ThixPolicy.bodyMediumStyle.copyWith(
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                      subtitle: section.sectionNumber != null
                          ? Text('§ ${section.sectionNumber}')
                          : null,
                      trailing: const Icon(
                        Icons.chevron_right,
                        size: ThixPolicy.s20,
                      ),
                      onTap: () {
                        context.push(
                          '/education/section/${section.id}',
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
