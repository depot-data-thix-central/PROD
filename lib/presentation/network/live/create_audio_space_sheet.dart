import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/services/live/audio_space_service.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/network/live/audio_space_room_screen.dart';

class CreateAudioSpaceSheet extends ConsumerStatefulWidget {
  const CreateAudioSpaceSheet({super.key});

  @override
  ConsumerState<CreateAudioSpaceSheet> createState() => _CreateAudioSpaceSheetState();
}

class _CreateAudioSpaceSheetState extends ConsumerState<CreateAudioSpaceSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _topic = 'entrepreneuriat';
  bool _verifiedOnly = false;
  bool _recording = false;
  bool _consent = false;
  bool _busy = false;
  String? _error;

  String _tx(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fallback : v;
  }

  String _humanError(Object e) {
    final msg = e.toString();
    if (msg.contains('23505') || msg.contains('audio_spaces_channel_name_key')) {
      return 'Un salon utilise déjà ce canal. Réessaie — un nouveau canal va être généré.';
    }
    if (msg.contains('JWT') || msg.contains('auth') || msg.contains('Session')) {
      return 'Session expirée. Reconnecte-toi.';
    }
    return msg.replaceFirst('Exception: ', '').replaceFirst('PostgrestException', 'Erreur serveur');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final err = AudioSpaceSanitizer.validateTitle(_title.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_recording && !_consent) {
      setState(() => _error = _tx(l10n, 'audio_space_consent_required', 'Le consentement d\'enregistrement est obligatoire.'));
      return;
    }
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      setState(() => _error = _tx(l10n, 'audio_space_auth_required', 'Connecte-toi avec ton THIX ID.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final space = await ref.read(audioSpaceServiceProvider).createSpace(
            title: _title.text,
            description: _desc.text,
            topic: _topic,
            hostName: user.displayName,
            hostAvatarUrl: user.photoUrl,
            requireVerifiedSpeakers: _verifiedOnly,
            recordingEnabled: _recording,
            recordingConsent: _consent,
          );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AudioSpaceRoomScreen(space: space)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _humanError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              _tx(l10n, 'audio_space_create_title', 'Nouveau salon audio THIX'),
              style: ThixPolicy.h2Style.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 100,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
              decoration: InputDecoration(
                labelText: _tx(l10n, 'audio_space_title_label', 'Titre du salon'),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLength: 500,
              maxLines: 3,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
              decoration: InputDecoration(
                labelText: _tx(l10n, 'audio_space_desc_label', 'Description'),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['entrepreneuriat', 'tech', 'education', 'sante', 'culture']
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: _topic == t,
                        onSelected: (_) => setState(() => _topic = t),
                      ))
                  .toList(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tx(l10n, 'audio_space_verified_only', 'Intervenants vérifiés uniquement')),
              value: _verifiedOnly,
              onChanged: (v) => setState(() => _verifiedOnly = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tx(l10n, 'audio_space_recording', 'Enregistrer le salon')),
              value: _recording,
              onChanged: (v) => setState(() {
                _recording = v;
                if (!v) _consent = false;
              }),
            ),
            if (_recording)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                title: Text(_tx(l10n, 'audio_space_consent', 'Je confirme le consentement d\'enregistrement')),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: ThixPolicy.danger)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ThixPolicy.domainMedia, // Utilisation propre du ThixPolicy
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_tx(l10n, 'audio_space_start', 'Démarrer')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
