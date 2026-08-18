// lib/presentation/education/widgets/formation_detail/formation_evaluation_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/presentation/education/models/evaluation.dart';
import 'package:thix_id/presentation/education/models/question.dart'; 


// ============================================================
// ÉTAT DE L'ÉVALUATION (Immuable)
// ============================================================
class EvaluationState {
  final Map<int, String> answers;
  final bool isSubmitting;
  final bool isSubmitted;
  final int score;
  final String? error;

  const EvaluationState({
    this.answers = const {},
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.score = 0,
    this.error,
  });

  EvaluationState copyWith({
    Map<int, String>? answers,
    bool? isSubmitting,
    bool? isSubmitted,
    int? score,
    String? error,
  }) {
    return EvaluationState(
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      score: score ?? this.score,
      error: error, // Si non spécifié, on l'écrase (permet de clear l'erreur)
    );
  }
}

// ============================================================
// PROVIDER & NOTIFIER (Logique Métier Séparée)
// ============================================================
// On utilise 'family' pour isoler l'état par évaluation (utile si on navigue entre plusieurs cours)
final evaluationProvider = AutoDisposeNotifierProviderFamily<EvaluationNotifier, EvaluationState, String>(
  EvaluationNotifier.new,
);

class EvaluationNotifier extends AutoDisposeFamilyNotifier<EvaluationState, String> {
  @override
  EvaluationState build(String arg) {
    return const EvaluationState();
  }

  void selectAnswer(int questionIndex, String answer) {
    if (state.isSubmitted || state.isSubmitting) return;

    final newAnswers = Map<int, String>.from(state.answers);
    newAnswers[questionIndex] = answer;
    
    state = state.copyWith(answers: newAnswers, error: null);
  }

  Future<bool> submitAnswers({
    required List<Question> questions,
    required int passingScore,
    Function(int score, int total)? onComplete,
  }) async {
    if (state.answers.length < questions.length) {
      state = state.copyWith(error: 'Veuillez répondre à toutes les questions.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      // 💡 NOTE ARCHITECTURE SCALABLE :
      // Actuellement, le score est calculé côté client.
      // Pour 1M+ d'utilisateurs, il faudra envoyer 'state.answers' à une Supabase Edge Function
      // pour éviter que des utilisateurs trichent en lisant les réponses dans le code source de l'app.
      
      int correct = 0;
      for (int i = 0; i < questions.length; i++) {
        if (state.answers[i] == questions[i].correctAnswer) {
          correct++;
        }
      }

      // TODO: Insérer l'enregistrement de la tentative dans Supabase ici
      // await ref.read(supabaseClientProvider).from('evaluation_attempts').insert({...});

      state = state.copyWith(
        isSubmitting: false,
        isSubmitted: true,
        score: correct,
      );

      onComplete?.call(correct, questions.length);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'Une erreur est survenue lors de la soumission.');
      return false;
    }
  }
}

// ============================================================
// WIDGET UI (ConsumerWidget)
// ============================================================
class FormationEvaluationWidget extends ConsumerWidget {
  final Evaluation evaluation;
  final Function(int score, int total)? onComplete;

  const FormationEvaluationWidget({
    super.key,
    required this.evaluation,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utilisation de l'ID de l'évaluation pour créer une instance unique du state
    final evaluationId = evaluation.id ?? 'default_eval'; 
    final state = ref.watch(evaluationProvider(evaluationId));
    final notifier = ref.read(evaluationProvider(evaluationId).notifier);
    
    final questions = evaluation.questions ?? [];

    // Gestion de l'affichage des erreurs (SnackBar) via un listener
    ref.listen<EvaluationState>(evaluationProvider(evaluationId), (previous, next) {
      if (next.error != null && (previous?.error != next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFFF5B3D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    if (questions.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Évaluation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 4),
        Text(
          '${questions.length} questions · Score minimum : ${evaluation.passingScore}%',
          style: const TextStyle(color: Color(0xFF7386A8), fontSize: 13),
        ),
        const SizedBox(height: 16),
        
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: questions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final question = questions[index];
            final selected = state.answers[index];
            return _buildQuestionCard(
              question: question,
              index: index,
              selected: selected,
              state: state,
              onSelect: (value) => notifier.selectAnswer(index, value),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        if (!state.isSubmitted)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.isSubmitting 
                ? null 
                : () => notifier.submitAnswers(
                    questions: questions,
                    passingScore: evaluation.passingScore,
                    onComplete: onComplete,
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6CDF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: state.isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Soumettre', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        else
          _buildResultCard(state.score, questions.length, evaluation.passingScore),
      ],
    );
  }

  Widget _buildQuestionCard({
    required Question question,
    required int index,
    required String? selected,
    required EvaluationState state,
    required Function(String) onSelect,
  }) {
    final isCorrect = state.isSubmitted && selected != null && selected == question.correctAnswer;
    
    // Détermination de la couleur de bordure selon l'état
    Color borderColor = Colors.grey[200]!;
    if (state.isSubmitted) {
      borderColor = isCorrect ? const Color(0xFF2ECC71) : const Color(0xFFFF5B3D);
    } else if (selected != null) {
      borderColor = const Color(0xFF2D6CDF).withOpacity(0.3); // Légère mise en évidence si répondu
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: state.isSubmitted || selected != null ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7386A8)),
                ),
              ),
              if (state.isSubmitted)
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? const Color(0xFF2ECC71) : const Color(0xFFFF5B3D),
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          
          ..._buildOptions(question, selected, state.isSubmitted, onSelect),
          
          if (state.isSubmitted && !isCorrect && question.correctAnswer != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6CDF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2D6CDF), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Réponse correcte : ${question.correctAnswer}',
                        style: const TextStyle(color: Color(0xFF2D6CDF), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(Question question, String? selected, bool isSubmitted, Function(String) onSelect) {
    final options = question.type == 'true_false' ? ['Vrai', 'Faux'] : question.options;

    return (options ?? []).map((option) {
      final isSelected = selected == option;
      final isCorrect = option == question.correctAnswer;
      
      Color? tileColor;
      if (isSubmitted && isSelected) {
        tileColor = isCorrect ? const Color(0xFF2ECC71).withOpacity(0.1) : const Color(0xFFFF5B3D).withOpacity(0.1);
      }

      return Theme(
        data: ThemeData(unselectedWidgetColor: const Color(0xFFE2E8F0)),
        child: RadioListTile<String>(
          value: option,
          groupValue: selected,
          onChanged: isSubmitted ? null : (value) => onSelect(value!),
          title: Text(
            option,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSubmitted && isSelected && !isCorrect ? const Color(0xFFFF5B3D) : const Color(0xFF1A1A2E),
            ),
          ),
          activeColor: const Color(0xFF2D6CDF),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: tileColor,
        ),
      );
    }).toList();
  }

  Widget _buildResultCard(int score, int totalQuestions, int passingScorePercentage) {
    final scorePercentage = (score / totalQuestions * 100).toInt();
    final hasPassed = scorePercentage >= passingScorePercentage;
    final color = hasPassed ? const Color(0xFF2ECC71) : const Color(0xFFFF5B3D);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasPassed ? Icons.emoji_events_rounded : Icons.info_outline_rounded, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                'Score : $score/$totalQuestions ($scorePercentage%)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasPassed
                ? 'Félicitations ! Vous avez réussi cette évaluation avec succès.'
                : 'L\'évaluation a échoué. Vous devez obtenir au moins $passingScorePercentage% pour valider ce module.',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'Aucune question disponible',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
