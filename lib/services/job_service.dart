import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/job_application.dart';
import 'package:thix_id/models/job_posting.dart';
import 'package:thix_id/openai/openai_config.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class JobService {
  static const String table = 'thix_job_offers';
  /// Supabase Storage bucket for job offer images (Admin).
  static const String imageBucket = 'thix_job_offer_images';
  static const String companiesTable = 'thix_companies';
  static const String savedTable = 'thix_job_saved';
  static const String applicationsTable = 'thix_job_applications';
  static const String messagesTable = 'thix_job_messages';
  static const String interviewsTable = 'thix_job_interviews';
  static const _kJobs = 'thix_jobs_v1';
  static const _kApplications = 'thix_job_applications_v1';
  static const _kSaved = 'thix_job_saved_v1';

  /// Upload an image to Supabase Storage and return a public URL.
  Future<String> uploadJobOfferImage({required Uint8List bytes, required String extension}) async {
    final ext = extension.trim().isEmpty ? 'jpg' : extension.trim().toLowerCase();
    final uid = SupabaseConfig.currentUser?.id ?? 'anon';
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final objectPath = 'job_offers/$uid/$ts.$ext';

    try {
      await SupabaseConfig.storage.from(imageBucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: ext == 'png'
                  ? 'image/png'
                  : ext == 'webp'
                      ? 'image/webp'
                      : ext == 'gif'
                          ? 'image/gif'
                          : 'image/jpeg',
            ),
          );
      final url = SupabaseConfig.storage.from(imageBucket).getPublicUrl(objectPath);
      if (url.trim().isEmpty) throw Exception('Storage: getPublicUrl returned empty.');
      return url;
    } catch (e) {
      final msg = e.toString();
      debugPrint('JobService.uploadJobOfferImage failed err=$msg');
      if (msg.contains('Bucket') && msg.contains('not found')) {
        throw Exception("Bucket Supabase Storage introuvable: '$imageBucket'. Crée-le (public) dans Supabase → Storage.");
      }
      throw Exception('Upload image échoué: $msg');
    }
  }

  Future<List<JobPosting>> listJobs() async {
    // 1) Supabase first (Admin-created offers)
    try {
      final res = await SupabaseService.select(table, select: '*', orderBy: 'created_at', ascending: false, limit: 200);
      final items = _mapRows(res);
      if (items.isNotEmpty) {
        await _cache(items);
        return items;
      }
    } catch (e) {
      debugPrint('JobService.listJobs supabase failed err=$e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kJobs);
      if (raw == null || raw.trim().isEmpty) {
        final seeded = _seedJobs();
        await prefs.setString(_kJobs, JobPosting.encodeList(seeded));
        return seeded;
      }
      final items = JobPosting.decodeList(raw);
      if (items.isEmpty) {
        final seeded = _seedJobs();
        await prefs.setString(_kJobs, JobPosting.encodeList(seeded));
        return seeded;
      }
      return items;
    } catch (e) {
      debugPrint('JobService.listJobs failed err=$e');
      return _seedJobs();
    }
  }

  Future<List<JobPosting>> searchJobs({
    String query = '',
    Set<String> types = const {},
    Set<String> workModes = const {},
    String? countryOrCity,
    String? industry,
    String? experienceLevel,
    int? salaryMin,
    int? salaryMax,
    int limit = 200,
  }) async {
    final all = await listJobs();
    final q = query.trim().toLowerCase();
    bool matchText(JobPosting j) {
      if (q.isEmpty) return true;
      final hay = '${j.title} ${j.company} ${j.location} ${j.description} ${j.skills.join(' ')} ${j.requirements.join(' ')}'.toLowerCase();
      return hay.contains(q);
    }

    bool matchSets(JobPosting j) {
      if (types.isNotEmpty && !types.contains(j.type.toLowerCase())) return false;
      final wm = (j.workMode ?? '').trim().toLowerCase();
      if (workModes.isNotEmpty && (wm.isEmpty || !workModes.contains(wm))) return false;
      if ((countryOrCity ?? '').trim().isNotEmpty) {
        final cc = countryOrCity!.trim().toLowerCase();
        if (!j.location.toLowerCase().contains(cc)) return false;
      }
      if ((industry ?? '').trim().isNotEmpty) {
        final ind = industry!.trim().toLowerCase();
        if ((j.industry ?? '').toLowerCase() != ind) return false;
      }
      if ((experienceLevel ?? '').trim().isNotEmpty) {
        final exp = experienceLevel!.trim().toLowerCase();
        if ((j.experienceLevel ?? '').toLowerCase() != exp) return false;
      }
      if (salaryMin != null) {
        final s = j.salaryMax ?? j.salaryMin;
        if (s != null && s < salaryMin!) return false;
      }
      if (salaryMax != null) {
        final s = j.salaryMin ?? j.salaryMax;
        if (s != null && s > salaryMax!) return false;
      }
      return true;
    }

    final filtered = all.where((j) => matchText(j) && matchSets(j)).toList(growable: false);
    return filtered.take(limit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> aiRecommendJobs({
    required Map<String, dynamic> userProfile,
    required List<JobPosting> jobs,
    int limit = 8,
  }) async {
    final jobJson = jobs
        .map((j) => {
              'id': j.id,
              'title': j.title,
              'company': j.company,
              'location': j.location,
              'work_mode': j.workMode,
              'type': j.type,
              'category': j.category,
              'industry': j.industry,
              'experience_level': j.experienceLevel,
              'salary': j.salary,
              'skills': j.skills,
              'requirements': j.requirements,
              'is_verified_employer': j.isVerifiedEmployer,
            })
        .toList(growable: false);
    return OpenAiConfig.recommendJobs(userProfile: userProfile, jobs: jobJson, limit: limit);
  }

  List<JobPosting> _mapRows(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    DateTime parseDate(dynamic v) {
      if (v == null) return now;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? now;
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    List<String> parseList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
      if (v is String) {
        final parts = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        return parts;
      }
      return const <String>[];
    }

    String pick(Map<String, dynamic> r, List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = r[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    return rows.map((r) {
      final id = pick(r, const ['id', 'uuid'], fallback: _id('job'));
      final title = pick(r, const ['title', 'position', 'job_title', 'name'], fallback: '—');
      final company = pick(r, const ['company', 'employer', 'organization'], fallback: '');
      final location = pick(r, const ['location', 'city', 'address'], fallback: '');
      final salary = pick(r, const ['salary', 'reward_label', 'compensation'], fallback: '—');
      final type = pick(r, const ['type', 'category', 'contract_type'], fallback: 'Offre');
      final description = pick(r, const ['description', 'content'], fallback: '');
      // Requirements: best-effort array
      final requirements = parseList(r['requirements']);

      return JobPosting(
        id: id,
        recruiterUserId: (r['recruiter_user_id'] ?? r['recruiterUserId'])?.toString(),
        companyId: (r['company_id'] ?? r['companyId'])?.toString(),
        title: title,
        company: company,
        // If you store a cover photo on the offer itself, we fall back to it as logo.
        companyLogoUrl: (r['company_logo_url'] ?? r['companyLogoUrl'] ?? r['image_url'] ?? r['cover_url'])?.toString(),
        isVerifiedEmployer: parseBool(r['is_verified_employer'] ?? r['isVerifiedEmployer'] ?? false),
        location: location,
        salary: salary,
        salaryMin: parseInt(r['salary_min'] ?? r['salaryMin']),
        salaryMax: parseInt(r['salary_max'] ?? r['salaryMax']),
        salaryCurrency: (r['salary_currency'] ?? r['salaryCurrency'])?.toString(),
        type: type,
        workMode: (r['work_mode'] ?? r['workMode'])?.toString(),
        category: pick(r, const ['category', 'segment', 'job_category'], fallback: '').trim().isEmpty ? null : pick(r, const ['category', 'segment', 'job_category']),
        industry: pick(r, const ['industry', 'sector'], fallback: '').trim().isEmpty ? null : pick(r, const ['industry', 'sector']),
        experienceLevel: pick(r, const ['experience_level', 'level'], fallback: '').trim().isEmpty ? null : pick(r, const ['experience_level', 'level']),
        description: description,
        // "Critères" (admin form) maps to requirements.
        requirements: requirements,
        skills: parseList(r['skills']),
        // "Mission" (admin form) maps to responsibilities.
        responsibilities: parseList(r['responsibilities'] ?? r['mission']),
        benefits: parseList(r['benefits']),
        deadline: parseNullableDate(r['deadline'] ?? r['deadline_at'] ?? r['deadline_date']),
        status: pick(r, const ['status', 'state'], fallback: '').trim().isEmpty ? null : pick(r, const ['status', 'state']),
        applicantsCount: parseInt(r['applicants_count'] ?? r['applicantsCount']),
        isFeatured: parseBool(r['is_featured'] ?? r['isFeatured'] ?? false),
        isSuggested: parseBool(r['is_suggested'] ?? r['isSuggested'] ?? false),
        createdAt: parseDate(r['created_at'] ?? r['createdAt']),
        updatedAt: parseDate(r['updated_at'] ?? r['updatedAt']),
      );
    }).toList(growable: false);
  }

  Future<void> _cache(List<JobPosting> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kJobs, JobPosting.encodeList(items));
    } catch (e) {
      debugPrint('JobService cache failed err=$e');
    }
  }

  Future<JobPosting?> fetchJob(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty) return null;
    final all = await listJobs();
    for (final j in all) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<JobApplication> submitApplication({
    required String jobId,
    required String applicantThixId,
    String? message,
    String? portfolioUrl,
    String? videoIntroUrl,
    String? resumeUrl,
    List<String> diplomaUrls = const [],
  }) async {
    final now = DateTime.now();
    final app = JobApplication(
      id: _id('apply'),
      jobId: jobId,
      applicantThixId: applicantThixId.trim().toUpperCase(),
      applicantUserId: SupabaseConfig.currentUser?.id,
      message: message?.trim().isEmpty ?? true ? null : message!.trim(),
      status: 'applied',
      portfolioUrl: portfolioUrl?.trim().isEmpty ?? true ? null : portfolioUrl?.trim(),
      videoIntroUrl: videoIntroUrl?.trim().isEmpty ?? true ? null : videoIntroUrl?.trim(),
      resumeUrl: resumeUrl?.trim().isEmpty ?? true ? null : resumeUrl?.trim(),
      diplomaUrls: diplomaUrls,
      recruiterNote: null,
      createdAt: now,
      updatedAt: now,
    );

    // 1) Try Supabase (best effort)
    try {
      await SupabaseService.insert(applicationsTable, app.toJson());
    } catch (e) {
      debugPrint('JobService.submitApplication supabase insert failed err=$e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kApplications);
      final list = (raw == null || raw.trim().isEmpty) ? <JobApplication>[] : JobApplication.decodeList(raw).toList(growable: true);
      list.insert(0, app);
      await prefs.setString(_kApplications, JobApplication.encodeList(list));
    } catch (e) {
      debugPrint('JobService.submitApplication failed (local write) err=$e');
    }
    return app;
  }

  Future<List<Map<String, dynamic>>> listMyApplicationsRemote({int limit = 200}) async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return const [];
    try {
      return await SupabaseService.select(applicationsTable, select: '*', orderBy: 'created_at', ascending: false, limit: limit, filters: {'applicant_user_id': uid});
    } catch (e) {
      debugPrint('JobService.listMyApplicationsRemote failed err=$e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> listRecruiterApplications({required String recruiterUserId, int limit = 200}) async {
    final rid = recruiterUserId.trim();
    if (rid.isEmpty) return const [];
    try {
      // Join is not required; we query raw applications and filter by recruiter_user_id if present.
      return await SupabaseService.select(applicationsTable, select: '*', orderBy: 'created_at', ascending: false, limit: limit, filters: {'recruiter_user_id': rid});
    } catch (e) {
      debugPrint('JobService.listRecruiterApplications failed err=$e');
      return const [];
    }
  }

  Future<void> toggleSavedRemote({required String jobId, bool? save}) async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) {
      await toggleSaved(jobId: jobId, save: save);
      return;
    }
    final id = jobId.trim();
    if (id.isEmpty) return;
    final shouldSave = save ?? true;
    try {
      if (shouldSave) {
        await SupabaseConfig.client.from(savedTable).upsert(
          {
            'user_id': uid,
            'job_id': id,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,job_id',
        );
      } else {
        await SupabaseConfig.client.from(savedTable).delete().eq('user_id', uid).eq('job_id', id);
      }
    } catch (e) {
      debugPrint('JobService.toggleSavedRemote failed err=$e');
    }
    await toggleSaved(jobId: id, save: shouldSave);
  }

  Future<Set<String>> getSavedJobIdsRemote() async {
    final uid = SupabaseConfig.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return getSavedJobIds();
    try {
      final rows = await SupabaseService.select(savedTable, select: 'job_id', orderBy: 'created_at', ascending: false, limit: 500, filters: {'user_id': uid});
      final ids = rows.map((r) => (r['job_id'] ?? '').toString()).where((e) => e.trim().isNotEmpty).toSet();
      if (ids.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kSaved, jsonEncode(ids.toList(growable: false)));
      }
      return ids;
    } catch (e) {
      debugPrint('JobService.getSavedJobIdsRemote failed err=$e');
      return getSavedJobIds();
    }
  }

  Future<Set<String>> getSavedJobIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSaved);
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toSet();
    } catch (e) {
      debugPrint('JobService.getSavedJobIds failed err=$e');
      return <String>{};
    }
  }

  Future<void> toggleSaved({required String jobId, bool? save}) async {
    final id = jobId.trim();
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = (await getSavedJobIds()).toSet();
      final shouldSave = save ?? !set.contains(id);
      if (shouldSave) {
        set.add(id);
      } else {
        set.remove(id);
      }
      await prefs.setString(_kSaved, jsonEncode(set.toList(growable: false)));
    } catch (e) {
      debugPrint('JobService.toggleSaved failed err=$e');
    }
  }

  Future<List<JobApplication>> listLocalApplications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kApplications);
      if (raw == null || raw.trim().isEmpty) return const <JobApplication>[];
      return JobApplication.decodeList(raw);
    } catch (e) {
      debugPrint('JobService.listLocalApplications failed err=$e');
      return const <JobApplication>[];
    }
  }

  String _id(String prefix) {
    final rnd = Random.secure();
    final n = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${prefix}_$n';
  }

  List<JobPosting> _seedJobs() {
    final now = DateTime.now();
    return [
      JobPosting(
        id: 'job_ops_director',
        recruiterUserId: null,
        companyId: null,
        title: 'Directeur des Opérations',
        company: 'Kamoto Copper Company',
        companyLogoUrl: null,
        isVerifiedEmployer: true,
        location: 'Kolwezi, Lualaba',
        salary: r'$5,500 - $8,000',
        salaryMin: 5500,
        salaryMax: 8000,
        salaryCurrency: 'USD',
        type: 'Premium Gold',
        workMode: 'on_site',
        category: 'industry',
        industry: 'Mines & Énergie',
        experienceLevel: 'senior',
        description:
            'Pilotez l’exécution opérationnelle d’un site minier stratégique. Collaboration étroite avec la sécurité, la conformité et les équipes terrain. Poste certifié THIX (KYC entreprise + audits).',
        requirements: const [
          '10+ ans en opérations/industrie lourde',
          'Expérience gestion multi-sites',
          'Culture HSE et conformité',
          'Leadership & reporting',
        ],
        skills: const ['Ops', 'HSE', 'Compliance', 'Leadership'],
        responsibilities: const ['Piloter les opérations', 'Superviser HSE', 'Gouvernance et reporting'],
        benefits: const ['Assurance santé', 'Prime performance', 'Logement'],
        deadline: null,
        status: 'approved',
        applicantsCount: 42,
        isFeatured: true,
        isSuggested: true,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      JobPosting(
        id: 'job_cyber_expert',
        recruiterUserId: null,
        companyId: null,
        title: 'Expert en Cybersécurité',
        company: 'Ministère du Numérique',
        companyLogoUrl: null,
        isVerifiedEmployer: true,
        location: 'Kinshasa, Gombe',
        salary: r'$3,200 - $5,000',
        salaryMin: 3200,
        salaryMax: 5000,
        salaryCurrency: 'USD',
        type: 'Gouvernement',
        workMode: 'hybrid',
        category: 'government',
        industry: 'Cybersécurité',
        experienceLevel: 'senior',
        description:
            'Renforcez la posture cyber nationale: SOC, gestion des vulnérabilités, réponse à incident, politiques et audits. Dossiers sensibles – vérification THIX ID obligatoire.',
        requirements: const [
          'SOC / IR / Threat intel',
          'Sécurité Cloud & IAM',
          'Rédaction de politiques',
          'Capacité de travail en environnement régulé',
        ],
        skills: const ['SOC', 'IR', 'IAM', 'Cloud Security'],
        responsibilities: const ['Surveillance SOC', 'Réponse à incident', 'Audits'],
        benefits: const ['Mission d’impact', 'Formation continue'],
        deadline: null,
        status: 'approved',
        applicantsCount: 81,
        isFeatured: false,
        isSuggested: true,
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      JobPosting(
        id: 'job_infra_pm',
        recruiterUserId: null,
        companyId: null,
        title: 'Chef de Projet Infrastructure',
        company: 'Vodacom RDC',
        companyLogoUrl: null,
        isVerifiedEmployer: true,
        location: 'Lubumbashi',
        salary: r'$4,000+',
        salaryMin: 4000,
        salaryMax: null,
        salaryCurrency: 'USD',
        type: 'Temps Plein',
        workMode: 'on_site',
        category: 'full_time',
        industry: 'Télécoms',
        experienceLevel: 'mid',
        description:
            'Conduisez des programmes d’infrastructure critique (réseaux, data centers edge, résilience). Rigueur, gouvernance et coordination multi-équipes.',
        requirements: const [
          'PMO/Delivery en télécoms ou IT',
          'Gestion risques & dépendances',
          'Pilotage fournisseurs',
        ],
        skills: const ['PMO', 'Networking', 'Delivery'],
        responsibilities: const ['Planification', 'Coordination', 'Suivi KPI'],
        benefits: const ['Mutuelle', 'Bonus', 'Téléphone pro'],
        deadline: null,
        status: 'approved',
        applicantsCount: 27,
        isFeatured: false,
        isSuggested: false,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
      JobPosting(
        id: 'job_risk_analyst',
        recruiterUserId: null,
        companyId: null,
        title: 'Analyste Senior Risques',
        company: 'Rawbank',
        companyLogoUrl: null,
        isVerifiedEmployer: true,
        location: 'Kinshasa',
        salary: r'$2,800 - $4,500',
        salaryMin: 2800,
        salaryMax: 4500,
        salaryCurrency: 'USD',
        type: 'Hybride',
        workMode: 'hybrid',
        category: 'full_time',
        industry: 'Banque & Finance',
        experienceLevel: 'senior',
        description:
            'Analyse des risques, conformité, scoring et gouvernance. Collaboration avec cybersécurité et fraude. Priorité aux profils certifiés THIX.',
        requirements: const [
          'Banque/finance – risk/compliance',
          'Analyse data & reporting',
          'Gestion incidents fraude',
        ],
        skills: const ['Risk', 'Compliance', 'Analytics'],
        responsibilities: const ['Analyser risques', 'Reporting', 'Contrôles'],
        benefits: const ['Assurance', 'Plan de carrière'],
        deadline: null,
        status: 'approved',
        applicantsCount: 19,
        isFeatured: true,
        isSuggested: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

