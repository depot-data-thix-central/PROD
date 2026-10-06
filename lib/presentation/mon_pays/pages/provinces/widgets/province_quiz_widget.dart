// lib/presentation/mon_pays/pages/provinces/widgets/province_quiz_widget.dart
//
// 🎮 QUIZ INTERACTIF : questions depuis Supabase, score, résultat, partage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../../providers/provinces_provider.dart';
import 'province_shortcut_bar.dart';

class ProvinceQuizSection extends ConsumerStatefulWidget {
  final String provinceId;
  final String provinceName;
  final NationalLanguage lang;
  const ProvinceQuizSection({super.key, required this.provinceId, required this.provinceName, required this.lang});

  @override
  ConsumerState<ProvinceQuizSection> createState() => _ProvinceQuizSectionState();
}

class _ProvinceQuizSectionState extends ConsumerState<ProvinceQuizSection> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _done = false;

  void _answer(int choice, int correct, int total) {
    if (_selected != null) return;
    setState(() => _selected = choice);
    if (choice == correct) _score++;
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _selected = null;
        _index++;
        if (_index >= total) _done = true;
      });
    });
  }

  void _reset() => setState(() {
        _index = 0;
        _score = 0;
        _selected = null;
        _done = false;
      });

  @override
  Widget build(BuildContext context) {
    return ref.watch(provinceQuizProvider(widget.provinceId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (questions) {
            if (questions.isEmpty) return const SizedBox.shrink();
            final total = questions.length;
            final q = _index < total ? questions[_index] : null;
            final options = q == null ? <String>[] : ((q['options'] as List?) ?? []).map((e) => e.toString()).toList();
            final correct = (q?['correct_answer'] as num?)?.toInt() ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.quiz_rounded, color: const Color(0xFF8E24AA),
                    title: ProvinceTranslations.t('quiz', widget.lang), count: total),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: !_done && q != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Question ${_index + 1}/$total',
                                      style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF8E24AA), fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  Text('Score : $_score',
                                      style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF43A047), fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (_index + 1) / total,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFF8E24AA).withOpacity(0.12),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8E24AA)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(q['question']?.toString() ?? '',
                                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 14),
                              ...options.asMap().entries.map((e) {
                                final isSel = _selected == e.key;
                                final isCorrect = e.key == correct;
                                final showState = _selected != null;
                                Color bg = ThixPolicy.surfaceSoft;
                                Color bd = ThixPolicy.border;
                                if (showState && isCorrect) {
                                  bg = const Color(0xFF43A047).withOpacity(0.12);
                                  bd = const Color(0xFF43A047);
                                } else if (showState && isSel && !isCorrect) {
                                  bg = ThixPolicy.danger.withOpacity(0.1);
                                  bd = ThixPolicy.danger;
                                }
                                return InkWell(
                                  onTap: () => _answer(e.key, correct, total),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: bd)),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 26, height: 26,
                                          decoration: BoxDecoration(color: const Color(0xFF8E24AA).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                          child: Center(
                                            child: Text(String.fromCharCode(65 + e.key),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF8E24AA))),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(e.value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    (_score >= total / 2 ? const Color(0xFF43A047) : const Color(0xFFE53935)).withOpacity(0.18),
                                    Colors.transparent,
                                  ]),
                                  shape: BoxShape.circle,
                                ),
                                child: Text('$_score/$total',
                                    style: ThixPolicy.h1Style.copyWith(
                                        color: _score >= total / 2 ? const Color(0xFF43A047) : const Color(0xFFE53935),
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(height: 12),
                              Text(_score >= total / 2 ? '🎉 Excellent !' : '💪 À améliorer',
                                  style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text('Vous connaissez ${_score >= total / 2 ? 'bien' : 'encore peu'} ${widget.provinceName} !',
                                  textAlign: TextAlign.center,
                                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _reset,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Rejouer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8E24AA),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => Share.share('🎮 Quiz ${widget.provinceName} : $_score/$total sur THIX ID !'),
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: const Text('Partager'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF8E24AA),
                                      side: const BorderSide(color: Color(0xFF8E24AA)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
  }
}
