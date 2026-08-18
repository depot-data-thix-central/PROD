// lib/presentation/thix_money/widgets/service_grid.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/nav.dart';

class _Service {
  final String label;
  final Color color; 
  final IconData icon;
  final String? route;
  const _Service({required this.label, required this.color, required this.icon, this.route});
}

class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key});

  // Ta liste de services avec les couleurs et routes connectées
  static const _services = [
    _Service(label: 'Crédit', color: Color(0xFF1E3A8A), icon: Icons.bolt_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Assurance', color: Color(0xFF0F766E), icon: Icons.security_outlined, route: null),
    _Service(label: 'Épargne', color: Color(0xFFB45309), icon: Icons.savings_outlined, route: AppRoutes.thixMoneySavings),
    _Service(label: 'Change', color: Color(0xFF6D28D9), icon: Icons.currency_exchange_outlined, route: null),
    _Service(label: 'Marchand', color: Color(0xFFC2410C), icon: Icons.storefront_outlined, route: AppRoutes.thixMarket),
    _Service(label: 'Dons', color: Color(0xFFBE123C), icon: Icons.favorite_border_rounded, route: null),
    _Service(label: 'Tontine', color: Color(0xFF0369A1), icon: Icons.groups_outlined, route: AppRoutes.thixMoneyTontines),
    _Service(label: 'Éducation', color: Color(0xFF0E7490), icon: Icons.school_outlined, route: AppRoutes.education),
    _Service(label: 'Virement', color: Color(0xFF1D4ED8), icon: Icons.language_outlined, route: AppRoutes.thixMoneySend),
    _Service(label: 'Microfinance', color: Color(0xFF15803D), icon: Icons.account_balance_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Investir', color: Color(0xFFB45309), icon: Icons.show_chart_rounded, route: AppRoutes.thixMoneyInvestments),
    _Service(label: 'Planifier', color: Color(0xFF0F172A), icon: Icons.calendar_month_outlined, route: AppRoutes.thixMoneySavings),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003882).withOpacity(0.04), // Ombre très premium
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 18,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: _services.length,
        itemBuilder: (_, i) {
          final s = _services[i];
          
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (s.route != null && s.route!.isNotEmpty) {
                context.push(s.route!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${s.label} sera bientôt disponible !'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: s.color, // S'adapte à la couleur du service
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Le conteneur en relief avec le fond teinté
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.08), // Fond pastel basé sur ta couleur
                    borderRadius: BorderRadius.circular(14), // Coins carrés arrondis style iOS
                  ),
                  child: Icon(s.icon, color: s.color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  s.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2A4F), // Texte bleu nuit foncé élégant
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
