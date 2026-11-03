// lib/presentation/thix_weeding/pages/provider_portal/traiteur/traiteur_menu_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'menu_models.dart';
import 'traiteur_menu_provider.dart';
import 'guest_voting_page.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — PAGE MENU TRAITEUR (Production v2)
/// ✅ Création et édition du menu
/// ✅ Ajout de plats par catégorie
/// ✅ Soumission au staff pour validation
/// ✅ Publication pour votes invités
/// ✅ Statistiques en temps réel
/// ═══════════════════════════════════════════════════════════════════════

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

class TraiteurMenuPage extends ConsumerStatefulWidget {
  final String orderId;
  final String? menuId;

  const TraiteurMenuPage({
    super.key,
    required this.orderId,
    this.menuId,
  });

  @override
  ConsumerState<TraiteurMenuPage> createState() => _TraiteurMenuPageState();
}

class _TraiteurMenuPageState extends ConsumerState<TraiteurMenuPage> {
  final _picker = ImagePicker();
  bool _isProcessing = false;

  final List<String> _categoryOrder = [
    'aperitif',
    'entree',
    'plat',
    'dessert',
    'boisson',
  ];

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider(widget.orderId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          'Menu traiteur',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        actions: [
          menuAsync.when(
            data: (menu) {
              if (menu == null) return const SizedBox.shrink();

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: _P.ink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) => _handleMenuAction(value, menu),
                itemBuilder: (context) => [
                  if (menu.status == MenuStatus.draft)
                    PopupMenuItem(
                      value: 'submit',
                      child: Row(
                        children: [
                          const Icon(Icons.send_rounded, size: 18, color: _P.blue),
                          const SizedBox(width: 8),
                          Text('Soumettre au staff', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                  if (menu.status == MenuStatus.validated)
                    PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          const Icon(Icons.public_rounded, size: 18, color: _P.green),
                          const SizedBox(width: 8),
                          Text('Rendre public', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                  if (menu.status == MenuStatus.public)
                    PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          const Icon(Icons.poll_rounded, size: 18, color: _P.purple),
                          const SizedBox(width: 8),
                          Text('Voir statistiques', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                  if (menu.status == MenuStatus.public)
                    PopupMenuItem(
                      value: 'finalize',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: _P.green),
                          const SizedBox(width: 8),
                          Text('Finaliser le menu', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: menuAsync.when(
        data: (menu) {
          if (menu == null) {
            return _EmptyMenuState(
              orderId: widget.orderId,
              onCreateMenu: _createMenu,
            );
          }

          return _buildMenuContent(menu);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _P.rose)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: _P.red),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuContent(WeddingMenu menu) {
    return Column(
      children: [
        // En-tête statut
        _MenuStatusHeader(menu: menu),

        // Contenu
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Informations menu
              _MenuInfoCard(menu: menu),
              const SizedBox(height: 16),

              // Plats par catégorie
              ..._categoryOrder.map((categoryKey) {
                final category = MenuItemCategory.values.firstWhere((c) => c.name == categoryKey);
                final items = menu.getItemsByCategory(category);

                return _CategorySection(
                  category: category,
                  items: items,
                  canEdit: menu.status == MenuStatus.draft,
                  onAddItem: () => _showAddItemDialog(category, menu),
                  onEditItem: (item) => _showEditItemDialog(item, menu),
                  onDeleteItem: (item) => _deleteItem(item, menu),
                );
              }),
              const SizedBox(height: 16),

              // Actions
              _MenuActions(
                menu: menu,
                onSubmit: () => _submitForValidation(menu),
                onPublish: () => _publishMenu(menu),
                onFinalize: () => _finalizeMenu(menu),
                onViewStats: () => _viewStatistics(menu),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createMenu() async {
    final titleCtrl = TextEditingController();
    final guestsCtrl = TextEditingController(text: '100');
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Créer un menu',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Nom du menu',
                hintText: 'Ex: Menu mariage traditionnel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: guestsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre d\'invités',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prix par personne (USD)',
                hintText: 'Optionnel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;

              Navigator.pop(context);

              try {
                await ref.read(menuProvider(widget.orderId).notifier).createMenu(
                      orderId: widget.orderId,
                      providerId: 'provider_id', // TODO: Récupérer depuis le contexte
                      title: titleCtrl.text,
                      maxGuests: int.tryParse(guestsCtrl.text) ?? 100,
                      pricePerPerson: double.tryParse(priceCtrl.text),
                    );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Menu créé ✓',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: _P.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: _P.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Créer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(MenuItemCategory category, WeddingMenu menu) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final prepTimeCtrl = TextEditingController(text: '30');

    final Set<DietaryRestriction> selectedDietary = {};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ajouter ${category.displayName.toLowerCase()}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom du plat *',
                    hintText: 'Ex: Poulet braisé',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Décrivez le plat...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Prix/personne',
                          hintText: 'Optionnel',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: prepTimeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Préparation (min)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Options diététiques',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DietaryRestriction.values.map((restriction) {
                    final selected = selectedDietary.contains(restriction);
                    return FilterChip(
                      label: Text(
                        restriction.displayName,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            selectedDietary.add(restriction);
                          } else {
                            selectedDietary.remove(restriction);
                          }
                        });
                      },
                      selectedColor: _P.green.withOpacity(0.3),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;

                Navigator.pop(context);

                final newItem = MenuItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  category: category,
                  dietaryOptions: selectedDietary.toList(),
                  pricePerPerson: double.tryParse(priceCtrl.text),
                  preparationTime: int.tryParse(prepTimeCtrl.text) ?? 30,
                );

                try {
                  await ref.read(menuProvider(widget.orderId).notifier).addMenuItem(
                        menuId: menu.id,
                        item: newItem,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${category.displayName} ajouté ✓',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: _P.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: _P.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Ajouter',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(MenuItem item, WeddingMenu menu) async {
    final nameCtrl = TextEditingController(text: item.name);
    final descCtrl = TextEditingController(text: item.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Modifier le plat',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nom du plat',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final updatedItem = item.copyWith(
                name: nameCtrl.text,
                description: descCtrl.text,
              );

              try {
                await ref.read(menuProvider(widget.orderId).notifier).updateMenuItem(
                      menuId: menu.id,
                      itemId: item.id,
                      updatedItem: updatedItem,
                    );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: _P.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Enregistrer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(MenuItem item, WeddingMenu menu) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Supprimer ce plat ?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            content: Text(
              '"${item.name}" sera définitivement supprimé du menu.',
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(color: _P.inkSoft),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Supprimer',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        await ref.read(menuProvider(widget.orderId).notifier).removeMenuItem(
              menuId: menu.id,
              itemId: item.id,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: _P.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitForValidation(WeddingMenu menu) async {
    setState(() => _isProcessing = true);

    try {
      await ref.read(menuProvider(widget.orderId).notifier).submitForValidation(
            menuId: menu.id,
            providerId: menu.providerId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Menu soumis au staff pour validation ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _publishMenu(WeddingMenu menu) async {
    setState(() => _isProcessing = true);

    try {
      await ref.read(menuProvider(widget.orderId).notifier).publishMenu(
            menuId: menu.id,
            orderId: widget.orderId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Menu rendu public - Les invités peuvent voter ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _finalizeMenu(WeddingMenu menu) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Finaliser le menu ?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Le menu sera figé et les votes des invités seront utilisés pour la préparation finale.',
              style: GoogleFonts.inter(color: _P.inkSoft),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.inter(color: _P.inkSoft),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Finaliser',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      setState(() => _isProcessing = true);

      try {
        await ref.read(menuProvider(widget.orderId).notifier).finalizeMenu(
              menuId: menu.id,
              orderId: widget.orderId,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Menu finalisé ✓',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: _P.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: _P.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _viewStatistics(WeddingMenu menu) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestVotingPage(menuId: menu.id),
      ),
    );
  }

  void _handleMenuAction(String action, WeddingMenu menu) {
    switch (action) {
      case 'submit':
        _submitForValidation(menu);
        break;
      case 'publish':
        _publishMenu(menu);
        break;
      case 'stats':
        _viewStatistics(menu);
        break;
      case 'finalize':
        _finalizeMenu(menu);
        break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _EmptyMenuState extends StatelessWidget {
  final String orderId;
  final VoidCallback onCreateMenu;

  const _EmptyMenuState({
    required this.orderId,
    required this.onCreateMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _P.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu, size: 56, color: _P.amber),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun menu créé',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _P.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez un menu pour cette commande traiteur. Vous pourrez ensuite le soumettre au staff pour validation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _P.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateMenu,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer un menu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuStatusHeader extends StatelessWidget {
  final WeddingMenu menu;

  const _MenuStatusHeader({required this.menu});

  Color get _statusColor {
    switch (menu.status) {
      case MenuStatus.draft:
        return _P.inkSoft;
      case MenuStatus.submitted:
        return _P.amber;
      case MenuStatus.validated:
        return _P.blue;
      case MenuStatus.public:
        return _P.green;
      case MenuStatus.finalized:
        return _P.purple;
    }
  }

  IconData get _statusIcon {
    switch (menu.status) {
      case MenuStatus.draft:
        return Icons.edit_rounded;
      case MenuStatus.submitted:
        return Icons.hourglass_empty_rounded;
      case MenuStatus.validated:
        return Icons.check_circle_rounded;
      case MenuStatus.public:
        return Icons.public_rounded;
      case MenuStatus.finalized:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_statusColor.withOpacity(0.9), _statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.statusDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  menu.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${menu.items.length} plats',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuInfoCard extends StatelessWidget {
  final WeddingMenu menu;

  const _MenuInfoCard({required this.menu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_rounded, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Informations',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Invités prévus',
            value: '${menu.maxGuests}',
            icon: Icons.people_rounded,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Prix par personne',
            value: menu.pricePerPerson != null ? '${menu.pricePerPerson!.toStringAsFixed(0)}\$' : 'N/A',
            icon: Icons.attach_money_rounded,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Total estimé',
            value: '${menu.estimatedTotalPrice.toStringAsFixed(0)}\$',
            icon: Icons.calculate_rounded,
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final MenuItemCategory category;
  final List<MenuItem> items;
  final bool canEdit;
  final VoidCallback onAddItem;
  final Function(MenuItem) onEditItem;
  final Function(MenuItem) onDeleteItem;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.canEdit,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = category.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header catégorie
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(category.icon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _P.ink,
                        ),
                      ),
                      Text(
                        '${items.length} plat(s)',
                        style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  IconButton(
                    onPressed: onAddItem,
                    icon: Icon(Icons.add_circle_rounded, color: categoryColor),
                    tooltip: 'Ajouter',
                  ),
              ],
            ),
          ),

          // Liste des plats
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aucun plat dans cette catégorie',
                  style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: items.map((item) {
                  return _MenuItemTile(
                    item: item,
                    categoryColor: categoryColor,
                    canEdit: canEdit,
                    onEdit: () => onEditItem(item),
                    onDelete: () => onDeleteItem(item),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final Color categoryColor;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemTile({
    required this.item,
    required this.categoryColor,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.restaurant_rounded, color: categoryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _P.ink,
                  ),
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.dietaryOptions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: item.dietaryOptions.map((option) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _P.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          option.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _P.green,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (item.pricePerPerson != null)
            Text(
              '${item.pricePerPerson!.toStringAsFixed(0)}\$',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _P.green,
              ),
            ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16, color: _P.inkSoft),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _P.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuActions extends StatelessWidget {
  final WeddingMenu menu;
  final VoidCallback onSubmit;
  final VoidCallback onPublish;
  final VoidCallback onFinalize;
  final VoidCallback onViewStats;

  const _MenuActions({
    required this.menu,
    required this.onSubmit,
    required this.onPublish,
    required this.onFinalize,
    required this.onViewStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Actions',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (menu.status == MenuStatus.draft) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Soumettre au staff pour validation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le menu doit être validé par le staff avant d\'être rendu public.',
              style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],

          if (menu.status == MenuStatus.validated) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.public_rounded, size: 20),
                label: const Text('Rendre public pour les votes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les invités pourront voter pour leurs plats préférés.',
              style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],

          if (menu.status == MenuStatus.public) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onViewStats,
                icon: const Icon(Icons.poll_rounded, size: 20),
                label: const Text('Voir les statistiques des votes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onFinalize,
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Finaliser le menu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _P.green,
                  side: const BorderSide(color: _P.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],

          if (menu.status == MenuStatus.submitted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _P.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty_rounded, color: _P.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'En attente de validation par le staff...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _P.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (menu.status == MenuStatus.finalized) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _P.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: _P.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Menu finalisé - Prêt pour la préparation',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _P.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _P.inkSoft),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _P.ink,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// EXTENSIONS
// ═══════════════════════════════════════════════════════════════════════

extension MenuItemCategoryExtension on MenuItemCategory {
  String get displayName {
    switch (this) {
      case MenuItemCategory.aperitif:
        return 'Apéritif';
      case MenuItemCategory.entree:
        return 'Entrée';
      case MenuItemCategory.plat:
        return 'Plat principal';
      case MenuItemCategory.dessert:
        return 'Dessert';
      case MenuItemCategory.boisson:
        return 'Boisson';
    }
  }

  Color get color {
    switch (this) {
      case MenuItemCategory.aperitif:
        return const Color(0xFF8B5CF6);
      case MenuItemCategory.entree:
        return const Color(0xFF10B981);
      case MenuItemCategory.plat:
        return const Color(0xFFF59E0B);
      case MenuItemCategory.dessert:
        return const Color(0xFFEC4899);
      case MenuItemCategory.boisson:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get icon {
    switch (this) {
      case MenuItemCategory.aperitif:
        return Icons.local_bar_rounded;
      case MenuItemCategory.entree:
        return Icons.restaurant_rounded;
      case MenuItemCategory.plat:
        return Icons.dinner_dining_rounded;
      case MenuItemCategory.dessert:
        return Icons.icecream_rounded;
      case MenuItemCategory.boisson:
        return Icons.local_drink_rounded;
    }
  }
}

extension DietaryRestrictionExtension on DietaryRestriction {
  String get displayName {
    switch (this) {
      case DietaryRestriction.vegetarian:
        return 'Végétarien';
      case DietaryRestriction.vegan:
        return 'Vegan';
      case DietaryRestriction.halal:
        return 'Halal';
      case DietaryRestriction.kosher:
        return 'Casher';
      case DietaryRestriction.glutenFree:
        return 'Sans gluten';
      case DietaryRestriction.lactoseFree:
        return 'Sans lactose';
      case DietaryRestriction.nutFree:
        return 'Sans noix';
    }
  }
}
