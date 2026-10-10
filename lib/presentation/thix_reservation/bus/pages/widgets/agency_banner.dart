import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

class AgencyBanner extends StatelessWidget {
  final bool hasAgency;
  final String? agencyName;
  final VoidCallback onTap;

  const AgencyBanner({
    super.key,
    required this.hasAgency,
    required this.agencyName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final domainColor = ThixPolicy.domainReservation;

    final String label = hasAgency
        ? '${l10n.t('agency_manage_dashboard')} (${agencyName ?? ''})'
        : l10n.t('agency_become_partner');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: ThixPolicy.s14,
            vertical: ThixPolicy.s12,
          ),
          decoration: BoxDecoration(
            color: hasAgency
                ? domainColor
                : ThixPolicy.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: hasAgency
                  ? domainColor
                  : ThixPolicy.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasAgency
                    ? Icons.dashboard_customize_rounded
                    : Icons.add_business_rounded,
                color: hasAgency ? Colors.white : ThixPolicy.warning,
                size: 18,
              ),
              SizedBox(width: ThixPolicy.s8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: hasAgency ? Colors.white : ThixPolicy.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: hasAgency ? Colors.white70 : ThixPolicy.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
