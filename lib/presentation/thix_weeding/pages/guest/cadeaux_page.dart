// lib/presentation/thix_weeding/pages/guest/cadeaux_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';
import 'group_gifts_repository.dart';

part 'cadeaux_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC);
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C4E);
  static const primarySoft = Color(0xFFFFE3EA);
  static const accent = Color(0xFFD4AF37);
  static const accentSoft = Color(0xFFFDF6E3);
  static const ink = Color(0xFF241521);
  static const inkSoft = Color(0xFF8A7580);

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE31C4E), Color(0xFFFF6B8B)],
  );

  static final shadow = [
    BoxShadow(
      color: const Color(0xFFE31C4E).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    )
  ];
}

// ============================================================
// MODELE ETENDU POUR CADEAUX DE GROUPE
// ============================================================
class GroupGift {
  final String id;
  final String name;
  final String imageUrl;
  final double targetAmount;
  final double currentAmount;
  final List<String> participants; // Liste des thix_id
  final String? chatId;
  final String organizerName;

  GroupGift({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.targetAmount,
    required this.currentAmount,
    required this.participants,
    this.chatId,
    required this.organizerName,
  });

  double get percent => targetAmount > 0 ? (currentAmount / targetAmount) : 0;
  bool get isComplete => percent >= 1.0;
  bool isParticipant(String myThixId) => participants.contains(myThixId);

  factory GroupGift.fromJson(Map<String, dynamic> j) => GroupGift(
        id: j['id'] as String,
        name: j['name'] as String,
        imageUrl: j['image_url'] as String? ?? '',
        targetAmount: (j['target_amount'] as num).toDouble(),
        currentAmount: (j['current_amount'] as num? ?? 0).toDouble(),
        participants: List<String>.from(j['participants'] ?? []),
        chatId: j['chat_id'] as String?,
        organizerName: j['organizer_name'] as String? ?? 'Organisateur',
      );
}

// ============================================================
// PROVIDERS
// ============================================================
@riverpod
Future<List<GiftItem>> weddingGifts(WeddingGiftsRef ref, String weddingId) async {
  final repo = ref.read(weddingRepositoryProvider);
  return repo.getGifts(weddingId);
}

@riverpod
Future<List<GroupGift>> groupGifts(GroupGiftsRef ref, String weddingId) async {
  final repo = ref.read(groupGiftsRepositoryProvider);
  return repo.getGroupGifts(weddingId);
}

@riverpod
class ProposeGiftController extends _$ProposeGiftController {
  @override
  FutureOr<void> build() => null;

  Future<void> submit(String weddingId, String name, String description, double budget, String thixId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(groupGiftsRepositoryProvider);
      await repo.proposeSpecialGift(
        weddingId: weddingId,
        name: name,
        description: description,
        budget: budget,
        proposerThixId: thixId,
      );
    });
  }
}

// ============================================================
// PAGE CADEAUX
// ============================================================
class CadeauxPage extends ConsumerStatefulWidget {
  final String weddingId;
  const CadeauxPage({super.key, required this.weddingId});

  @override
  ConsumerState<CadeauxPage> createState() => _CadeauxPageState();
}

