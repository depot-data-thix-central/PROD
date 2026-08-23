// lib/presentation/thix_ia/widgets/project_memory_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_memory.dart';
import '../providers/project_memory_provider.dart';
import 'fact_card.dart';
import 'confidence_indicator.dart';

class ProjectMemoryPanel extends ConsumerWidget {
  const ProjectMemoryPanel({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryAsync = ref.watch(projectMemoryProvider);
    final memory = memoryAsync.value;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: memoryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur mémoire: $e'),
        ),
        data: (_) {
          if (memory == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Aucune mémoire', style: ThixPolicy.bodySmallStyle),
            );
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded, color: ThixPolicy.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Mémoire Projet', style: ThixPolicy.h3Style),
                    const Spacer(),
                    ConfidenceIndicator(
                      value: memory.facts.isEmpty 
                        ? 0 
                        : memory.facts.map((f) => f.confidence).reduce((a, b) => a + b) / memory.facts.length,
                    ),
                    // Le problème était ici : il y avait un "), " en trop qui fermait la Row trop tôt.
                  ],
                ),
              ),
              Divider(height: 1, color: ThixPolicy.border),
              _Section(
                title: 'Contexte',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(label: 'Problème', value: memory.context.problem ?? '-'),
                    _Row(label: 'Proposition', value: memory.context.valueProposition ?? '-'),
                    _Row(label: 'Clients', value: memory.context.targetCustomers.join(', ')),
                  ],
                ),
              ),
              if (memory.facts.isNotEmpty) ...[
                _Section(
                  title: 'Faits vérifiés (${memory.facts.length})',
                  child: Column(
                    children: memory.facts.take(3).map((f) => FactCard(fact: f)).toList(),
                  ),
                ),
              ],
              if (memory.openQuestions.isNotEmpty) ...[
                _Section(
                  title: 'Questions ouvertes',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: memory.openQuestions.map((q) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ThixPolicy.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(q, style: ThixPolicy.captionStyle),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ThixPolicy.labelStyle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: ThixPolicy.bodySmallStyle,
            ),
          ),
        ],
      ),
    );
  }
}
