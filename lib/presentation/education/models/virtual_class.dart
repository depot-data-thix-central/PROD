class VirtualClass {
  final String id;
  final String instructorId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingLink;
  final String? recordingUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  VirtualClass({required this.id, required this.instructorId, required this.title, this.description, required this.scheduledAt, this.durationMinutes = 60, this.meetingLink, this.recordingUrl, this.status = 'scheduled', required this.createdAt, required this.updatedAt});

  factory VirtualClass.fromJson(Map<String, dynamic> json) => VirtualClass(
    id: json['id'],
    instructorId: json['instructor_id'],
    title: json['title'],
    description: json['description'],
    scheduledAt: DateTime.parse(json['scheduled_at']),
    durationMinutes: json['duration_minutes'] ?? 60,
    meetingLink: json['meeting_link'],
    recordingUrl: json['recording_url'],
    status: json['status'] ?? 'scheduled',
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
