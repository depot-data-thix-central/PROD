// lib/presentation/thix_money/models/tontine_model.dart
class TontineModel {
  final String id;
  final String thixId; // créateur lié à THIX ID
  final String name;
  final int members;
  final int totalMembers;
  final int cotisation;
  final String devise;
  final String frequence; // hebdo, mensuel
  final DateTime createdAt;

  TontineModel({
    required this.id,
    required this.thixId,
    required this.name,
    required this.members,
    required this.totalMembers,
    required this.cotisation,
    required this.devise,
    required this.frequence,
    required this.createdAt,
  });

  factory TontineModel.fromJson(Map<String, dynamic> j) => TontineModel(
    id: j['id'],
    thixId: j['thix_id'],
    name: j['name'],
    members: j['members'] as int,
    totalMembers: j['total_members'] as int,
    cotisation: (j['cotisation'] as num).toInt(),
    devise: j['devise'] ?? 'CDF',
    frequence: j['frequence'] ?? 'mensuel',
    createdAt: DateTime.parse(j['created_at']),
  );

  double get progress => totalMembers == 0 ? 0 : members / totalMembers;
}
