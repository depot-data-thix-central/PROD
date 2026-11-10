// ============================================================================
// FICHIER : lib/presentation/thix_incubator/pages/program_details_page.dart
// Module  : thix_incubator
// Route   : /incubator/program/:programId
// Stack   : Riverpod moderne (ConsumerStatefulWidget + ref) — zéro provider/*
// ============================================================================
// Détail d'un programme d'incubation + candidature.
// Sécurité :
//   - validation stricte de l'ID avant requête
//   - vérification session utilisateur (pas de candidature anonyme)
//   - anti double-submit sur le bouton CTA
//   - CTA dynamique selon statut DB (open/closed/upcoming/applied)
//   - sanitization de l'URL cover
//   - rate-limiting soft (cooldown 30s entre tentatives)
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, debugPrintStack;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../nav.dart';
import '../../../providers/incubator_provider.dart';
import '../../../services/incubator_service.dart';
import '../../../models/incubator_program.dart';
import 'incubator_home_page.dart'; // pour IncubatorColors

class ProgramDetailsPage extends ConsumerStatefulWidget {
  const ProgramDetailsPage({super.key, required this.programId});
  final String programId;

  @override
  ConsumerState<ProgramDetailsPage> createState() => _ProgramDetailsPageState();
}

class _ProgramDetailsPageState extends ConsumerState<ProgramDetailsPage> {
  IncubatorProgram? _program;
  ProgramDetailsState _state = ProgramDetailsState.loading;
  String? _errorMessage;

  // Anti-double-submit
  bool _isSubmitting = false;
  DateTime? _lastAttemptAt;
  static const Duration _cooldown = Duration(seconds: 30);

  // État candidature utilisateur (null = non candidat, 'pending', 'accepted'…)
  String? _userApplicationStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pré-charger l'état global incubator (pour les mentors, etc.)
      if (ref.read(incubatorProvider).status == IncubatorStatus.idle) {
        ref.read(incubatorProvider.notifier).loadAll();
      }
      _load();
    });
  }

  Future<void> _load() async {
    // 1. Validation de l'ID (anti-injection, anti crash)
    final id = widget.programId.trim();
    if (id.isEmpty || id.length > 128) {
      setState(() {
        _state = ProgramDetailsState.error;
        _errorMessage = 'Identifiant de programme invalide.';
      });
      return;
    }

    setState(() {
      _state = ProgramDetailsState.loading;
      _errorMessage = null;
    });

    try {
      final service = ref.read(incubatorServiceProvider);
      final program = await service.fetchProgram(id);
      if (!mounted) return;

      if (program == null) {
        setState(() {
          _state = ProgramDetailsState.notFound;
        });
        return;
      }

      // 2. Vérifier le statut candidature utilisateur courant
      final userStatus = await service.checkUserApplicationStatus(id);

      if (!mounted) return;
      setState(() {
        _program = program;
        _userApplicationStatus = userStatus;
        _state = ProgramDetailsState.loaded;
      });
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ProgramDetailsState.error;
        _errorMessage = 'Délai d\'attente dépassé. Vérifiez votre connexion.';
      });
      if (kDebugMode) debugPrint('Timeout: $e');
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _state = ProgramDetailsState.error;
        _errorMessage =
            kDebugMode ? e.toString() : 'Impossible de charger le programme.';
      });
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }

  // --------------------------------------------------------------------------
  // CANDIDATURE
  // --------------------------------------------------------------------------
  Future<void> _onApply() async {
    // Garde : session authentifiée (RLS Supabase fait le reste côté serveur)
    final isAuth = Supabase.instance.client.auth.currentUser != null;
    if (!isAuth) {
      context.go(AppRoutes.login);
      return;
    }

    // Cooldown anti-spam
    if (_lastAttemptAt != null &&
        DateTime.now().difference(_lastAttemptAt!) < _cooldown) {
      final remaining = _cooldown - DateTime.now().difference(_lastAttemptAt!);
      _showInfo('Veuillez patienter ${remaining.inSeconds}s avant de réessayer.');
      return;
    }

    // État DB : fermé ou déjà candidat → bloque
    if (_userApplicationStatus != null && _userApplicationStatus != 'none') {
      _showInfo('Vous avez déjà candidaté à ce programme.');
      return;
    }
    if (_program?.status != 'open') {
      _showInfo('Les candidatures pour ce programme sont fermées.');
      return;
    }

    _lastAttemptAt = DateTime.now();
    await _showApplicationSheet();
  }

  Future<void> _showApplicationSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplicationBottomSheet(program: _program!),
    );
    if (result == true && mounted) {
      setState(() {
        _userApplicationStatus = 'pending';
      });
      _showSuccess('Candidature envoyée avec succès !');
      HapticFeedback.mediumImpact();
    }
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: IncubatorColors.textPrimary(context),
      ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: IncubatorColors.validationGreen,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IncubatorColors.background(context),
      body: _buildBody(),
      bottomNavigationBar: _state == ProgramDetailsState.loaded
          ? _StickyCta(
              program: _program!,
              userStatus: _userApplicationStatus,
              isSubmitting: _isSubmitting,
              onApply: _onApply,
            )
          : null,
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      ProgramDetailsState.loading => const _DetailsSkeleton(),
      ProgramDetailsState.notFound => _NotFound(onBack: () => context.pop()),
      ProgramDetailsState.error => _DetailsError(
          message: _errorMessage ?? 'Erreur inconnue',
          onRetry: _load,
        ),
      ProgramDetailsState.loaded => _DetailsContent(program: _program!),
    };
  }
}

