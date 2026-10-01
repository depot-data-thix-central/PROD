// lib/presentation/network/profile_page.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ProfileValidators {
  _ProfileValidators._();

  static const int maxAvatarSizeMB = 5;
  static const int maxCoverSizeMB = 10;
  static const int maxPrivateMediaSizeMB = 50;
  static const int maxBioLength = 300;
  static const int maxPrivateMediaCount = 50;
  static const Duration uploadTimeout = Duration(seconds: 30);
  static const Duration requestTimeout = Duration(seconds: 15);

  static const Set<String> allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> allowedVideoExts = {'mp4', 'mov', 'webm', 'm4v'};

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool validateFileSize(int bytes, int maxMB) => bytes <= maxMB * 1024 * 1024;

  static bool validateFileExtension(String name, Set<String> allowed) {
    final ext = name.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'Fichier trop petit';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null; // JPEG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null; // PNG
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return null; // WebP / RIFF
    }
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return null; // MP4/MOV
    }
    return 'Format de fichier non reconnu';
  }
}

// ============================================================================
// COMPRESSION
// ============================================================================
Future<Uint8List> _compressImageAsync(Uint8List bytes, {int quality = 85}) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(
        input,
        minHeight: 1080,
        minWidth: 1080,
        quality: quality,
      );
    }, bytes);
  } catch (e) {
    debugPrint('[Profile] Compression error: $e');
    return bytes;
  }
}

