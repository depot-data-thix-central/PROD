import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/external_link_service.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/theme.dart';

class OpportunityApplyPage extends StatefulWidget {
  final String opportunityId;
  const OpportunityApplyPage({super.key, required this.opportunityId});

  @override
  State<OpportunityApplyPage> createState() => _OpportunityApplyPageState();
}

class _OpportunityApplyPageState extends State<OpportunityApplyPage> {
  final _service = OpportunityService();
  final _profileService = ProfileService();
  final _thixCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _thixCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final thixId = auth.currentUser?.thixId ?? '';
    if (_thixCtrl.text.trim().isEmpty && thixId.trim().isNotEmpty) {
      _thixCtrl.text = thixId;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final canonical = ThixIdService.canonicalizeOrNull(_thixCtrl.text);
      if (canonical == null || !ThixIdService.isValid(canonical)) {
        setState(() => _error = 'THIX ID invalide. Exemple: ${ThixIdService.exampleV2}');
        return;
      }

      final profile = await _profileService.fetchPublicProfileByThixId(canonical);
      if (profile == null) {
        setState(() => _error = 'Aucun profil trouvé pour ce THIX ID. Vérifie l’ID ou contacte le support.');
        return;
      }

      final opp = await _service.fetchOpportunity(widget.opportunityId);
      final baseUrl = opp?.applyUrl;
      if (baseUrl == null || baseUrl.trim().isEmpty) {
        setState(() => _error = 'Lien externe indisponible pour cette opportunité.');
        return;
      }

      final uri = Uri.tryParse(baseUrl.trim());
      if (uri == null) {
        setState(() => _error = 'Lien externe invalide.');
        return;
      }

      final out = uri.replace(queryParameters: {...uri.queryParameters, 'thix_id': canonical});
      final ok = await ExternalLinkService.open(out.toString());
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Impossible d’ouvrir le lien.');
        return;
      }

      // Retourner vers les détails après ouverture du lien.
      context.pushReplacement('/opportunities/${widget.opportunityId}?applied=1');
    } catch (e) {
      debugPrint('OpportunityApplyPage.submit failed err=$e');
      if (!mounted) return;
      setState(() => _error = 'Erreur lors de la candidature. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = auth.currentUser;

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder(
          future: _service.fetchOpportunity(widget.opportunityId),
          builder: (context, snap) {
            final opp = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (opp == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TopBar(opportunityId: widget.opportunityId),
                    const Spacer(),
                    Text('Opportunité introuvable.', style: context.textStyles.titleMedium?.copyWith(color: context.theme.colorScheme.onSurface)),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.canPop() ? context.pop() : context.push('/opportunities/${widget.opportunityId}'), child: const Text('Retour'))),
                    const Spacer(),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(opportunityId: widget.opportunityId),
                  const SizedBox(height: AppSpacing.md),
                  Text('Postuler', style: context.textStyles.titleLarge?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(opp.title, style: context.textStyles.titleMedium?.copyWith(color: LightModeColors.secondaryText, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: LightModeColors.accent.withValues(alpha: 0.45), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: LightModeColors.success),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Vérification THIX ID + redirection',
                                style: context.textStyles.titleSmall?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          me?.hasRealThixId == true
                              ? 'Nous avons pré-rempli ton THIX ID. Ensuite on ouvre le site officiel.'
                              : 'Entre ton THIX ID (il sera vérifié), puis on ouvrira le site officiel.',
                          style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.secondaryText, height: 1.5),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _thixCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(labelText: 'THIX ID', hintText: ThixIdService.exampleV2, prefixIcon: const Icon(Icons.badge_rounded)),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!, style: context.textStyles.bodyMedium?.copyWith(color: context.theme.colorScheme.error, fontWeight: FontWeight.w800)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                            label: Text(_loading ? 'Ouverture…' : 'Ouvrir le lien de candidature'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String opportunityId;
  const _TopBar({required this.opportunityId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.push('/opportunities/$opportunityId'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(child: Text('THIX Apply', style: context.textStyles.titleLarge?.copyWith(color: context.theme.colorScheme.onSurface, fontWeight: FontWeight.w900))),
      ],
    );
  }
}

extension _ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