enum ProgramDetailsState { loading, loaded, notFound, error }

// ============================================================================
// CONTENT — ConsumerWidget pour accéder à ref (mentors via incubatorProvider)
// ============================================================================
class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({required this.program});
  final IncubatorProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = program.coverUrl;
    final mentors = ref.watch(incubatorProvider).mentorsForProgram(program.id);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // SliverAppBar avec cover image
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: IncubatorColors.background(context),
          leading: const _BackButton(),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null && cover.isNotEmpty)
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CoverFallbackBig(),
                  )
                else
                  const _CoverFallbackBig(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          program.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        program.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        program.organizer,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stats rapides
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IncubatorColors.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: IncubatorColors.border(context)),
            ),
            child: Row(
              children: [
                _StatMini(
                  icon: Icons.calendar_month_rounded,
                  label: 'Durée',
                  value: '${program.durationWeeks} sem.',
                  color: IncubatorColors.electricBlue,
                ),
                _StatMini(
                  icon: Icons.group_rounded,
                  label: 'Places',
                  value: '${program.seatsRemaining}',
                  color: IncubatorColors.institutionalBlue,
                ),
                _StatMini(
                  icon: Icons.event_rounded,
                  label: 'Deadline',
                  value: program.deadlineLabel,
                  color: IncubatorColors.danger,
                ),
                _StatMini(
                  icon: Icons.map_rounded,
                  label: 'Lieu',
                  value: program.location,
                  color: IncubatorColors.validationGreen,
                ),
              ],
            ),
          ),
        ),

        // Description
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _Card(
              title: 'Présentation',
              child: Text(
                program.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: IncubatorColors.textPrimary(context),
                ),
              ),
            ),
          ),
        ),

        // Éligibilité
        if (program.eligibility.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _Card(
                title: 'Éligibilité',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: program.eligibility
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: IncubatorColors.validationGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: IncubatorColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),

        // Mentors associés (DB) — via Riverpod
        if (mentors.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mentors associés',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: IncubatorColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mentors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _MentorChip(mentor: mentors[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Espace pour le CTA sticky
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: IncubatorColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: IncubatorColors.textPrimary(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: IncubatorColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MentorChip extends StatelessWidget {
  const _MentorChip({required this.mentor});
  final dynamic mentor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IncubatorColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IncubatorColors.border(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: IncubatorColors.electricBlue.withValues(alpha: 0.15),
            child: const Icon(Icons.person_rounded,
                color: IncubatorColors.electricBlue, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            mentor.name as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: IncubatorColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFallbackBig extends StatelessWidget {
  const _CoverFallbackBig();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              IncubatorColors.nightBlue,
              IncubatorColors.institutionalBlue,
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.school_rounded, color: Colors.white, size: 72),
        ),
      );
}

// ============================================================================
// STICKY CTA — bouton piloté par DB
// ============================================================================
class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.program,
    required this.userStatus,
    required this.isSubmitting,
    required this.onApply,
  });
  final IncubatorProgram program;
  final String? userStatus;
  final bool isSubmitting;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final (label, color, enabled, icon) = _resolveCta();
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: IncubatorColors.background(context),
        border: Border(
          top: BorderSide(color: IncubatorColors.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: enabled && !isSubmitting ? onApply : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(icon),
            label: Text(
              isSubmitting ? 'Envoi en cours…' : label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, Color, bool, IconData) _resolveCta() {
    if (userStatus != null && userStatus != 'none') {
      return switch (userStatus!) {
        'pending' => ('Candidature en cours', IncubatorColors.warning, false,
            Icons.hourglass_top_rounded),
        'accepted' => ('Candidature acceptée', IncubatorColors.validationGreen,
            false, Icons.check_circle_rounded),
        'rejected' => ('Candidature refusée', IncubatorColors.textSecondaryLight,
            false, Icons.close_rounded),
        _ => ('Consulter', IncubatorColors.electricBlue, true,
            Icons.arrow_forward_rounded),
      };
    }
    return switch (program.status) {
      'open' => ('Postuler', IncubatorColors.electricBlue, true,
          Icons.send_rounded),
      'upcoming' => ('Candidatures bientôt ouvertes', IncubatorColors.warning,
          false, Icons.event_busy_rounded),
      'closed' => ('Programme fermé', IncubatorColors.textSecondaryLight, false,
          Icons.lock_rounded),
      _ => ('Postuler', IncubatorColors.electricBlue, true, Icons.send_rounded),
    };
  }
}

// ============================================================================
// BOTTOM SHEET — Formulaire de candidature sécurisé (ConsumerStatefulWidget)
// ============================================================================
class _ApplicationBottomSheet extends ConsumerStatefulWidget {
  const _ApplicationBottomSheet({required this.program});
  final IncubatorProgram program;

  @override
  ConsumerState<_ApplicationBottomSheet> createState() =>
      _ApplicationBottomSheetState();
}

class _ApplicationBottomSheetState
    extends ConsumerState<_ApplicationBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  bool _acceptTerms = false;
  bool _submitting = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\p{C}]', unicode: true), '').trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez accepter les conditions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    try {
      final service = ref.read(incubatorServiceProvider);
      await service.submitApplication(
        programId: widget.program.id,
        programTitle: widget.program.title,
        message: _sanitize(_messageCtrl.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TimeoutException {
      if (!mounted) return;
      _showError('Délai d\'attente dépassé. Réessayez.');
    } catch (e) {
      if (!mounted) return;
      _showError(kDebugMode
          ? 'Erreur: $e'
          : 'Impossible d\'envoyer votre candidature.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: IncubatorColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: IncubatorColors.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: IncubatorColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Postuler à ${widget.program.title}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: IncubatorColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Présentez brièvement votre projet et votre motivation.',
              style: TextStyle(
                fontSize: 12,
                color: IncubatorColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              maxLength: 2000,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Votre message',
                hintText: 'Ex: Mon projet, mes objectifs, pourquoi ce programme…',
                filled: true,
                fillColor: IncubatorColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(
                  fontSize: 10,
                  color: IncubatorColors.textSecondary(context),
                ),
              ),
              validator: (v) {
                final clean = _sanitize(v ?? '');
                if (clean.length < 30) {
                  return 'Votre message doit contenir au moins 30 caractères.';
                }
                if (clean.length > 2000) {
                  return 'Message trop long (max 2000 caractères).';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _acceptTerms = v ?? false),
                  activeColor: IncubatorColors.electricBlue,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _submitting
                        ? null
                        : () => setState(() => _acceptTerms = !_acceptTerms),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'J\'accepte ',
                              style: TextStyle(
                                fontSize: 12,
                                color: IncubatorColors.textPrimary(context),
                              ),
                            ),
                            TextSpan(
                              text: 'les conditions d\'incubation',
                              style: TextStyle(
                                fontSize: 12,
                                color: IncubatorColors.electricBlue,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(
                              text: ' et la politique de confidentialité.',
                              style: TextStyle(
                                fontSize: 12,
                                color: IncubatorColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_submitting || !_acceptTerms) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IncubatorColors.electricBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      IncubatorColors.electricBlue.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Envoyer ma candidature',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON
// ============================================================================
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: IncubatorColors.border(context),
      highlightColor: IncubatorColors.card(context),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            backgroundColor: Colors.white,
            flexibleSpace: Container(color: Colors.white),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 100,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18))),
                  const SizedBox(height: 20),
                  Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(
                      height: 100,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: IncubatorColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 56, color: IncubatorColors.warning),
            ),
            const SizedBox(height: 24),
            Text(
              'Programme introuvable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: IncubatorColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ce programme n\'existe plus ou a été supprimé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: IncubatorColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: IncubatorColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 56, color: IncubatorColors.danger),
            ),
            const SizedBox(height: 24),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: IncubatorColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            if (kDebugMode)
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: IncubatorColors.textSecondary(context),
                  fontFamily: 'monospace',
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: IncubatorColors.electricBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