// ============================================================================
// AVATAR CIRCULAIRE (plus d'hexagone)
// ============================================================================
class _ProfileCircleAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final IconData fallbackIcon;

  const _ProfileCircleAvatar({
    required this.size,
    this.imageUrl,
    this.imageBytes,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ThixPolicy.surface,
        border: Border.all(color: ThixPolicy.surface, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageBytes != null
            ? Image.memory(imageBytes!, fit: BoxFit.cover, width: size, height: size)
            : imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                    errorWidget: (_, __, ___) => Icon(
                      fallbackIcon,
                      size: size * 0.42,
                      color: ThixPolicy.primary.withOpacity(0.5),
                    ),
                  )
                : Container(
                    color: ThixPolicy.surfaceSoft,
                    child: Icon(
                      fallbackIcon,
                      size: size * 0.42,
                      color: ThixPolicy.primary.withOpacity(0.5),
                    ),
                  ),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  int _selectedTab = 1;
  bool _isGridView = false;
  bool _isUploading = false;
  bool _isFollowLoading = false;

  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  String? _localAvatarUrl;
  String? _localCoverUrl;

  final _tabs = ['Bio', 'Publications', 'Photos publiques', 'Vidéos', 'Audios', 'Galerie privée'];

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final uid = widget.userId ?? Supabase.instance.client.auth.currentUser!.id;
      ref.read(userPostsProvider(uid).notifier).loadMore();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── UPLOAD AVATAR / COVER ───
  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    if (_isUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final file = result?.files.first;
      if (file == null || file.bytes == null) return;

      final maxSize = isAvatar ? _ProfileValidators.maxAvatarSizeMB : _ProfileValidators.maxCoverSizeMB;
      if (!_ProfileValidators.validateFileSize(file.bytes!.length, maxSize)) {
        _showError('Image trop volumineuse (max ${maxSize}MB)');
        return;
      }
      if (!_ProfileValidators.validateFileExtension(file.name, _ProfileValidators.allowedImageExts)) {
        _showError('Format non supporté (JPG, PNG, WebP, HEIC)');
        return;
      }
      final mimeErr = _ProfileValidators.validateMime(file.bytes!);
      if (mimeErr != null) {
        _showError(mimeErr);
        return;
      }

      setState(() {
        if (isAvatar) {
          _localAvatarBytes = file.bytes;
        } else {
          _localCoverBytes = file.bytes;
        }
        _isUploading = true;
      });

      HapticFeedback.mediumImpact();

      final ns = ref.read(networkServiceProvider);
      final bucket = isAvatar ? 'avatars' : 'covers';

      Uint8List uploadBytes = file.bytes!;
      try {
        uploadBytes = await _compressImageAsync(file.bytes!, quality: 88);
      } catch (e) {
        debugPrint('[Profile] Compression failed: $e');
      }

      String? uploadedUrl;
      try {
        final url = await ns
            .uploadImageBytes(uploadBytes, fileExtension: file.extension ?? 'jpg', bucket: bucket)
            .timeout(_ProfileValidators.uploadTimeout);

        uploadedUrl = url;

        await Supabase.instance.client
            .from('profiles')
            .update({isAvatar ? 'avatar_url' : 'cover_url': url})
            .eq('id', ns.currentUserId)
            .timeout(_ProfileValidators.requestTimeout);

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
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(isAvatar ? 'Photo de profil mise à jour' : 'Photo de couverture mise à jour'),
                ],
              ),
              backgroundColor: ThixPolicy.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
          );
        }
      } catch (e) {
        debugPrint('[Profile] Upload error: $e');
        if (uploadedUrl != null) {
          await _cleanupUploadedFile(uploadedUrl, bucket);
        }
        _showError('Erreur lors de la mise à jour');
      }
    } catch (e) {
      debugPrint('[Profile] Pick image error: $e');
      _showError('Erreur lors de la sélection');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _cleanupUploadedFile(String url, String bucket) async {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
      final filePath = path.replaceFirst('$bucket/', '');
      await Supabase.instance.client.storage.from(bucket).remove([filePath]);
    } catch (e) {
      debugPrint('[Profile] Cleanup error: $e');
    }
  }
  
  // ─── GALERIE PRIVÉE ───
  Future<void> _uploadPrivateMedia() async {
    if (_isUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      if (result.files.length > 10) {
        _showError('Maximum 10 fichiers par upload');
        return;
      }

      setState(() => _isUploading = true);
      final ns = ref.read(networkServiceProvider);
      final uid = ns.currentUserId;

      int successCount = 0;
      int errorCount = 0;

      for (var file in result.files) {
        if (file.bytes == null) {
          errorCount++;
          continue;
        }

        final ext = file.extension?.toLowerCase() ?? 'jpg';
        if (!_ProfileValidators.validateFileSize(file.bytes!.length, _ProfileValidators.maxPrivateMediaSizeMB)) {
          errorCount++;
          continue;
        }

        final isVideo = _ProfileValidators.allowedVideoExts.contains(ext);
        final isImage = _ProfileValidators.allowedImageExts.contains(ext);
        if (!isVideo && !isImage) {
          errorCount++;
          continue;
        }

        try {
          Uint8List uploadBytes = file.bytes!;
          if (isImage) {
            try {
              uploadBytes = await _compressImageAsync(file.bytes!, quality: 85);
            } catch (_) {}
          }

          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';
          final path = '$uid/$fileName';

          await Supabase.instance.client.storage
              .from('private_gallery')
              .uploadBinary(path, uploadBytes)
              .timeout(_ProfileValidators.uploadTimeout);

          final url = Supabase.instance.client.storage.from('private_gallery').getPublicUrl(path);

          await Supabase.instance.client.from('private_gallery').insert({
            'user_id': uid,
            'media_url': url,
            'media_type': isVideo ? 'video' : 'image',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }).timeout(_ProfileValidators.requestTimeout);

          successCount++;
        } catch (e) {
          debugPrint('[Profile] Upload error for ${file.name}: $e');
          errorCount++;
        }
      }

      setState(() {});
      if (mounted) {
        final message = successCount > 0
            ? '$successCount média${successCount > 1 ? 's' : ''} ajouté${successCount > 1 ? 's' : ''}'
            : 'Aucun média ajouté';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorCount > 0
                  ? '$message ($errorCount erreur${errorCount > 1 ? 's' : ''})'
                  : message,
            ),
            backgroundColor: successCount > 0 ? ThixPolicy.success : ThixPolicy.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Profile] Private gallery error: $e');
      _showError('Erreur d\'upload privé');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── EDIT BIO ───
  Future<void> _editBio(String currentBio) async {
    final bioController = TextEditingController(text: currentBio);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Modifier ma Bio', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
        content: TextField(
          controller: bioController,
          maxLines: 4,
          maxLength: _ProfileValidators.maxBioLength,
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: 'Parlez un peu de vous...',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
            ),
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, bioController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentBio && mounted) {
      setState(() => _isUploading = true);
      try {
        final uid = Supabase.instance.client.auth.currentUser!.id;
        final sanitized = _ProfileValidators.sanitize(result, maxLength: _ProfileValidators.maxBioLength);

        await Supabase.instance.client
            .from('profiles')
            .update({'bio': sanitized})
            .eq('id', uid)
            .timeout(_ProfileValidators.requestTimeout);

        ref.invalidate(userProfileProvider(uid));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Bio mise à jour'),
                ],
              ),
              backgroundColor: ThixPolicy.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('[Profile] Bio update error: $e');
        _showError('Erreur lors de la mise à jour');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  // ─── FOLLOW / UNFOLLOW ───
  Future<void> _toggleFollow(String targetId, bool currentlyFollowing) async {
    if (_isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final ns = ref.read(networkServiceProvider);
      if (currentlyFollowing) {
        await ns.unfollowUser(targetId).timeout(_ProfileValidators.requestTimeout);
      } else {
        await ns.followUser(targetId).timeout(_ProfileValidators.requestTimeout);
      }
      ref.invalidate(followStatusProvider(targetId));
      ref.invalidate(userProfileProvider(targetId));
    } catch (e) {
      debugPrint('[Profile] Follow error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  // ─── BLOCK ───
  Future<void> _handleBlockUser(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: ThixPolicy.danger, size: 24),
            const SizedBox(width: 8),
            Text('Bloquer cet utilisateur ?',
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
          ],
        ),
        content: Text(
          'Vous ne verrez plus ses publications et il ne pourra plus interagir avec vous.',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        final currentUid = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('blocked_users').insert({
          'blocker_id': currentUid,
          'blocked_id': uid,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).timeout(_ProfileValidators.requestTimeout);

        try {
          await ref.read(networkServiceProvider).unfollowUser(uid);
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.block_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Utilisateur bloqué'),
                ],
              ),
              backgroundColor: ThixPolicy.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/network');
        }
        HapticFeedback.heavyImpact();
      } catch (e) {
        debugPrint('[Profile] Block error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors du blocage'),
              backgroundColor: ThixPolicy.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ─── OPEN CHAT (route correcte) ───
  void _openChat(String uid, Map<String, dynamic> u) {
    HapticFeedback.selectionClick();
    context.push(
      '/network/chat/$uid',
      extra: {
        'userName': _ProfileValidators.sanitize(
          u['display_name']?.toString() ?? 'Discussion',
          maxLength: 50,
        ),
        'userAvatar': _ProfileValidators.sanitizeUrl(u['avatar_url']?.toString()),
      },
    );
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final uid = widget.userId ?? currentUid;
    final isOwn = uid == currentUid;

    final profileAsync = ref.watch(userProfileProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('Erreur: $e', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger))),
        data: (userProfile) {
          final u = userProfile ?? <String, dynamic>{};
          return Stack(
            children: [
              RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: () async {
                  ref.invalidate(userProfileProvider(uid));
                  ref.invalidate(userPostsProvider(uid));
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopSection(u, isOwn, uid)),
                    const SliverToBoxAdapter(child: SizedBox(height: 56)),
                    SliverToBoxAdapter(child: _buildProfileInfo(u)),
                    SliverToBoxAdapter(child: _buildStats(u, uid)),
                    SliverToBoxAdapter(child: _buildTabs()),
                    if (_tabs[_selectedTab] == 'Bio')
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ProfileValidators.sanitize(u['bio'], maxLength: _ProfileValidators.maxBioLength).isEmpty
                                    ? 'Aucune biographie disponible pour le moment.'
                                    : _ProfileValidators.sanitize(u['bio'], maxLength: _ProfileValidators.maxBioLength),
                                style: ThixPolicy.bodyStyle.copyWith(height: 1.5, fontSize: 15),
                              ),
                              if (isOwn) ...[
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: () => _editBio(u['bio'] ?? ''),
                                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                                  label: const Text('Modifier ma Bio'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                                  ),
                                ),
                              ],
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
                                    Icon(Icons.article_outlined, size: 48, color: ThixPolicy.textMuted),
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
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
                          ),
                        ),
                        error: (e, _) => SliverToBoxAdapter(
                          child: Center(
                            child: Text('Erreur: $e', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
              if (_isUploading)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        boxShadow: ThixPolicy.shadowCard(),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: ThixPolicy.primary),
                          const SizedBox(height: 16),
                          Text('Traitement en cours...', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─── TOP SECTION (avatar CIRCULAIRE + chat) ───
  Widget _buildTopSection(Map<String, dynamic> u, bool isOwn, String uid) {
    final avatarUrl = _ProfileValidators.sanitizeUrl(_localAvatarUrl ?? u['avatar_url']?.toString());
    final coverUrl = _ProfileValidators.sanitizeUrl(_localCoverUrl ?? u['cover_url']?.toString());

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 240,
          width: double.infinity,
          color: ThixPolicy.inkDeep,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_localCoverBytes != null)
                Image.memory(_localCoverBytes!, fit: BoxFit.cover)
              else if (coverUrl != null)
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: ThixPolicy.inkDeep),
                  errorWidget: (_, __, ___) => Container(color: ThixPolicy.inkDeep),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.25), Colors.black.withOpacity(0.0)],
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
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Avatar circulaire
        Positioned(
          bottom: -46,
          left: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileCircleAvatar(size: 96, imageUrl: avatarUrl, imageBytes: _localAvatarBytes),
              if (isOwn)
                Positioned(
                  bottom: 2,
                  right: -2,
                  child: GestureDetector(
                    onTap: () => _pickAndUploadImage(isAvatar: true),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.surface, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Boutons droite : chat + follow / paramètres
        Positioned(
          bottom: -20,
          right: 16,
          child: isOwn
              ? OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/network/profile-settings');
                  },
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
                    // Bouton message → route correcte
                    Container(
                      decoration: BoxDecoration(
                        color: ThixPolicy.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.borderStrong),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.mail_outline_rounded),
                        color: ThixPolicy.textMain,
                        onPressed: () => _openChat(uid, u),
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
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  isFollowing ? 'Abonné' : 'Suivre',
                                  style: ThixPolicy.labelStyle.copyWith(
                                    fontWeight: ThixPolicy.bold,
                                    color: isFollowing ? ThixPolicy.textMain : Colors.white,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(Map<String, dynamic> u) {
    final tier = CertificationTierX.parse(u['certification_tier']);
    final status = CertificationStatusX.parse(u['certification_status']);
    final isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    final displayName = _ProfileValidators.sanitize(u['display_name']?.toString() ?? 'Utilisateur THIX', maxLength: 100);
    final profession = _ProfileValidators.sanitize(u['profession']?.toString() ?? 'Membre THIX', maxLength: 100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: ThixPolicy.h2Style.copyWith(fontWeight: ThixPolicy.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCertified)
                CertificationNameBadge(
                  tier: tier,
                  status: status,
                  showLabel: false,
                  iconSize: 22,
                  padding: const EdgeInsets.only(left: 6),
                )
              else if (u['is_verified'] == true)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(profession, style: ThixPolicy.bodySmallStyle),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> u, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: Row(
        children: [
          _statTile('${u['followers_count'] ?? 0}', 'Abonnés', () {
            HapticFeedback.selectionClick();
            context.push('/network/followers/$uid');
          }),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u['following_count'] ?? 0}', 'Abonnements', () {
            HapticFeedback.selectionClick();
            context.push('/network/following/$uid');
          }),
          Container(width: 1, height: 28, color: ThixPolicy.border),
          _statTile('${u['posts_count'] ?? 0}', 'Publications', () {
            HapticFeedback.selectionClick();
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
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Column(
          children: [
            Text(value, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.inkDeep)),
            const SizedBox(height: 2),
            Text(label, style: ThixPolicy.captionStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateGallery(bool isOwn, String uid) {
    if (!isOwn) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: ThixPolicy.textMuted),
            const SizedBox(height: 12),
            Text('Ce contenu est privé', style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold)),
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
            label: Text(
              'Ajouter à ma galerie privée',
              style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('private_gallery')
                .select()
                .eq('user_id', uid)
                .order('created_at', ascending: false)
                .timeout(_ProfileValidators.requestTimeout),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: ThixPolicy.primary),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Erreur de chargement', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger)),
                );
              }

              final media = snapshot.data ?? [];
              if (media.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.lock_person_rounded, size: 42, color: ThixPolicy.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('Aucun média privé pour le moment', style: ThixPolicy.captionStyle),
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
                  final url = _ProfileValidators.sanitizeUrl(item['media_url']?.toString());
                  final mediaType = item['media_type']?.toString() ?? 'image';

                  return GestureDetector(
                    onTap: () => HapticFeedback.selectionClick(),
                    child: url != null
                        ? CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                            errorWidget: (_, __, ___) => Container(
                              color: ThixPolicy.surfaceSoft,
                              child: const Icon(Icons.broken_image, color: ThixPolicy.textMuted),
                            ),
                          )
                        : Container(
                            color: ThixPolicy.surfaceSoft,
                            child: Icon(
                              mediaType == 'video' ? Icons.videocam_rounded : Icons.image_rounded,
                              color: ThixPolicy.textMuted,
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = i);
                      },
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
                          style: ThixPolicy.labelStyle.copyWith(
                            color: selected ? Colors.white : ThixPolicy.textSecondary,
                            fontWeight: ThixPolicy.bold,
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
              icon: Icon(
                _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                color: ThixPolicy.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _isGridView = !_isGridView);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGridItem(NetworkPost post) {
    final mediaUrl = post.hasImages ? _ProfileValidators.sanitizeUrl(post.imageUrls.first) : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/comments/${post.id}');
      },
      child: Container(
        color: ThixPolicy.card,
        child: mediaUrl != null
            ? CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                errorWidget: (_, __, ___) => Container(
                  color: ThixPolicy.surfaceSoft,
                  child: const Icon(Icons.broken_image, color: ThixPolicy.textMuted),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(
                    _ProfileValidators.sanitize(post.content, maxLength: 200),
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
}
