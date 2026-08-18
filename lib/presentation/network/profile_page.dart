// lib/presentation/network/profile_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 1; // Par défaut sur 'Publications'
  bool _isGridView = false;
  bool _isUploading = false;
  bool _isFollowLoading = false;

  // Images locales (priorité sur le profil distant pendant l'upload)
  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  String? _localAvatarUrl;
  String? _localCoverUrl;

  // Nouveaux onglets demandés
  final _tabs = [
    'Bio', 
    'Publications', 
    'Photos publiques', 
    'Vidéos', 
    'Audios', 
    'Galerie privée'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final uid = widget.userId ??
          Supabase.instance.client.auth.currentUser!.id;
      ref.read(userPostsProvider(uid).notifier).loadMore();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPLOAD PHOTO PROFIL / COUVERTURE
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes!;
      final ext = result.files.first.extension ?? 'jpg';

      setState(() {
        if (isAvatar) {
          _localAvatarBytes = bytes;
        } else {
          _localCoverBytes = bytes;
        }
        _isUploading = true;
      });

      final ns = ref.read(networkServiceProvider);
      final bucket = isAvatar ? 'avatars' : 'covers';
      final url = await ns.uploadImageBytes(
        bytes,
        fileExtension: ext,
        bucket: bucket,
      );

      if (url != null) {
        await Supabase.instance.client.from('profiles').update({
          isAvatar ? 'avatar_url' : 'cover_url': url,
        }).eq('id', ns.currentUserId);

        setState(() {
          if (isAvatar) {
            _localAvatarUrl = url;
            _localAvatarBytes = null;
          } else {
            _localCoverUrl = url;
            _localCoverBytes = null;
          }
        });

        final uid = widget.userId ?? ns.currentUserId;
        ref.invalidate(userProfileProvider(uid));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAvatar
                  ? 'Photo de profil mise à jour avec succès'
                  : 'Photo de couverture mise à jour avec succès'),
              backgroundColor: ThixPolicy.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS GALERIE PRIVÉE
  // ─────────────────────────────────────────────────────────────
  Future<void> _uploadPrivateMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);
      final ns = ref.read(networkServiceProvider);
      final uid = ns.currentUserId;

      for (var file in result.files) {
        if (file.bytes == null) continue;
        final ext = file.extension ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';
        final path = '$uid/$fileName';
        
        // Upload dans le bucket 'private_gallery'
        await Supabase.instance.client.storage
            .from('private_gallery')
            .uploadBinary(path, file.bytes!);
            
        final url = Supabase.instance.client.storage.from('private_gallery').getPublicUrl(path);
        
        // Insertion dans la table 'private_gallery'
        await Supabase.instance.client.from('private_gallery').insert({
          'user_id': uid,
          'media_url': url,
          'media_type': (ext.toLowerCase() == 'mp4' || ext.toLowerCase() == 'mov') ? 'video' : 'image',
        });
      }
      
      setState(() {}); // Rafraîchit l'interface pour afficher les nouvelles images
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Média(s) ajouté(s) à votre galerie privée !'), backgroundColor: ThixPolicy.success),
        );
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'upload privé: $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MODIFIER LA BIO
  // ─────────────────────────────────────────────────────────────
  Future<void> _editBio(String currentBio) async {
    final TextEditingController bioController = TextEditingController(text: currentBio);
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: const Text('Modifier ma Bio', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: bioController,
          maxLines: 4,
          maxLength: 300,
          decoration: InputDecoration(
            hintText: 'Parlez un peu de vous...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, bioController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _isUploading = true);
      try {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('profiles').update({'bio': result}).eq('id', uid);
        ref.invalidate(userProfileProvider(uid));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bio mise à jour avec succès'), backgroundColor: ThixPolicy.success),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger),
        );
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FOLLOW / UNFOLLOW
  // ─────────────────────────────────────────────────────────────
  Future<void> _toggleFollow(String targetId, bool currentlyFollowing) async {
    if (_isFollowLoading) return; 
    
    setState(() => _isFollowLoading = true);
    HapticFeedback.lightImpact();
    final ns = ref.read(networkServiceProvider);

    try {
      if (currentlyFollowing) {
        await ns.unfollowUser(targetId);
      } else {
        await ns.followUser(targetId);
      }
      ref.invalidate(followStatusProvider(targetId));
      ref.invalidate(userProfileProvider(targetId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur Follow: $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _handleBlockUser(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer cet utilisateur ?'),
        content: const Text('Vous ne verrez plus ses publications et il ne pourra plus interagir avec vous.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            child: const Text('Bloquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur bloqué.')));
      context.go('/network');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final uid = widget.userId ?? currentUid;
    final isOwn = uid == currentUid;

    final profileAsync = ref.watch(userProfileProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));
    final pinnedAsync = ref.watch(pinnedPostsProvider(uid));

    final userProfile = profileAsync.valueOrNull;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).canPop() ? Navigator.pop(context) : context.go('/network'),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                onSelected: (val) {
                  if (val == 'settings') {
                    context.push('/network/profile-settings');
                  } else if (val == 'block') {
                    _handleBlockUser(uid);
                  } else if (val == 'report') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé.')));
                  }
                },
                itemBuilder: (_) => isOwn
                    ? [const PopupMenuItem(value: 'settings', child: Text('Paramètres du profil'))]
                    : [
                        const PopupMenuItem(value: 'report', child: Text('Signaler')),
                        const PopupMenuItem(value: 'block', child: Text('Bloquer', style: TextStyle(color: Colors.red))),
                      ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(uid));
              ref.read(userPostsProvider(uid).notifier).refresh();
            },
            color: ThixPolicy.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── HEADER (COVER + AVATAR + ACTIONS) ──
                SliverToBoxAdapter(
                  child: userProfile != null
                      ? _buildTopSection(userProfile, isOwn, uid)
                      : Container(height: 240, color: ThixPolicy.inkDeep),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 55)),

                // ── INFO PROFIL (Nom, Profession + Certification) ──
                SliverToBoxAdapter(
                  child: userProfile != null ? _buildProfileInfo(userProfile) : const SizedBox(),
                ),

                // ── STATS ──
                SliverToBoxAdapter(
                  child: userProfile != null ? _buildStats(userProfile, uid) : const SizedBox(),
                ),

                // ── POST ÉPINGLÉ ──
                pinnedAsync.when(
                  data: (pins) => pins.isNotEmpty
                      ? SliverToBoxAdapter(child: _buildPinned(pins.first))
                      : const SliverToBoxAdapter(child: SizedBox()),
                  loading: () => const SliverToBoxAdapter(child: SizedBox()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
                ),

                // ── TABS ──
                SliverToBoxAdapter(child: _buildTabs()),

                // ── CONTENU DES ONGLETS ──
                if (_tabs[_selectedTab] == 'Bio')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProfile?['bio'] ?? 'Aucune biographie disponible pour le moment.',
                            style: ThixPolicy.bodyStyle.copyWith(height: 1.5, fontSize: 15),
                          ),
                          if (isOwn) ...[
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: () => _editBio(userProfile?['bio'] ?? ''),
                              icon: const Icon(Icons.edit_note_rounded, size: 18),
                              label: const Text('Modifier ma Bio'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  )
                else if (_tabs[_selectedTab] == 'Galerie privée')
                  SliverToBoxAdapter(child: _buildPrivateGallery(isOwn, uid))
                else
                  postsAsync.when(
                    data: (posts) {
                      var displayed = posts;
                      
                      if (_tabs[_selectedTab] == 'Photos publiques') {
                        displayed = posts.where((p) => p.hasImages).toList();
                      } else if (_tabs[_selectedTab] == 'Vidéos') {
                        displayed = posts.where((p) => p.hasVideos).toList(); 
                      } else if (_tabs[_selectedTab] == 'Audios') {
                        displayed = posts.where((p) => p.hasAudio).toList();
                      }

                      if (displayed.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.article_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text('Aucun contenu', style: ThixPolicy.bodySmallStyle),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_isGridView) {
                        return SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildGridItem(displayed[i]),
                            childCount: displayed.length,
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: displayed[i],
                              currentProfileId: currentUid,
                              onRefresh: () => ref.read(userPostsProvider(uid).notifier).refresh(),
                            ),
                          ),
                          childCount: displayed.length,
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary))),
                    ),
                    error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erreur: $e'))),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Traitement en cours...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP SECTION (Cover + Avatar sur le même plan)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopSection(Map<String, dynamic> u, bool isOwn, String uid) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Photo de couverture
        Container(
          height: 240, 
          width: double.infinity,
          color: ThixPolicy.inkDeep,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_localCoverBytes != null)
                Image.memory(_localCoverBytes!, fit: BoxFit.cover)
              else if (_localCoverUrl != null)
                Image.network(_localCoverUrl!, fit: BoxFit.cover)
              else if (u['cover_url'] != null)
                Image.network(
                  u['cover_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: ThixPolicy.inkDeep),
                ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),

              if (isOwn)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadImage(isAvatar: false),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Avatar
        Positioned(
          bottom: -46, 
          left: 16,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surface, 
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: _localAvatarBytes != null
                      ? MemoryImage(_localAvatarBytes!)
                      : (_localAvatarUrl != null
                          ? NetworkImage(_localAvatarUrl!)
                          : (u['avatar_url'] != null
                              ? NetworkImage(u['avatar_url'])
                              : null)) as ImageProvider?,
                  child: (_localAvatarBytes == null &&
                          _localAvatarUrl == null &&
                          (u['avatar_url'] == null || u['avatar_url'].toString().isEmpty))
                      ? Icon(Icons.person, size: 48, color: ThixPolicy.primary.withValues(alpha: 0.5))
                      : null,
                ),
              ),
              if (isOwn)
                GestureDetector(
                  onTap: () => _pickAndUploadImage(isAvatar: true),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4, right: 4),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.surface, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                  ),
                ),
            ],
          ),
        ),

        // 3. Boutons d'action
        Positioned(
          bottom: -20,
          right: 16,
          child: isOwn
              ? OutlinedButton.icon(
                  onPressed: () => context.push('/network/profile-settings'),
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Paramètres'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: ThixPolicy.surface,
                    foregroundColor: ThixPolicy.textMain,
                    side: const BorderSide(color: ThixPolicy.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.borderStrong),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.mail_outline_rounded),
                        color: ThixPolicy.textMain,
                        onPressed: () => context.push('/network/messages/chat/$uid'), 
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final followAsync = ref.watch(followStatusProvider(uid));
                        final isFollowing = followAsync.valueOrNull ?? false;

                        return ElevatedButton(
                          onPressed: _isFollowLoading ? null : () => _toggleFollow(uid, isFollowing),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? ThixPolicy.surfaceStrong : ThixPolicy.primary,
                            foregroundColor: isFollowing ? ThixPolicy.textMain : Colors.white,
                            elevation: isFollowing ? 0 : 1,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                          ),
                          child: _isFollowLoading 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isFollowing ? 'Abonné' : 'Suivre',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                        );
                      },
                    ),
                  ],
                ),
        )
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INFO PROFIL AVEC BADGE DE CERTIFICATION
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileInfo(Map<String, dynamic> u) {
    // 1. Parsing du niveau et statut de certification
    final tier = CertificationTierX.parse(u['certification_tier']);
    final status = CertificationStatusX.parse(u['certification_status']);
    
    // 2. Vérification de la validité de la certification
    final isCertified = status == CertificationStatus.approved || 
                        status == CertificationStatus.generated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  u['display_name'] ?? 'Utilisateur THIX',
                  style: ThixPolicy.h2Style.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              
              // 3. Affichage dynamique du badge avec showLabel: false
              if (isCertified)
                CertificationNameBadge(
                  tier: tier,
                  status: status,
                  showLabel: false, // ✅ Ajouté comme demandé (sceau seul)
                  iconSize: 22, 
                  padding: const EdgeInsets.only(left: 6),
                )
              else if (u['is_verified'] == true) // Fallback pour les anciens comptes
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            u['profession'] ?? 'Membre THIX',
            style: ThixPolicy.bodySmallStyle,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────────────────────
  Widget _buildStats(Map<String, dynamic> u, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          _statTile('${u['followers_count'] ?? 0}', 'Abonnés', () => context.push('/network/followers/$uid')),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u['following_count'] ?? 0}', 'Abonnements', () => context.push('/network/following/$uid')),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u['posts_count'] ?? 0}', 'Publications', () {
            _scrollController.animateTo(350, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
          }),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
            const SizedBox(height: 2),
            Text(label, style: ThixPolicy.captionStyle),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GALERIE PRIVÉE UI (Avec fetch depuis Supabase)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPrivateGallery(bool isOwn, String uid) {
    if (!isOwn) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Ce contenu est privé', style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadPrivateMedia,
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
            label: const Text('Ajouter à ma galerie privée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
          ),
          const SizedBox(height: 24),
          
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('private_gallery')
                .select()
                .eq('user_id', uid)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: ThixPolicy.primary));
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Erreur de chargement de la galerie', style: ThixPolicy.captionStyle),
                );
              }
              
              final media = snapshot.data ?? [];
              
              if (media.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.lock_person_rounded, size: 42, color: ThixPolicy.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun média privé pour le moment.', style: ThixPolicy.captionStyle),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: media.length,
                itemBuilder: (context, index) {
                  final item = media[index];
                  final url = item['media_url'] as String;
                  return Image.network(url, fit: BoxFit.cover);
                },
              );
            },
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _selectedTab == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected ? ThixPolicy.inkDeep : ThixPolicy.card,
                          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                          border: Border.all(color: selected ? ThixPolicy.inkDeep : ThixPolicy.border),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            color: selected ? Colors.white : ThixPolicy.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (_tabs[_selectedTab] != 'Bio' && _tabs[_selectedTab] != 'Galerie privée')
            IconButton(
              icon: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded, color: ThixPolicy.textSecondary),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GRID ITEM
  // ─────────────────────────────────────────────────────────────
  Widget _buildGridItem(NetworkPost post) {
    String? mediaUrl;
    if (post.hasImages) mediaUrl = post.imageUrls.first;

    return GestureDetector(
      onTap: () => context.push('/network/comments/${post.id}'),
      child: Container(
        color: ThixPolicy.card,
        child: mediaUrl != null
            ? Image.network(mediaUrl, fit: BoxFit.cover)
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(
                    post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep),
                  ),
                ),
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PINNED
  // ─────────────────────────────────────────────────────────────
  Widget _buildPinned(NetworkPost post) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_rounded, color: ThixPolicy.gold, size: 15),
              const SizedBox(width: 6),
              Text('Publication épinglée', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.gold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodyStyle),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => context.push('/network/comments/${post.id}'),
            child: Text('Voir la publication', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary)),
          ),
        ],
      ),
    );
  }
}
