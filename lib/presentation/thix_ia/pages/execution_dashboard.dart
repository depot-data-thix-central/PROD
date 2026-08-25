// lib/presentation/thix_ia/pages/execution_dashboard.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/thix_design_policy.dart';

/// ============================================================================
/// EXECUTION DASHBOARD (SAAS MODE)
/// Code modulaire de production - Architecture prête pour des millions d'utilisateurs.
/// ============================================================================

class ExecutionDashboard extends ConsumerWidget {
  const ExecutionDashboard({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 💡 Ici, tu lieras plus tard tes Providers (ex: financialProvider, kanbanProvider)
    // Pour l'instant, on utilise des données statiques pour le design.

    return Container(
      // Un fond subtil pour faire ressortir l'effet "Glassmorphism" des cartes
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50.withOpacity(0.3),
            Colors.purple.shade50.withOpacity(0.3),
            Colors.white,
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: const [
          _SectionTitle(title: 'Financial Engine', subtitle: 'Santé financière en temps réel'),
          SizedBox(height: 16),
          _MainFinancialCard(),
          SizedBox(height: 16),
          _QuickStatsRow(),
          
          SizedBox(height: 32),
          
          _SectionTitle(title: 'Auto-Kanban', subtitle: 'Tâches générées par l\'IA'),
          SizedBox(height: 16),
          _KanbanPreviewList(),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS UI : LUMINOUS GLASSMORPHISM
// ============================================================================

class _MainFinancialCard extends StatelessWidget {
  const _MainFinancialCard();

  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      shadowColor: ThixPolicy.primary.withOpacity(0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 14, color: ThixPolicy.primary),
                    const SizedBox(width: 6),
                    Text('Trésorerie actuelle', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 20),
          const Text('\$ 18,500.00', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  title: 'Burn Rate',
                  value: '\$ 1,200/mo',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              const Expanded(
                child: _MetricItem(
                  icon: Icons.flight_takeoff_rounded,
                  iconColor: Colors.green,
                  title: 'Runway',
                  value: '15 Mois',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LuminousGlassCard(
            padding: const EdgeInsets.all(16),
            shadowColor: Colors.purple.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.pie_chart_rounded, color: Colors.purple.shade400, size: 24),
                const SizedBox(height: 12),
                Text('Budget CAPEX', style: ThixPolicy.captionStyle),
                const SizedBox(height: 4),
                const Text('45% utilisé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: 0.45, backgroundColor: Colors.purple.shade50, color: Colors.purple.shade400, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _LuminousGlassCard(
            padding: const EdgeInsets.all(16),
            shadowColor: Colors.blue.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.trending_up_rounded, color: Colors.blue.shade400, size: 24),
                const SizedBox(height: 12),
                Text('Revenus (MRR)', style: ThixPolicy.captionStyle),
                const SizedBox(height: 4),
                const Text('\$ 0.00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: 0.05, backgroundColor: Colors.blue.shade50, color: Colors.blue.shade400, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KanbanPreviewList extends StatelessWidget {
  const _KanbanPreviewList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TaskCard(
          title: 'Obtenir l\'agrément OCC',
          category: 'Légal',
          color: Colors.red.shade400,
          isAiGenerated: true,
        ),
        const SizedBox(height: 12),
        _TaskCard(
          title: 'Commander les emballages (5000 pcs)',
          category: 'Logistique',
          color: Colors.orange.shade400,
          isAiGenerated: true,
        ),
        const SizedBox(height: 12),
        _TaskCard(
          title: 'Campagne Facebook Kinshasa',
          category: 'Marketing',
          color: ThixPolicy.primary,
          isAiGenerated: false,
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.category,
    required this.color,
    required this.isAiGenerated,
  });

  final String title;
  final String category;
  final Color color;
  final bool isAiGenerated;

  @override
  Widget build(BuildContext context) {
    return _LuminousGlassCard(
      padding: const EdgeInsets.all(16),
      shadowColor: Colors.black.withOpacity(0.04), // Ombre plus douce pour les listes
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(category, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (isAiGenerated) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.auto_awesome, size: 12, color: ThixPolicy.primary),
                      const SizedBox(width: 4),
                      Text('Suggéré par l\'IA', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary)),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS DE BASE (THE CORE)
// ============================================================================

/// Carte maîtresse du design : Luminous Glassmorphism
class _LuminousGlassCard extends StatelessWidget {
  const _LuminousGlassCard({
    required this.child,
    required this.shadowColor,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Ombre principale excessive et colorée (Glow effect)
          BoxShadow(
            color: shadowColor,
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          // Ombre secondaire douce pour le contraste
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Effet verre
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92), // Blanc presque pur
              border: Border.all(color: Colors.white, width: 1.5), // Bordure brillante
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ThixPolicy.captionStyle),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(subtitle, style: ThixPolicy.captionStyle),
      ],
    );
  }
}
