// lib/presentation/thix_reservation/delivery/pages/admin/delivery_admin_dashboard_page.dart
// FIX ONTAP - GO_ROUTER + APP_ROUTES
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/nav.dart';
import '../../providers/delivery_admin_provider.dart';
import '../../widgets/delivery_admin_widgets.dart';

class DeliveryAdminDashboardPage extends StatefulWidget {
  const DeliveryAdminDashboardPage({super.key});

  @override
  State<DeliveryAdminDashboardPage> createState() =>
      _DeliveryAdminDashboardPageState();
}

class _DeliveryAdminDashboardPageState
    extends State<DeliveryAdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryAdminProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text(
          "Admin Delivery",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<DeliveryAdminProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6D28D9),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => prov.init(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATS 2x2 ---
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.7,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    children: [
                      AdminStatCard(
                        title: "Total colis",
                        value: "${prov.stats['total'] ?? 0}",
                        icon: Icons.inventory_2,
                        color: const Color(0xFF6D28D9),
                      ),
                      AdminStatCard(
                        title: "En attente",
                        value: "${prov.stats['pending'] ?? 0}",
                        icon: Icons.pending,
                        color: Colors.orange,
                      ),
                      AdminStatCard(
                        title: "Livrés",
                        value: "${prov.stats['delivered'] ?? 0}",
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      AdminStatCard(
                        title: "Aujourd'hui",
                        value: "${prov.stats['today'] ?? 0}",
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- MENU ADMIN ---
                  const Text(
                    "Gestion",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AdminMenuBtn(
                        icon: Icons.route_rounded,
                        label: "Prix par trajet",
                        onTap: () =>
                            context.push(AppRoutes.deliveryAdminRoutes),
                      ),
                      const SizedBox(width: 10),
                      _AdminMenuBtn(
                        icon: Icons.local_shipping_rounded,
                        label: "Tous colis",
                        onTap: () =>
                            context.push(AppRoutes.deliveryAdminShipments),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _AdminMenuBtn(
                        icon: Icons.qr_code_scanner_rounded,
                        label: "Scanner QR",
                        onTap: () =>
                            context.push(AppRoutes.deliveryAdminScan),
                      ),
                      const SizedBox(width: 10),
                      _AdminMenuBtn(
                        icon: Icons.local_offer_rounded,
                        label: "Offres",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Offres à venir"),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- ROUTES RECENTES ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Trajets actifs",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(AppRoutes.deliveryAdminRoutes),
                        child: const Text(
                          "Voir tout",
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  if (prov.routes.isEmpty)
                    const Text(
                      "Aucun trajet - Créez en un",
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8B8BA3),
                      ),
                    )
                  else
                    ...prov.routes.take(3).map(
                      (r) => AdminRouteCard(
                        route: r,
                        onEdit: () => context.push(
                          AppRoutes.deliveryAdminRoutes,
                        ),
                        onDelete: () => prov.deleteRoute(r.id),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminMenuBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdminMenuBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF6D28D9), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
