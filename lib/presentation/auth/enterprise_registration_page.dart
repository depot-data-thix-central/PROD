import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme.dart';
import '../../nav.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/profile_photo_service.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class FormLabel extends StatelessWidget {
  final String label;
  final bool required;

  const FormLabel({
    super.key,
    required this.label,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (required) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '*',
              style: theme.textTheme.labelLarge?.copyWith(
                color: LightModeColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const SectionHeader({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: LightModeColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF0A2F5C),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: LightModeColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class EnterpriseRegistrationPage extends StatefulWidget {
  const EnterpriseRegistrationPage({super.key});

  @override
  State<EnterpriseRegistrationPage> createState() =>
      _EnterpriseRegistrationPageState();
}

class _EnterpriseRegistrationPageState
    extends State<EnterpriseRegistrationPage> {
  final _profileService = ProfileService();
  final _photos = ProfilePhotoService();

  final _companyNameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;

  PlatformFile? _pickedPhoto;
  PhoneAuthSession? _phoneSession;

  bool _hasSupabaseSession() {
    return Supabase.instance.client.auth.currentSession != null;
  }

  void _handleUnauthedWrite() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session expirée. Connectez-vous pour continuer.',
        ),
      ),
    );

    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _companyNameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();

    super.dispose();
  }

  Future<void> _createEnterprise() async {
    final auth = context.read<AuthController>();

    final name = _companyNameC.text.trim();
    final email = _emailC.text.trim();
    final pass = _passwordC.text;
    final confirm = _confirmC.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez compléter Entreprise, Email et Mot de passe.',
          ),
        ),
      );
      return;
    }

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les mots de passe ne correspondent pas.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_looksLikePhone(email) && !email.contains('@')) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Inscription par SMS non disponible dans la Preview web.',
              ),
            ),
          );
          return;
        }

        if (_phoneSession == null) {
          _phoneSession = await auth.startPhoneAuth(
            phoneNumber: email,
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS envoyé. Entrez le code dans “Mot de passe”.',
              ),
            ),
          );

          return;
        }

        await auth.confirmPhoneCode(
          session: _phoneSession!,
          smsCode: pass,
          displayName: name,
          accountType: AccountType.enterprise,
        );

        if (!mounted) return;

        await _prepareEnterpriseAndFinishFree(
          companyName: name,
        );

        return;
      }

      await auth.registerEnterprise(
        email: email,
        password: pass,
        displayName: name,
        rememberMe: _rememberMe,
        profileDraft: {
          'registration_status': 'draft',
          'display_name': name,
        },
      );

      if (!mounted) return;

      await _prepareEnterpriseAndFinishFree(
        companyName: name,
      );
    } catch (e) {
      debugPrint('Enterprise registration failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _prepareEnterpriseAndFinishFree({
    required String companyName,
  }) async {
    final me = context.read<AuthController>().currentUser;

    if (me == null) {
      throw Exception('Session utilisateur introuvable.');
    }

    if (!_hasSupabaseSession()) {
      _handleUnauthedWrite();
      return;
    }

    try {
      await _profileService.updateProfile(
        userId: me.id,
        displayName: companyName,
      );

      if (_pickedPhoto != null) {
        try {
          final url = await _photos.uploadProfilePhoto(
            uid: me.id,
            file: _pickedPhoto!,
          );

          await _profileService.updateProfile(
            userId: me.id,
            photoUrl: url,
          );
        } catch (e) {
          debugPrint(
            'EnterpriseReg: avatar upload failed uid=${me.id} err=$e',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
              ),
            );
          }

          rethrow;
        }
      }

      final existingProfile =
          await _profileService.fetchPublicProfileByUserId(me.id);

      final currentThixId =
          existingProfile?.thixId ?? me.thixId;

      if (currentThixId.isEmpty ||
          currentThixId == 'THIX-PENDING' ||
          currentThixId == 'THIX-000000') {
        final newThixId = await _profileService.generateThixId(
          uid: me.id,
        );

        // ✅ PARAMÈTRE CORRECT : 'thixId' (pas 'thixid')
        await _profileService.updateProfile(
          userId: me.id,
          thixId: newThixId,
        );

        final updatedUser = me.copyWith(
          thixId: newThixId,
        );

        await context
            .read<AuthController>()
            .updateCurrentUser(updatedUser);
      }

      final suggestedChat =
          '@${companyName.toLowerCase().replaceAll(RegExp(r"[^a-z0-9._]"), '')}${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

      final claimedChat =
          await _profileService.reserveThixChat(
        userId: me.id,
        desired: suggestedChat,
      );

      await _profileService.updateProfile(
        userId: me.id,
        thixChat: claimedChat,
      );
    } catch (e) {
      debugPrint(
        'EnterpriseReg: prepare identifiers failed uid=${me.id} err=$e',
      );

      if (mounted) {
        final msg = e.toString();

        if (msg.contains('Not authenticated') ||
            msg.toLowerCase().contains('jwt') ||
            msg.contains('42501')) {
          _handleUnauthedWrite();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
          ),
        );
      }

      rethrow;
    }

    if (!mounted) return;

    context.go(AppRoutes.enterpriseDashboard);
  }

  Future<void> _pickPhoto() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
        allowMultiple: false,
      );

      if (res == null || res.files.isEmpty) return;

      setState(() {
        _pickedPhoto = res.files.first;
      });
    } catch (e) {
      debugPrint(
        'EnterpriseReg: pick photo failed err=$e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sélection image impossible.',
          ),
        ),
      );
    }
  }

  bool _looksLikePhone(String s) {
    return RegExp(
      r'^\+?[0-9][0-9\s\-]{7,}$',
    ).hasMatch(s.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Compte Entreprise',
                        style: theme.textTheme.titleLarge,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      TextField(
                        controller: _companyNameC,
                        decoration: const InputDecoration(
                          hintText: "Nom de l'entreprise",
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      TextField(
                        controller: _emailC,
                        decoration: const InputDecoration(
                          hintText: 'Email administrateur',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      TextField(
                        controller: _passwordC,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Mot de passe',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      TextField(
                        controller: _confirmC,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText:
                              'Confirmer le mot de passe',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _createEnterprise,
                        child: Text(
                          _isLoading
                              ? 'Création...'
                              : 'Créer le compte',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