class _CadeauxPageState extends ConsumerState<CadeauxPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _myThixId = 'THIX_GUEST_001'; // TODO: Récupérer depuis auth provider

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final giftsAsync = ref.watch(weddingGiftsProvider(widget.weddingId));
    final groupsAsync = ref.watch(groupGiftsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.surface,
        foregroundColor: _P.ink,
        title: const Text('Cadeaux & Contributions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _P.accentSoft, shape: BoxShape.circle),
              child: const Icon(Icons.lightbulb_outline_rounded, color: _P.accent, size: 20),
            ),
            onPressed: () => _showProposeGiftSheet(context),
            tooltip: 'Suggérer un cadeau spécial',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: _P.surface,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: _P.primary,
              indicatorWeight: 3,
              labelColor: _P.primary,
              unselectedLabelColor: _P.inkSoft,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text('Cadeaux de groupe'),
                      groupsAsync.whenOrNull(
                            data: (groups) => groups.isNotEmpty
                                ? Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: _P.accent, borderRadius: BorderRadius.circular(8)),
                                    child: Text('${groups.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                                  )
                                : const SizedBox(),
                          ) ??
                          const SizedBox(),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Liste de mariage'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ONGLET 1: CADEAUX DE GROUPE
                groupsAsync.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return _EmptyGroupGiftsView(
                        onCreate: () => _showCreateGroupGiftSheet(context),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Bouton créer
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showCreateGroupGiftSheet(context),
                            icon: const Icon(Icons.add_rounded, color: _P.primary),
                            label: const Text('Initier un nouveau cadeau de groupe', style: TextStyle(color: _P.primary, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _P.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionTitle(title: 'En cours de financement'),
                        const SizedBox(height: 12),
                        ...groups.map((g) => _GroupGiftCard(
                              group: g,
                              myThixId: _myThixId!,
                              weddingId: widget.weddingId,
                            )),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: _P.primary)),
                  error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: _P.inkSoft))),
                ),
                // ONGLET 2: LISTE DE MARIAGE INDIVIDUELLE
                giftsAsync.when(
                  data: (gifts) {
                    if (gifts.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.card_giftcard_outlined, size: 56, color: _P.inkSoft),
                            SizedBox(height: 12),
                            Text('Aucun cadeau sur la liste', style: TextStyle(color: _P.inkSoft, fontSize: 16)),
                          ],
                        ),
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Offrez un cadeau personnel',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _P.ink),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            delegate: SliverChildBuilderDelegate((context, index) {
                              final gift = gifts[index];
                              return _IndividualGiftCard(
                                gift: gift,
                                onTap: () => _showContributeSheet(context, gift),
                              );
                            }, childCount: gifts.length),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: _P.primary)),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44, color: _P.inkSoft),
                        const SizedBox(height: 12),
                        Text('Erreur: $e', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _P.primary),
                          onPressed: () => ref.invalidate(weddingGiftsProvider(widget.weddingId)),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContributeSheet(BuildContext context, GiftItem gift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContributeSheet(gift: gift),
    );
  }

  void _showProposeGiftSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProposeGiftSheet(
        weddingId: widget.weddingId,
        thixId: _myThixId!,
      ),
    );
  }

  void _showCreateGroupGiftSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGroupGiftSheet(
        weddingId: widget.weddingId,
        organizerThixId: _myThixId!,
      ),
    );
  }
}

// ============================================================
// BOTTOM SHEETS
// ============================================================
class _ContributeSheet extends StatelessWidget {
  final GiftItem gift;
  const _ContributeSheet({required this.gift});

