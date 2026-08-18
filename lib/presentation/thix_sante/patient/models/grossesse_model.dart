enum PregnancyType { singleton, jumeaux, triple }
enum BloodGroup { O, A, B, AB }
enum Rhesus { pos, neg }

class BabyWeekInfo {
  final String fruit, size, weight, desc;
  const BabyWeekInfo({
    required this.fruit,
    required this.size,
    required this.weight,
    required this.desc,
  });
}

class WeekAdvice {
  final String title;
  final List<String> babyDevelopment, nutrition, avoid;
  const WeekAdvice({
    required this.title,
    required this.babyDevelopment,
    required this.nutrition,
    required this.avoid,
  });
}

class PregnancyProfile {
  final String id, userId;
  final DateTime lastPeriodDate, dpa, createdAt;
  final DateTime? conceptionDate, echoDate;
  final PregnancyType type;
  final int age, parity, gravida;
  final double weightBefore, height, bmi;
  final BloodGroup bloodGroup;
  final Rhesus rhesus;
  final List<String> antecedents;
  final bool tabac, alcool, diabete, hta;

  PregnancyProfile({
    required this.id,
    required this.userId,
    required this.lastPeriodDate,
    required this.dpa,
    required this.createdAt,
    this.conceptionDate,
    this.echoDate,
    required this.type,
    required this.age,
    required this.parity,
    required this.gravida,
    required this.weightBefore,
    required this.height,
    required this.bmi,
    required this.bloodGroup,
    required this.rhesus,
    required this.antecedents,
    required this.tabac,
    required this.alcool,
    required this.diabete,
    required this.hta,
  });

  int get sa {
    final diff = DateTime.now().difference(lastPeriodDate).inDays;
    return (diff / 7).floor().clamp(0, 42);
  }

  int get daysRemain => dpa.difference(DateTime.now()).inDays;
  double get progress => (sa / 40).clamp(0, 1).toDouble();
  String trimester() => sa < 14 ? 'T1' : sa < 28 ? 'T2' : 'T3';
  int get daysRemainAbs => daysRemain.abs();

  factory PregnancyProfile.fromJson(Map<String, dynamic> j) {
    DateTime parse(String? s) => s == null ? DateTime.now() : DateTime.parse(s);
    return PregnancyProfile(
      id: j['id'] ?? '',
      userId: j['user_id'] ?? '',
      lastPeriodDate: parse(j['last_period_date']),
      dpa: parse(j['dpa']),
      createdAt: parse(j['created_at'] ?? j['last_period_date']),
      conceptionDate:
          j['conception_date'] != null ? DateTime.tryParse(j['conception_date']) : null,
      echoDate: j['echo_date'] != null ? DateTime.tryParse(j['echo_date']) : null,
      type: PregnancyType.values.firstWhere(
        (e) => e.name == j['pregnancy_type'],
        orElse: () => PregnancyType.singleton,
      ),
      age: (j['age'] ?? 25) as int,
      parity: (j['parity'] ?? 0) as int,
      gravida: (j['gravida'] ?? 1) as int,
      weightBefore: ((j['weight_before'] ?? 60) as num).toDouble(),
      height: ((j['height'] ?? 165) as num).toDouble(),
      bmi: ((j['bmi'] ?? 22) as num).toDouble(),
      bloodGroup: BloodGroup.values.firstWhere(
        (e) => e.name == j['blood_group'],
        orElse: () => BloodGroup.O,
      ),
      rhesus: Rhesus.values.firstWhere(
        (e) => e.name == j['rhesus'],
        orElse: () => Rhesus.pos,
      ),
      antecedents: List<String>.from(j['antecedents'] ?? []),
      tabac: j['tabac'] ?? false,
      alcool: j['alcool'] ?? false,
      diabete: j['diabete'] ?? false,
      hta: j['hta'] ?? false,
    );
  }
}

class PregnancyVital {
  final String id;
  final DateTime createdAt;
  final String type, value;
  final String? value2;

  PregnancyVital({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.value,
    this.value2,
  });

  factory PregnancyVital.fromJson(Map<String, dynamic> j) => PregnancyVital(
        id: j['id'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        type: j['type'] ?? '',
        value: j['value'] ?? '',
        value2: j['value2'],
      );
}

class PregnancyKick {
  final String id;
  final DateTime createdAt;

  PregnancyKick({
    required this.id,
    required this.createdAt,
  });

  factory PregnancyKick.fromJson(Map<String, dynamic> j) => PregnancyKick(
        id: j['id'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

class PregnancyContraction {
  final String id;
  final DateTime createdAt;
  final int durationSec, intervalSec;

  PregnancyContraction({
    required this.id,
    required this.createdAt,
    required this.durationSec,
    required this.intervalSec,
  });

  factory PregnancyContraction.fromJson(Map<String, dynamic> j) =>
      PregnancyContraction(
        id: j['id'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        durationSec: (j['duration_sec'] ?? 0) as int,
        intervalSec: (j['interval_sec'] ?? 0) as int,
      );
}

class PregnancyJournal {
  final String id;
  final DateTime createdAt;
  final String title, content;
  final String? photoUrl;

  PregnancyJournal({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.content,
    this.photoUrl,
  });

  factory PregnancyJournal.fromJson(Map<String, dynamic> j) => PregnancyJournal(
        id: j['id'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        photoUrl: j['photo_url'],
      );
}

class PregnancyChecklist {
  final String id, item, category;
  final bool done;

  PregnancyChecklist({
    required this.id,
    required this.item,
    required this.category,
    required this.done,
  });

  factory PregnancyChecklist.fromJson(Map<String, dynamic> j) =>
      PregnancyChecklist(
        id: j['id'] ?? '',
        item: j['item'] ?? '',
        category: j['category'] ?? 'bebe',
        done: j['done'] ?? false,
      );
}

typedef ChecklistItem = PregnancyChecklist;
