class CalendarEvent {
  final String id;
  final String instructorId;
  final String? formationId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String eventType;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({required this.id, required this.instructorId, this.formationId, required this.title, this.description, required this.startTime, required this.endTime, required this.eventType, required this.createdAt, required this.updatedAt});

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'],
    instructorId: json['instructor_id'],
    formationId: json['formation_id'],
    title: json['title'],
    description: json['description'],
    startTime: DateTime.parse(json['start_time']),
    endTime: DateTime.parse(json['end_time']),
    eventType: json['event_type'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}