  @override
  Widget build(BuildContext context) {
    final amountCtrl = TextEditingController();
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              gift.imageUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 140,
                color: _P.primarySoft,
                child: const Icon(Icons.card_giftcard_rounded, size: 48, color: _P.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(gift.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _P.ink)),
          const SizedBox(height: 8),
          Text(
            'Objectif : ${gift.price.toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _P.inkSoft),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: gift.percent.clamp(0, 1),
            backgroundColor: _P.primarySoft,
            color: _P.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(gift.percent * 100).toStringAsFixed(0)}% financé • Restant: ${gift.remaining.toStringAsFixed(0)} FCFA',
            style: const TextStyle(fontSize: 12, color: _P.inkSoft),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Montant de votre contribution (FCFA)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
              suffixIcon: IconButton(
                icon: const Icon(Icons.attach_money_rounded, color: _P.primary),
                onPressed: () => amountCtrl.text = gift.remaining.toStringAsFixed(0),
                tooltip: 'Financer le reste',
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                // TODO: Paiement via Thix Money
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Contribution de ${amountCtrl.text} FCFA en cours...')),
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _P.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.wallet_rounded),
              label: const Text('Payer avec Thix Money', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ProposeGiftSheet extends ConsumerStatefulWidget {
  final String weddingId;
  final String thixId;
  const _ProposeGiftSheet({required this.weddingId, required this.thixId});

  @override
  ConsumerState<_ProposeGiftSheet> createState() => _ProposeGiftSheetState();
}

class _ProposeGiftSheetState extends ConsumerState<_ProposeGiftSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proposeGiftControllerProvider);

    ref.listen<AsyncValue<void>>(proposeGiftControllerProvider, (_, next) {
      next.whenOrNull(
        data: (_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Votre suggestion a été envoyée à l\'organisation !'),
              backgroundColor: _P.accent,
            ),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.primary),
          );
        },
      );
    });

    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _P.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: _P.accent, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Proposez une idée de cadeau. Elle sera visible uniquement par l\'organisation.',
                    style: TextStyle(fontSize: 12, color: _P.ink, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Suggérer un cadeau spécial', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _P.ink)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nom du cadeau *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description / Pourquoi ce cadeau ? *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Budget estimé (FCFA)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (_nameCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir le nom et la description')),
                        );
                        return;
                      }
                      ref.read(proposeGiftControllerProvider.notifier).submit(
                            widget.weddingId,
                            _nameCtrl.text,
                            _descCtrl.text,
                            double.tryParse(_budgetCtrl.text) ?? 0,
                            widget.thixId,
                          );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _P.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: state.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(state.isLoading ? 'Envoi...' : 'Envoyer à l\'organisation', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CreateGroupGiftSheet extends ConsumerStatefulWidget {
  final String weddingId;
  final String organizerThixId;
  const _CreateGroupGiftSheet({required this.weddingId, required this.organizerThixId});

  @override
  ConsumerState<_CreateGroupGiftSheet> createState() => _CreateGroupGiftSheetState();
}

class _CreateGroupGiftSheetState extends ConsumerState<_CreateGroupGiftSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _P.inkSoft.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.group_add_rounded, size: 48, color: _P.primary),
          const SizedBox(height: 12),
          const Text('Initier un cadeau de groupe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _P.ink)),
          const SizedBox(height: 8),
          const Text(
            'Les autres invités pourront rejoindre et contribuer. Un chat sera créé automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _P.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nom du cadeau *',
              hintText: 'Ex: Voyage de noces aux Seychelles',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Objectif collectif (FCFA) *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: _P.bg,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      if (_nameCtrl.text.isEmpty || _amountCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir tous les champs')),
                        );
                        return;
                      }
                      setState(() => _loading = true);
                      try {
                        final repo = ref.read(groupGiftsRepositoryProvider);
                        await repo.createGroupGift(
                          weddingId: widget.weddingId,
                          name: _nameCtrl.text,
                          targetAmount: double.tryParse(_amountCtrl.text) ?? 0,
                          organizerThixId: widget.organizerThixId,
                        );
                        ref.invalidate(groupGiftsProvider(widget.weddingId));
                        if (mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _P.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded),
              label: Text(_loading ? 'Création...' : 'Créer et inviter', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGETS REUTILISABLES
// ============================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _P.ink, letterSpacing: -0.2));
  }
}

class _IndividualGiftCard extends StatelessWidget {
  final GiftItem gift;
  final VoidCallback onTap;
  const _IndividualGiftCard({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _P.shadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    gift.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: _P.primarySoft,
                      child: const Icon(Icons.card_giftcard_rounded, color: _P.primary, size: 32),
                    ),
                  ),
                ),
                if (gift.isReserved)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Financé', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gift.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _P.ink)),
                  const SizedBox(height: 6),
                  Text('${gift.price.toStringAsFixed(0)} FCFA', style: const TextStyle(color: _P.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: gift.percent.clamp(0, 1),
                    backgroundColor: _P.primarySoft,
                    color: _P.primary,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 6),
                  Text('${(gift.percent * 100).toStringAsFixed(0)}% contribué', style: const TextStyle(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupGiftsView extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyGroupGiftsView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _P.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _P.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.group_add_rounded, size: 48, color: _P.primary),
            ),
            const SizedBox(height: 20),
            const Text('Aucun cadeau de groupe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink)),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à initier un cadeau commun ! Les autres invités pourront se coordonner via un chat dédié.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _P.inkSoft, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Initier un cadeau de groupe'),
              style: FilledButton.styleFrom(
                backgroundColor: _P.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGiftCard extends ConsumerWidget {
  final GroupGift group;
  final String myThixId;
  final String weddingId;
  const _GroupGiftCard({required this.group, required this.myThixId, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isParticipant = group.isParticipant(myThixId);
    bool loading = false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _P.shadow,
        border: isParticipant ? Border.all(color: _P.accent, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    group.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _P.accentSoft,
                      child: const Icon(Icons.card_giftcard_rounded, color: _P.accent, size: 48),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('${group.participants.length} participants', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (group.isComplete)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Objectif atteint', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: _P.primary),
                        const SizedBox(width: 4),
                        Text('Par ${group.organizerName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _P.ink)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _P.ink)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${group.currentAmount.toStringAsFixed(0)} / ${group.targetAmount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _P.primary),
                      ),
                    ),
                    Text('${(group.percent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: _P.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: group.percent.clamp(0, 1),
                  backgroundColor: _P.primarySoft,
                  color: _P.primary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: group.chatId == null
                            ? null
                            : () => context.push('/thix-weeding/chat/${group.chatId}'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _P.primary),
                          foregroundColor: _P.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isParticipant || group.isComplete || loading
                            ? null
                            : () async {
                                // Join logic
                                try {
                                  final repo = ref.read(groupGiftsRepositoryProvider);
                                  await repo.joinGroupGift(group.id, myThixId);
                                  ref.invalidate(groupGiftsProvider(weddingId));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('✅ Vous avez rejoint "${group.name}"')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.primary),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: isParticipant ? _P.inkSoft : _P.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isParticipant ? '✓ Rejoint' : 'Rejoindre',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
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
