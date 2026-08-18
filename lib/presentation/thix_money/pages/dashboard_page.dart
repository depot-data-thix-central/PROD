// lib/presentation/thix_money/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/nav.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _Service {
  final String label;
  final Color color;
  final IconData icon;
  final String? route;
  const _Service({required this.label, required this.color, required this.icon, this.route});
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final PageController _cardController = PageController(viewportFraction: 0.9);
  int _cardPage = 0;
  bool _balanceVisible = true;

  // ─── SERVICES ───
  static const List<_Service> _services = [
    _Service(label: 'Crédit', color: ThixPolicy.primaryDeep, icon: Icons.bolt_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Assurance', color: ThixPolicy.domainHealth, icon: Icons.security_outlined, route: null),
    _Service(label: 'Épargne', color: ThixPolicy.domainOpportunity, icon: Icons.savings_outlined, route: AppRoutes.thixMoneySavings),
    _Service(label: 'Change', color: ThixPolicy.domainNetwork, icon: Icons.currency_exchange_outlined, route: null),
    _Service(label: 'Marchand', color: ThixPolicy.domainMarket, icon: Icons.storefront_outlined, route: AppRoutes.thixMarket),
    _Service(label: 'Dons', color: ThixPolicy.domainEvents, icon: Icons.favorite_border_rounded, route: null),
    _Service(label: 'Tontine', color: ThixPolicy.domainLearning, icon: Icons.groups_outlined, route: AppRoutes.thixMoneyTontines),
    _Service(label: 'Éducation', color: ThixPolicy.domainInfo, icon: Icons.school_outlined, route: AppRoutes.education),
    _Service(label: 'Virement', color: ThixPolicy.domainMedia, icon: Icons.language_outlined, route: AppRoutes.thixMoneySend),
    _Service(label: 'Microfinance', color: ThixPolicy.domainJobs, icon: Icons.account_balance_outlined, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Investir', color: ThixPolicy.premiumAccent, icon: Icons.show_chart_rounded, route: AppRoutes.thixMoneyInvestments),
    _Service(label: 'Planifier', color: ThixPolicy.textMain, icon: Icons.calendar_month_outlined, route: AppRoutes.thixMoneySavings),
  ];

  Future<Map<String, dynamic>> _getRealDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'name': 'Utilisateur', 'balance_fc': 0.0, 'balance_usd': 0.0, 'thix_id': '', 'avatar_url': null};

    final profileRes = await Supabase.instance.client.from('profiles').select('first_name, full_name, avatar_url').eq('id', user.id).maybeSingle();
    final name = profileRes?['first_name'] ?? profileRes?['full_name'] ?? 'Utilisateur';
    final avatarUrl = profileRes?['avatar_url'] as String?;

    final walletRes = await Supabase.instance.client.from('wallets').select('balance, balance_usd, thix_id').eq('user_id', user.id).maybeSingle();
    final balanceFc = (walletRes?['balance'] ?? 0.0).toDouble();
    final balanceUsd = (walletRes?['balance_usd'] ?? 0.0).toDouble();
    final thixId = walletRes?['thix_id'] ?? '';

    return { 'name': name, 'balance_fc': balanceFc, 'balance_usd': balanceUsd, 'thix_id': thixId, 'avatar_url': avatarUrl };
  }

  String _formatAmount(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i != 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatThixId(String thixId) {
    if (thixId.isEmpty) return '•••• •••• •••• ••••';
    final clean = thixId.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getRealDashboardData(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {'name': '...', 'balance_fc': 0.0, 'balance_usd': 0.0, 'thix_id': '', 'avatar_url': null};
          final thixId = data['thix_id'] as String;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── En-tête Premium ───
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + ThixPolicy.s16, bottom: ThixPolicy.s24, left: ThixPolicy.s20, right: ThixPolicy.s20),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rXl)),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(data['name'], data['avatar_url']),
                      const SizedBox(height: ThixPolicy.s24),
                      _buildSearchBar(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s24)),

              // ─── Cartes Bancaires (THIX ID) ───
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Comptes & Cartes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
                          GestureDetector(
                            onTap: () => context.push('/thix-money/cards/add'),
                            child: const Text('+ Ajouter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 250, // Ajusté pour englober la carte et la pillule flottante
                      child: PageView(
                        controller: _cardController,
                        onPageChanged: (i) => setState(() => _cardPage = i),
                        children: [
                          _buildPremiumBalanceCard(
                            thixId: thixId,
                            balanceFc: data['balance_fc'] as double,
                            balanceUsd: data['balance_usd'] as double,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s8),
                    _buildDotsIndicator(1),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s32)),

              // ─── Grille de Services THIX ───
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                  child: Text('Services THIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: ThixPolicy.s16,
                    crossAxisSpacing: ThixPolicy.s12,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final s = _services[index];
                      final enabled = s.route != null;
                      return GestureDetector(
                        onTap: enabled
                            ? () { HapticFeedback.lightImpact(); context.push(s.route!); }
                            : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.label} — bientôt disponible'), backgroundColor: ThixPolicy.textSecondary)),
                        child: Opacity(
                          opacity: enabled ? 1.0 : 0.4,
                          child: Column(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: ThixPolicy.card,
                                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                                  border: Border.all(color: ThixPolicy.border),
                                  boxShadow: ThixPolicy.shadowSoft(),
                                ),
                                child: Icon(s.icon, color: s.color, size: 24),
                              ),
                              const SizedBox(height: ThixPolicy.s8),
                              Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _services.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace Bottom Nav
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // BARRE DU HAUT
  // ==========================================
  Widget _buildTopBar(String name, String? avatarUrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bonjour,', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
          ],
        ),
        GestureDetector(
          onTap: () => context.push('/account'),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.primary, width: 2)),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: ThixPolicy.tint,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, color: ThixPolicy.primaryDeep) : null,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RECHERCHE (Façon néo-banque)
  // ==========================================
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.push('/thix-money/search'),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 22),
            const SizedBox(width: ThixPolicy.s12),
            const Expanded(child: Text('Rechercher un service, un paiement...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w500))),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(6), border: Border.all(color: ThixPolicy.border)),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: ThixPolicy.primary),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CARTE DE SOLDE PREMIUM & FLOATING PILL
  // ==========================================
  Widget _buildPremiumBalanceCard({required String thixId, required double balanceFc, required double balanceUsd}) {
    final actions = [
      {'label': 'Recharger', 'icon': Icons.add_card_rounded, 'route': '/thix-money/topup'},
      {'label': 'Envoyer', 'icon': Icons.send_rounded, 'route': AppRoutes.thixMoneySend},
      {'label': 'Recevoir', 'icon': Icons.call_received_rounded, 'route': '/thix-money/request'},
      {'label': 'Historique', 'icon': Icons.history_rounded, 'route': '/thix-money/history'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // La Carte (THIX ID)
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(ThixPolicy.s24),
            decoration: BoxDecoration(
              gradient: ThixPolicy.brandGradient,
              borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
              boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('THIX ID', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    Row(
                      children: [
                        Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle)),
                        Transform.translate(offset: const Offset(-10, 0), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), shape: BoxShape.circle))),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_balanceVisible ? _formatAmount(balanceFc) : '••••••', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
                    const SizedBox(width: 4),
                    const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('FC', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700))),
                    const SizedBox(width: ThixPolicy.s12),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                    const SizedBox(width: ThixPolicy.s12),
                    Padding(padding: EdgeInsets.only(bottom: _balanceVisible ? 4 : 0), child: Text(_balanceVisible ? '\$ ${balanceUsd.toStringAsFixed(2)}' : '•••• \$', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w700))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () { HapticFeedback.lightImpact(); setState(() => _balanceVisible = !_balanceVisible); },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(_balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ThixPolicy.s12),
                Text(_formatThixId(thixId), style: const TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Courier', fontWeight: FontWeight.w600, letterSpacing: 3.0)),
                const SizedBox(height: ThixPolicy.s16), // Espace pour la pillule
              ],
            ),
          ),

          // La Pillule d'Actions Flottante
          Positioned(
            bottom: -22,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions.map((a) {
                  final isPrimary = a['label'] == 'Envoyer' || a['label'] == 'Recharger';
                  return GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); context.push(a['route'] as String); },
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isPrimary ? ThixPolicy.tint : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a['icon'] as IconData, color: isPrimary ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary, size: 22),
                          const SizedBox(height: 4),
                          Text(a['label'] as String, style: TextStyle(color: isPrimary ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(int count) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _cardPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(color: active ? ThixPolicy.primary : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(3)),
        );
      }),
    );
  }
}
