// lib/presentation/education/models/question.dart

class Question {
  final String id;
  final String evaluationId;
  final String text;
  final String type; // 'qcm', 'true_false', 'open'
  final List<String>? options;
  final int? correctIndex;
  final String? correctAnswer;

  Question({
    required this.id,
    required this.evaluationId,
    required this.text,
    this.type = 'qcm',
    this.options,
    this.correctIndex,
    this.correctAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      evaluationId: json['evaluation_id']?.toString() ?? '',
      text: json['text'] ?? '',
      type: json['type'] ?? 'qcm',
      // Supabase retourne souvent le JSONB comme une List dynamique, on la cast en List<String>
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      correctIndex: json['correct_index'] != null ? int.tryParse(json['correct_index'].toString()) : null,
      correctAnswer: json['correct_answer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'evaluation_id': evaluationId,
      'text': text,
      'type': type,
      'options': options,
      'correct_index': correctIndex,
      'correct_answer': correctAnswer,
    };
  }
}
