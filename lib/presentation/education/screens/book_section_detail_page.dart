// lib/presentation/education/screens/book_section_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/book_section.dart';
import '../services/book_content_service.dart';

final bookSectionProvider =
    FutureProvider.family<BookSection, String>((ref, sectionId) async {
  return BookContentService().getSectionById(sectionId);
});

class BookSectionDetailPage extends HookConsumerWidget {
  final String sectionId;

  const BookSectionDetailPage({required this.sectionId, super.key});

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionAsync = ref.watch(bookSectionProvider(sectionId));
    final selectedLang = useState<String>('FR');

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        backgroundColor: navyDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: gold.withOpacity(0.5)),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 15, color: gold),
            ),
            const SizedBox(width: 10),
            const Text('Section',
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
      body: sectionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (section) => _buildContent(section, selectedLang),
      ),
    );
  }

  Widget _buildContent(BookSection section, ValueNotifier<String> selectedLang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [navyDeep, navy],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title ?? 'Section',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3),
                ),
                if (section.sectionNumber != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '§ ${section.sectionNumber}',
                      style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Contenu + sélecteur de langue
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        SizedBox(
                          width: 4,
                          height: 18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(3)),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Contenu',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: darkText)),
                      ],
                    ),
                    _buildLanguageSelector(selectedLang),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    section.getContent(selectedLang.value),
                    key: ValueKey(selectedLang.value),
                    style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.65,
                        color: darkText),
                  ),
                ),
              ],
            ),
          ),

          // Explication (si existe)
          if (section.getExplanation(selectedLang.value) != null &&
              section.getExplanation(selectedLang.value)!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 18, color: navyDeep),
                      SizedBox(width: 8),
                      Text('Explication',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: navyDeep)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    section.getExplanation(selectedLang.value)!,
                    style: const TextStyle(
                        fontSize: 14, height: 1.6, color: darkText),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(ValueNotifier<String> selectedLang) {
    return Container(
      decoration: BoxDecoration(
        color: hairline,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['FR', 'LN', 'SW', 'EN'].map((lang) {
          final isSelected = selectedLang.value == lang;
          return GestureDetector(
            onTap: () => selectedLang.value = lang,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? pureWhite : mutedText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
