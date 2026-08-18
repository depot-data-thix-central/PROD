class Submission {
  final String id;
  final String assignmentId;
  final String userId;
  final String? content;
  final String? fileUrl;
  final DateTime submittedAt;
  final double? score;
  final String? feedback;
  final DateTime? correctedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Submission({required this.id, required this.assignmentId, required this.userId, this.content, this.fileUrl, required this.submittedAt, this.score, this.feedback, this.correctedAt, required this.createdAt, required this.updatedAt});

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
    id: json['id'],
    assignmentId: json['assignment_id'],
    userId: json['user_id'],
    content: json['content'],
    fileUrl: json['file_url'],
    submittedAt: DateTime.parse(json['submitted_at']),
    score: (json['score'] as num?)?.toDouble(),
    feedback: json['feedback'],
    correctedAt: json['corrected_at'] != null ? DateTime.parse(json['corrected_at']) : null,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
