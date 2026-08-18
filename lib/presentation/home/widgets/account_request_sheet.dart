// lib/presentation/home/widgets/account_request_sheet.dart
import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

enum AccountRequestChoice { personal }

class AccountRequestSheet extends StatelessWidget {
  const AccountRequestSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 35, 
              height: 4, 
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              l10n.t('account_request_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: ThixPolicy.s20),
            _OptionButton(
              icon: Icons.person_outline,
              title: l10n.t('account_personal'),
              subtitle: l10n.t('account_personal_desc'),
              onTap: () {
                Navigator.pop(context, AccountRequestChoice.personal);
              },
            ),
            const SizedBox(height: ThixPolicy.s12),
          ],
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s12),
        decoration: BoxDecoration(
          border: Border.all(color: ThixPolicy.border),
          borderRadius: BorderRadius.circular(14),
          color: ThixPolicy.surface,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ThixPolicy.textMain.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ThixPolicy.textMain, size: 20),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: ThixPolicy.textSecondary),
          ],
        ),
      ),
    );
  }
}
