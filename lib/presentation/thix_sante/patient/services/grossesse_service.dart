import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grossesse_model.dart';

class GrossesseService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;
  String resolveUid(String? pid) => pid ?? _uid;

  // ========== PROFILE ==========
  Future<PregnancyProfile?> getProfile(String? pid) async {
    final uid = resolveUid(pid);
    final res = await _db.from('pregnancy_profiles').select().eq('user_id', uid).maybeSingle();
    return res == null ? null : PregnancyProfile.fromJson(res);
  }

  Future<void> createProfile(String? pid, DateTime ddr, PregnancyType type) async {
    final uid = resolveUid(pid);
    final dpa = ddr.add(Duration(days: type == PregnancyType.jumeaux ? 259 : type == PregnancyType.triple ? 245 : 280));
    await _db.from('pregnancy_profiles').upsert({
      'user_id': uid,
      'last_period_date': ddr.toIso8601String().substring(0, 10),
      'dpa': dpa.toIso8601String().substring(0, 10),
      'pregnancy_type': type.name
    }, onConflict: 'user_id');
    await ensureDefaultChecklist(pid);
  }

  Future<void> createFullProfile({
    required String? pid,
    required DateTime ddr,
    DateTime? conception,
    DateTime? echo,
    required PregnancyType type,
    required int age,
    required int parity,
    required int gravida,
    required double poids,
    required double taille,
    required BloodGroup bloodGroup,
    required Rhesus rhesus,
    required List<String> antecedents,
    required bool tabac,
    required bool alcool,
    required bool diabete,
    required bool hta,
  }) async {
    final uid = resolveUid(pid);
    final bmi = poids / ((taille / 100) * (taille / 100));
    DateTime dpa;
    if (echo != null) {
      dpa = echo.add(const Duration(days: 266));
    } else if (conception != null) {
      dpa = conception.add(const Duration(days: 266));
    } else {
      dpa = ddr.add(Duration(days: type == PregnancyType.jumeaux ? 259 : type == PregnancyType.triple ? 245 : 280));
    }
    await _db.from('pregnancy_profiles').upsert({
      'user_id': uid,
      'last_period_date': ddr.toIso8601String().substring(0, 10),
      'conception_date': conception?.toIso8601String().substring(0, 10),
      'echo_date': echo?.toIso8601String().substring(0, 10),
      'dpa': dpa.toIso8601String().substring(0, 10),
      'pregnancy_type': type.name,
      'age': age,
      'parity': parity,
      'gravida': gravida,
      'weight_before': poids,
      'height': taille,
      'bmi': double.parse(bmi.toStringAsFixed(1)),
      'blood_group': bloodGroup.name,
      'rhesus': rhesus.name,
      'antecedents': antecedents,
      'tabac': tabac,
      'alcool': alcool,
      'diabete': diabete,
      'hta': hta,
    }, onConflict: 'user_id');
    await _db.from('pregnancy_vitals').insert({'user_id': uid, 'type': 'poids', 'value': poids.toString()});
    await _db.from('pregnancy_vitals').insert({'user_id': uid, 'type': 'imc', 'value': bmi.toStringAsFixed(1)});
    await ensureDefaultChecklist(pid);
  }

  // ========== VITALS ==========
  Future<List<PregnancyVital>> getVitals(String? pid) async {
    final res = await _db.from('pregnancy_vitals').select().eq('user_id', resolveUid(pid)).order('created_at', ascending: false).limit(100);
    return (res as List).map((e) => PregnancyVital.fromJson(e)).toList();
  }

  Future<void> addVital(String? pid, String type, String value, {String? value2}) async {
    await _db.from('pregnancy_vitals').insert({'user_id': resolveUid(pid), 'type': type, 'value': value, 'value2': value2});
  }

  // ========== KICKS ==========
  Future<List<PregnancyKick>> getKicks(String? pid) async {
    final res = await _db.from('pregnancy_kicks').select().eq('user_id', resolveUid(pid)).order('created_at', ascending: false).limit(100);
    return (res as List).map((e) => PregnancyKick.fromJson(e)).toList();
  }

  Future<void> addKick(String? pid) async {
    if (pid != null) throw Exception('Femme seule');
    await _db.from('pregnancy_kicks').insert({'user_id': resolveUid(pid)});
  }

  // ========== CONTRACTIONS ==========
  Future<List<PregnancyContraction>> getContractions(String? pid) async {
    final res = await _db.from('pregnancy_contractions').select().eq('user_id', resolveUid(pid)).order('created_at', ascending: false).limit(20);
    return (res as List).map((e) => PregnancyContraction.fromJson(e)).toList();
  }

  Future<void> addContraction(String? pid, int dur, int inter) async {
    await _db.from('pregnancy_contractions').insert({'user_id': resolveUid(pid), 'duration_sec': dur, 'interval_sec': inter});
  }

  // ========== JOURNAL ==========
  Future<List<PregnancyJournal>> getJournals(String? pid) async {
    final res = await _db.from('pregnancy_journal').select().eq('user_id', resolveUid(pid)).order('created_at', ascending: false);
    return (res as List).map((e) => PregnancyJournal.fromJson(e)).toList();
  }

  Future<void> addJournal(String? pid, String title, String content, {String? photoUrl}) async {
    if (pid != null) throw Exception('Femme seule');
    await _db.from('pregnancy_journal').insert({'user_id': resolveUid(pid), 'title': title, 'content': content, 'photo_url': photoUrl});
  }

  // ========== CHECKLIST ==========
  Future<List<PregnancyChecklist>> getChecklist(String? pid) async {
    final res = await _db.from('pregnancy_checklist').select().eq('user_id', resolveUid(pid)).order('created_at');
    return (res as List).map((e) => PregnancyChecklist.fromJson(e)).toList();
  }

  Future<void> toggleChecklist(String id, bool done) async {
    await _db.from('pregnancy_checklist').update({'done': done}).eq('id', id);
  }

  Future<void> ensureDefaultChecklist(String? pid) async {
    final uid = resolveUid(pid);
    final existing = await _db.from('pregnancy_checklist').select().eq('user_id', uid).limit(1);
    if ((existing as List).isNotEmpty) return;
    final defaults = [
      {'item': 'Dossier medical + carte THIX', 'category': 'maman'},
      {'item': '3 pyjamas ouverts devant', 'category': 'maman'},
      {'item': 'Couches taille 1 + lingettes', 'category': 'bebe'},
      {'item': 'Siege auto homologue', 'category': 'bebe'},
      {'item': 'Trousse + carnet sante', 'category': 'bebe'},
    ];
    for (final d in defaults) {
      await _db.from('pregnancy_checklist').insert({'user_id': uid, 'item': d['item'], 'category': d['category'], 'done': false});
    }
  }

  // ========== RECORDS / DOCS ==========
  Future<List<dynamic>> getRecords(String? pid) async {
    final res = await _db.from('health_records').select().eq('patient_uid', resolveUid(pid)).order('exam_date', ascending: false).limit(50);
    return res as List;
  }

  Future<String> uploadPhoto(String? pid, String path, dynamic bytes) async {
    final uid = resolveUid(pid);
    final filePath = '$uid/journal/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Uint8List data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes as List<int>);
    await _db.storage.from('pregnancy_photos').uploadBinary(filePath, data, fileOptions: const FileOptions(upsert: true));
    return _db.storage.from('pregnancy_photos').getPublicUrl(filePath);
  }

  Future<void> uploadDoc(String? pid, String fileName, dynamic bytes) async {
    final uid = resolveUid(pid);
    final filePath = '$uid/$fileName';
    final Uint8List data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes as List<int>);
    await _db.storage.from('pregnancy_docs').uploadBinary(filePath, data, fileOptions: const FileOptions(upsert: true));
  }

  Future<void> addConsultation(String? pid, String title, String desc) async {
    await _db.from('health_records').insert({
      'patient_uid': resolveUid(pid),
      'professional_uid': _uid,
      'type': 'consultation',
      'title': 'Grossesse - $title',
      'description': desc,
      'exam_date': DateTime.now().toIso8601String()
    });
  }

  // ========== RISQUES ==========
  List<String> calculateRisks({required int sa, List<PregnancyVital> vitals = const [], List<PregnancyKick> kicks = const [], List<PregnancyContraction> contractions = const []}) {
    final alerts = <String>[];
    final ta = vitals.where((v) => v.type == 'tension').toList();
    if (ta.isNotEmpty) {
      final sys = int.tryParse(ta.first.value.split('/').first) ?? 0;
      if (sys >= 140) alerts.add('TA ${ta.first.value} >140 - Risque pre-eclampsie');
    }
    if (kicks.where((k) => k.createdAt.day == DateTime.now().day).isEmpty && sa >= 28) {
      alerts.add('0 mouvement aujourd hui apres 28 SA');
    }
    if (sa >= 37 && contractions.length >= 3) {
      final avg = contractions.take(3).map((c) => c.intervalSec).reduce((a, b) => a + b) / 3;
      if (avg <= 300) alerts.add('Contractions toutes les 5 min - Maternite');
    }
    return alerts;
  }
}
