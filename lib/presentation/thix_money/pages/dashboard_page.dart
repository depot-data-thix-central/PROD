// lib/presentation/thix_money/pages/dashboard_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/nav.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE NÉO-BANQUE PREMIUM (Violet)
// ═══════════════════════════════════════════════════════════════════════════
class _MoneyColors {
  _MoneyColors._();
  static const Color violetDeep = Color(0xFF2E1065); // Fond sombre de la carte
  static const Color violetMain = Color(0xFF7C3AED); // Violet éclatant
  static const Color violetLight = Color(0xFFC4B5FD); // Accent clair
  static const Color violetSoft = Color(0xFFEDE9FE); // Fond de bouton
  static const Color bgApp = Color(0xFFF4F7FB); // Fond de l'application
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _Service {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String? route;
  const _Service({required this.label, required this.color, required this.bgColor, required this.icon, this.route});
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final PageController _cardController = PageController(viewportFraction: 0.92);
  int _cardPage = 0;
  bool _balanceVisible = true;

  // ─── SERVICES (Harmonisés avec le thème Violet & Néo-banque) ───
  static const List<_Service> _services = [
    _Service(label: 'Crédit', color: _MoneyColors.violetMain, bgColor: _MoneyColors.violetSoft, icon: Icons.bolt_rounded, route: AppRoutes.thixMoneyLoans),
    _Service(label: 'Épargne', color: Color(0xFF059669), bgColor: Color(0xFFD1FAE5), icon: Icons.savings_rounded, route: AppRoutes.thixMoneySavings),
    _Service(label: 'Tontine', color: Color(0xFFD97706), bgColor: Color(0xFFFEF3C7), icon: Icons.groups_rounded, route: AppRoutes.thixMoneyTontines),
    _Service(label: 'Virement', color: Color(0xFF2563EB), bgColor: Color(0xFFDBEAFE), icon: Icons.language_rounded, route: AppRoutes.thixMoneySend),
    _Service(label: 'Marchand', color: Color(0xFF4F46E5), bgColor: Color(0xFFE0E7FF), icon: Icons.storefront_rounded, route: AppRoutes.thixMarket),
    _Service(label: 'Assurance', color: Color(0xFF0891B2), bgColor: Color(0xFFCFFAFE), icon: Icons.security_rounded, route: null),
    _Service(label: 'Change', color: Color(0xFF0D9488), bgColor: Color(0xFFCCFBF1), icon: Icons.currency_exchange_rounded, route: null),
    _Service(label: 'Dons', color: Color(0xFFE11D48), bgColor: Color(0xFFFFE4E6), icon: Icons.favorite_rounded, route: null),
    _Service(label: 'Éducation', color: Color(0xFF7C3AED), bgColor: Color(0xFFEDE9FE), icon: Icons.school_rounded, route: AppRoutes.education),
    _Service(label: 'Investir', color: Color(0xFF0F766E), bgColor: Color(0xFFCCFBF1), icon: Icons.show_chart_rounded, route: AppRoutes.thixMoneyInvestments),
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
      backgroundColor: _MoneyColors.bgApp,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getRealDashboardData(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {'name': '...', 'balance_fc': 0.0, 'balance_usd': 0.0, 'thix_id': '', 'avatar_url': null};
          final thixId = data['thix_id'] as String;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── En-tête (Transparent et épuré) ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 16, left: 24, right: 24, bottom: 16),
                  child: _buildTopBar(data['name'], data['avatar_url']),
                ),
              ),

