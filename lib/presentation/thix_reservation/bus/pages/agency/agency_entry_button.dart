// lib/presentation/thix_reservation/bus/pages/agency/agency_entry_button.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/agency_dashboard_provider.dart';

class AgencyEntryButton extends StatelessWidget {
  const AgencyEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AgencyDashboardProvider>(
      builder: (_, provider, __) {
        // Si pas d'agence, on propose de créer
        final hasAgency = provider.hasAgency;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              if (hasAgency) {
                context.push('/thix-reservation/bus/agency/dashboard');
              } else {
                context.push('/thix-reservation/bus/agency/onboarding');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasAgency? const Color(0xFF0A3D62): Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hasAgency? const Color(0xFF0A3D62): Colors.orange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(hasAgency? Icons.dashboard_customize: Icons.add_business, color: hasAgency? Colors.white: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 8),
                  Text(hasAgency? 'Gérer mon Agence (${provider.myAgency?.name})': 'Devenir Agence Partenaire',
                      style: TextStyle(color: hasAgency? Colors.white: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, size: 12, color: hasAgency? Colors.white70: Colors.orange.shade800),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
