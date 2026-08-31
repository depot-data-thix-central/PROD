// lib/presentation/home/widgets/account_request_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// ENUM EXTENSIBLE (préparé pour futures options)
// ============================================================================
enum AccountRequestChoice {
  personal,
  // business,    // À décommenter quand disponible
  // enterprise,  // À décommenter quand disponible
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class AccountRequestSheet extends StatelessWidget {
  const AccountRequestSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: ThixPolicy.s20,
          right: ThixPolicy.s20,
          top: ThixPolicy.s12,
          bottom: ThixPolicy.s20 + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            _SheetHandle(),
            
            const SizedBox(height: ThixPolicy.s16),

            // Header
            _SheetHeader(
              title: l10n.t('account_request_title'),
              subtitle: l10n.t('account_request_subtitle'),
            ),

            const SizedBox(height: ThixPolicy.s20),

            // Options
            _OptionButton(
              icon: Icons.person_outline_rounded,
              title: l10n.t('account_personal'),
              subtitle: l10n.t('account_personal_desc'),
              onTap: () => _handleChoice(context, AccountRequestChoice.personal),
            ),

            // Placeholder pour futures options
            // const SizedBox(height: ThixPolicy.s12),
            // _OptionButton(
            //   icon: Icons.business_outlined,
            //   title: l10n.t('account_business'),
            //   subtitle: l10n.t('account_business_desc'),
            //   onTap: () => _handleChoice(context, AccountRequestChoice.business),
            // ),

            const SizedBox(height: ThixPolicy.s16),

            // Bouton Annuler
            _CancelButton(
              label: l10n.t('common_cancel'),
              onTap: () => _handleCancel(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChoice(BuildContext context, AccountRequestChoice choice) {
    HapticFeedback.selectionClick();
    debugPrint('[AccountRequestSheet] ✓ Selected: ${choice.name}');
    Navigator.pop(context, choice);
  }

  void _handleCancel(BuildContext context) {
    HapticFeedback.lightImpact();
    debugPrint('[AccountRequestSheet] ❌ Cancelled');
    Navigator.pop(context);
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: ThixPolicy.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SheetHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ThixPolicy.h3Style.copyWith(
            fontSize: 18,
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: ThixPolicy.bodySmallStyle.copyWith(
            color: ThixPolicy.textMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _OptionButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<_OptionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(ThixPolicy.s12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isPressed 
                      ? ThixPolicy.primary.withOpacity(0.3)
                      : ThixPolicy.border,
                  width: _isPressed ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
                color: _isPressed
                    ? ThixPolicy.primary.withOpacity(0.04)
                    : ThixPolicy.surface,
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      color: ThixPolicy.primary,
                      size: 22,
                    ),
                  ),
                  
                  const SizedBox(width: ThixPolicy.s12),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontSize: 14,
                            fontWeight: ThixPolicy.bold,
                            color: ThixPolicy.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 11,
                            color: ThixPolicy.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Arrow
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ThixPolicy.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CancelButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        style: TextButton.styleFrom(
          foregroundColor: ThixPolicy.textSecondary,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: ThixPolicy.labelStyle.copyWith(
            fontSize: 14,
            fontWeight: ThixPolicy.semiBold,
          ),
        ),
      ),
    );
  }
}