              // ─── Cartes Bancaires (THIX ID) ───
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 260, // Espace pour la carte + la pillule flottante + l'ombre
                      child: PageView(
                        controller: _cardController,
                        onPageChanged: (i) => setState(() => _cardPage = i),
                        children: [
                          _buildPremiumBalanceCard(
                            thixId: thixId,
                            balanceFc: data['balance_fc'] as double,
                            balanceUsd: data['balance_usd'] as double,
                          ),
                          // Tu pourras ajouter d'autres cartes ici (ex: USD locale)
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDotsIndicator(1),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ─── Recherche et Scan ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSearchBar(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ─── Grille de Services THIX ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Services THIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border)),
                          child: const Text('Gérer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
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
                          opacity: enabled ? 1.0 : 0.5,
                          child: Column(
                            children: [
                              Container(
                                width: 54, height: 54,
                                decoration: BoxDecoration(
                                  color: s.bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: s.color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Icon(s.icon, color: s.color, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, letterSpacing: -0.2)),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _services.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace pour la Bottom Nav
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
            Row(
              children: [
                const Text('THIX ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
                Text('MONEY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _MoneyColors.violetMain, letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Bonjour, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.5)),
          ],
        ),
        GestureDetector(
          onTap: () => context.push('/account'),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: _MoneyColors.violetSoft,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person_rounded, color: _MoneyColors.violetMain) : null,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RECHERCHE (Néo-banque)
  // ==========================================
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => context.push('/thix-money/search'),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 22),
            const SizedBox(width: 12),
            const Expanded(child: Text('Effectuer un paiement...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _MoneyColors.violetSoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: _MoneyColors.violetMain),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CARTE DE SOLDE PREMIUM & PILLULE D'ACTIONS
  // ==========================================
  Widget _buildPremiumBalanceCard({required String thixId, required double balanceFc, required double balanceUsd}) {
    final actions = [
      {'label': 'Recharger', 'icon': Icons.add_rounded, 'route': '/thix-money/topup'},
      {'label': 'Envoyer', 'icon': Icons.arrow_upward_rounded, 'route': AppRoutes.thixMoneySend},
      {'label': 'Recevoir', 'icon': Icons.arrow_downward_rounded, 'route': '/thix-money/request'},
      {'label': 'Historique', 'icon': Icons.history_rounded, 'route': '/thix-money/history'},
    ];

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 🌟 LA CARTE BANCAIRE VIRTUELLE
        Container(
          width: double.infinity,
          height: 220,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_MoneyColors.violetMain, _MoneyColors.violetDeep],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: _MoneyColors.violetMain.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: Stack(
            children: [
              // Motif de fond (Cercles abstraits pour le design)
              Positioned(right: -50, top: -50, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
              Positioned(left: -30, bottom: -30, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Puce électronique + Sans contact
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32, height: 24,
                            decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.8), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withOpacity(0.2))),
                            child: Center(child: Container(width: 20, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.1)), borderRadius: BorderRadius.circular(2)))),
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.contactless_outlined, color: Colors.white70, size: 20),
                        ],
                      ),
                      // Logo THIX
                      const Text('THIX ID', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_balanceVisible ? _formatAmount(balanceFc) : '••••••', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0)),
                      const SizedBox(width: 6),
                      const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('FC', style: TextStyle(color: _MoneyColors.violetLight, fontSize: 18, fontWeight: FontWeight.w800))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); setState(() => _balanceVisible = !_balanceVisible); },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(_balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(padding: EdgeInsets.only(bottom: _balanceVisible ? 4 : 0), child: Text(_balanceVisible ? '\$ ${balanceUsd.toStringAsFixed(2)}' : '•••• \$', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 12),
                  Text(_formatThixId(thixId), style: const TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Courier', fontWeight: FontWeight.w600, letterSpacing: 3.5)),
                  const SizedBox(height: 16), // Espace pour laisser déborder la pillule
                ],
              ),
            ],
          ),
        ),

        // 🌟 LA PILLULE D'ACTIONS FLOTTANTE (Design Apple/Revolut)
        Positioned(
          bottom: -24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions.map((a) {
                    final isPrimary = a['label'] == 'Envoyer' || a['label'] == 'Recharger';
                    return GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); context.push(a['route'] as String); },
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isPrimary ? _MoneyColors.violetMain : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a['icon'] as IconData, color: isPrimary ? Colors.white : _MoneyColors.violetDeep, size: 20),
                            const SizedBox(height: 6),
                            Text(a['label'] as String, style: TextStyle(color: isPrimary ? Colors.white : _MoneyColors.violetDeep, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
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
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(color: active ? _MoneyColors.violetMain : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(4)),
        );
      }),
    );
  }
}
