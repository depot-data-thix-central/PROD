// lib/presentation/network/widgets/comments_page.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/models/comment.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/comments_provider.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';
import 'package:timeago/timeago.dart' as timeago;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CommentValidators {
  _CommentValidators._();

  static const int maxCommentLength = 2000;
  // ✅ NOUVEAU : limite de caractères spécifique aux comptes gratuits.
  static const int maxCommentLengthFree = 280;
  static const int maxAudioDurationSeconds = 30;
  static const int maxImageSizeMB = 10;

  static String sanitize(String? input, {int maxLength = maxCommentLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }
}

// ============================================================================
// EMOJIS / REACTIONS / FLAGS
// ============================================================================
static const List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','🥲','🥹',
    '😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗',
    '😙','😚','🤩','🥳','🤗','🤔','🤭','🤫','🤥','😏',
    '😒','🙄','😬','😮‍💨','😔','😪','🤤','😴','😷','🤒',
    '🤕','🤢','🤮','🥵','🥶','😵','🤯','🤠','🥸','😎',
    '🤓','🧐','😕','😟','🙁','☹️','😮','😯','😲','😳',
    '🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖',
    '😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬',
  ];

  static const List<String> _reactions = [
    '👍','👎','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘',
    '🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖',
    '👋','👏','🙌','🫶','💪','🦾','🙏','✍️',
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❣️','💕','💞','💓','💗','💖','💘','💝','💟','❤️‍🔥',
    '🔥','⭐','🌟','✨','💫','💥','💯','🎉','🎊','🏆',
    '🥇','🥈','🥉','🎯','✅','❌','⚡','💡','📌','🔔',
  ];

  static const List<String> _flags = [
    '🏁','🚩','🎌','🏴','🏳️','🏳️‍⚧️','🏴‍☠️',
    '🇦🇫','🇿🇦','🇦🇱','🇩🇿','🇩🇪','🇦🇩','🇦🇴','🇦🇬',
    '🇸🇦','🇦🇷','🇦🇲','🇦🇺','🇦🇹','🇦🇿','🇧🇸','🇧🇭',
    '🇧🇩','🇧🇧','🇧🇪','🇧🇿','🇧🇯','🇧🇹','🇧🇾','🇲🇲',
    '🇧🇴','🇧🇦','🇧🇼','🇧🇷','🇧🇳','🇧🇬','🇧🇫','🇧🇮',
    '🇰🇭','🇨🇲','🇨🇦','🇨🇻','🇨🇱','🇨🇳','🇨🇾','🇨🇴',
    '🇰🇲','🇨🇬','🇨🇩','🇰🇵','🇰🇷','🇨🇷','🇨🇮','🇭🇷',
    '🇨🇺','🇩🇰','🇩🇯','🇩🇲','🇪🇬','🇸🇻','🇦🇪','🇪🇨',
    '🇪🇷','🇪🇸','🇪🇪','🇺🇸','🇪🇹','🇫🇯','🇫🇮','🇫🇷',
    '🇬🇦','🇬🇲','🇬🇪','🇬🇭','🇬🇷','🇬🇩','🇬🇹','🇬🇳',
    '🇬🇶','🇬🇾','🇭🇹','🇭🇳','🇭🇰','🇭🇺','🇮🇳','🇮🇩',
    '🇮🇷','🇮🇶','🇮🇪','🇮🇸','🇮🇱','🇮🇹','🇯🇲','🇯🇵',
    '🇯🇴','🇰🇿','🇰🇪','🇰🇬','🇰🇼','🇱🇦','🇱🇻','🇱🇧',
    '🇱🇷','🇱🇾','🇱🇮','🇱🇹','🇱🇺','🇲🇬','🇲🇾','🇲🇼',
    '🇲🇻','🇲🇱','🇲🇹','🇲🇦','🇲🇺','🇲🇽','🇲🇩','🇲🇨',
    '🇲🇳','🇲🇪','🇲🇿','🇳🇦','🇳🇵','🇳🇮','🇳🇪','🇳🇬',
    '🇳🇴','🇳🇿','🇴🇲','🇺🇬','🇺🇿','🇵🇰','🇵🇸','🇵🇦',
    '🇵🇬','🇵🇾','🇳🇱','🇵🇪','🇵🇭','🇵🇱','🇵🇹','🇶🇦',
    '🇨🇫','🇩🇴','🇷🇴','🇬🇧','🇷🇺','🇷🇼','🇸🇳','🇷🇸',
    '🇸🇨','🇸🇱','🇸🇬','🇸🇰','🇸🇮','🇸🇴','🇸🇩','🇱🇰',
    '🇸🇪','🇨🇭','🇸🇾','🇹🇯','🇹🇼','🇹🇿','🇹🇩','🇨🇿',
    '🇹🇭','🇹🇬','🇹🇴','🇹🇹','🇹🇳','🇹🇷','🇺🇦','🇺🇾',
    '🇻🇪','🇻🇳','🇾🇪','🇿🇲','🇿🇼',
  ];

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class CommentsPage extends ConsumerStatefulWidget {
  final String postId;
  final String currentProfileId;

  const CommentsPage({super.key, required this.postId, required this.currentProfileId});

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  NetworkPost? _post;
  bool _isLoadingPost = true;
  bool _isSubmitting = false;
  String? _replyingTo;
  String? _replyingToName;

  final Set<String> _expandedComments = {};

  // ─── MÉDIAS ───
  Uint8List? _imageBytes;
  Uint8List? _audioBytes;
  String? _localAudioPath;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;

  bool _showStickers = false;

  // ─── LOGIQUE DES LIMITES ───
  bool _isLoadingLimits = true;
  String _userTier = 'gratuit';
  bool get _isFree => _userTier == 'gratuit' || _userTier == 'none';

  // ✅ NOUVEAU : longueur maximale de commentaire selon le palier du compte.
  int get _maxCommentLengthForUser =>
      _isFree ? _CommentValidators.maxCommentLengthFree : _CommentValidators.maxCommentLength;

  @override
  void initState() {
    super.initState();
    _loadUserLimits();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        ref.read(commentsProvider(widget.postId).notifier).loadMore();
      }
    });
    _loadPost();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserLimits() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? widget.currentProfileId;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('certification_tier')
          .eq('id', uid)
          .maybeSingle();

      final tier = (profile?['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';

      if (mounted) {
        setState(() {
          _userTier = tier;
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('[Comments] Load limits error: $e');
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _loadPost() async {
    try {
      final p = await ref.read(networkServiceProvider).getPostById(widget.postId);
      if (mounted) setState(() { _post = p; _isLoadingPost = false; });
    } catch (e) {
      debugPrint('[Comments] Load post error: $e');
      if (mounted) setState(() => _isLoadingPost = false);
    }
  }

  // ─── DIALOG UPGRADE (uniquement pour l'audio) ───
  void _showUpgradeDialog(String featureName, String requiredTier) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.gold, size: 28),
            const SizedBox(width: 8),
            Text('Fonctionnalité bloquée', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(
          "$featureName est réservée aux comptes $requiredTier et supérieurs.\n\nMettez à niveau votre compte pour débloquer cette fonctionnalité.",
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Plus tard', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: ThixPolicy.inkDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: Text('Voir les offres', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: Text('Permission requise', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          content: Text('Vous avez précédemment refusé cette permission. Veuillez l\'activer dans les paramètres.', style: ThixPolicy.bodyStyle),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Paramètres')),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
      return false;
    }

    if (!mounted) return false;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
            const SizedBox(width: 10),
            Text("Autorisation requise", style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text(explanation, style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Annuler", style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Compris", style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );

    if (userAgreed != true) return false;
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  // ─── AUDIO (bloqué pour gratuits uniquement) ───
  Future<void> _startRecording() async {
    if (_isFree) {
      _showUpgradeDialog('Les commentaires vocaux', 'Standard');
      return;
    }

    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.microphone,
      "Pour enregistrer un commentaire vocal, THIX ID a besoin d'accéder à votre microphone.",
    );
    if (!hasPerm) return;

    try {
      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = p.join(dir.path, 'comment_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      }

      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: path);

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _localAudioPath = null;
        _showStickers = false;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _recordDuration++);
        if (_recordDuration >= _CommentValidators.maxAudioDurationSeconds) {
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Durée maximale atteinte (${_CommentValidators.maxAudioDurationSeconds}s)'), backgroundColor: ThixPolicy.warning),
          );
        }
      });
    } catch (e) {
      debugPrint('[Comments] Record error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Erreur lors du démarrage du micro'), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        Uint8List bytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          bytes = response.bodyBytes;
        } else {
          final file = XFile(path);
          bytes = await file.readAsBytes();
        }
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('[Comments] Stop record error: $e');
    }
  }

  Future<void> _pickImage() async {
    if (_isFree) {
      _showUpgradeDialog('Les images dans les commentaires', 'Standard');
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.bytes!.length > _CommentValidators.maxImageSizeMB * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image trop volumineuse (max ${_CommentValidators.maxImageSizeMB}MB)'), backgroundColor: ThixPolicy.danger),
          );
        }
        return;
      }
      setState(() {
        _imageBytes = file.bytes;
        _showStickers = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  // ─── SOUMISSION ───
  Future<void> _submitComment({String? parentId}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && _audioBytes == null && _imageBytes == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final ns = ref.read(networkServiceProvider);
      String? audioUrl;
      String? imageUrl;

      if (_audioBytes != null && _audioBytes!.isNotEmpty) {
        audioUrl = await ns.uploadAudioBytes(_audioBytes!);
      }

      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        imageUrl = await ns.uploadImageBytes(_imageBytes!, fileExtension: 'jpg', bucket: 'post_images');
      }

      // ✅ Applique la limite de caractères correspondant au palier de l'utilisateur.
      String finalContent = _CommentValidators.sanitize(text, maxLength: _maxCommentLengthForUser);
      if (finalContent.isEmpty) {
        if (audioUrl != null) finalContent = '🎤 Note vocale';
        else if (imageUrl != null) finalContent = '📷 Photo';
      }

      await ns.addComment(
        widget.postId,
        finalContent,
        parentId: parentId ?? _replyingTo,
        audioUrl: audioUrl,
        imageUrl: imageUrl,
      );

      if (_replyingTo != null) {
        _expandedComments.add(_replyingTo!);
      }

      ref.invalidate(commentsProvider(widget.postId));

      setState(() {
        _controller.clear();
        _audioBytes = null;
        _localAudioPath = null;
        _imageBytes = null;
        _showStickers = false;
      });
      _clearReply();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[Comments] Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearReply() => setState(() { _replyingTo = null; _replyingToName = null; });

  void _startReply(String userName, String commentId) {
    setState(() { _replyingTo = commentId; _replyingToName = userName; });
    _focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleLikeComment(Comment comment) async {
    final oldLiked = comment.isLiked;
    final oldCount = comment.likesCount;
    setState(() {
      comment.isLiked = !oldLiked;
      comment.likesCount = oldLiked ? oldCount - 1 : oldCount + 1;
    });
    HapticFeedback.selectionClick();
    try {
      if (comment.isLiked) {
        await ref.read(networkServiceProvider).likeComment(comment.id);
      } else {
        await ref.read(networkServiceProvider).unlikeComment(comment.id);
      }
    } catch (_) {
      setState(() {
        comment.isLiked = oldLiked;
        comment.likesCount = oldCount;
      });
    }
  }

  // ─── MENU 3 POINTS (MODERNE) ───
  void _showCommentActions(Comment comment, String currentUserId) async {
    FocusScope.of(context).unfocus();
    final isOwnComment = comment.userId == currentUserId;
    final isPostOwner = _post?.userId == currentUserId;
    final canDelete = isOwnComment || isPostOwner;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: ThixPolicy.primary),
                title: Text('Répondre', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: ThixPolicy.textMain),
                title: Text('Copier le texte', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
              if (isOwnComment && (comment.audioUrl == null || comment.audioUrl!.isEmpty))
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: ThixPolicy.textMain),
                  title: Text('Modifier', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger),
                  title: Text('Supprimer', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              if (!isOwnComment)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: ThixPolicy.warning),
                  title: Text('Signaler', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.warning)),
                  onTap: () => Navigator.pop(context, 'report'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case 'reply':
        _startReply(comment.userName, comment.parentId ?? comment.id);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: comment.content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Texte copié'),
                ],
              ),
              backgroundColor: ThixPolicy.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'edit':
        _editComment(comment);
        break;
      case 'delete':
        _confirmDelete(comment);
        break;
      case 'report':
        _showReportDialog(comment);
        break;
    }
  }

  void _editComment(Comment comment) async {
    final ctrl = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Modifier le commentaire', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: _maxCommentLengthForUser,
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.trim().isNotEmpty && newContent != comment.content) {
      try {
        await Supabase.instance.client
            .from('comments')
            .update({'content': _CommentValidators.sanitize(newContent, maxLength: _maxCommentLengthForUser)})
            .eq('id', comment.id);
        ref.invalidate(commentsProvider(widget.postId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commentaire modifié'), backgroundColor: ThixPolicy.success),
          );
        }
      } catch (e) {
        debugPrint('[Comments] Edit error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger),
          );
        }
      }
    }
  }

  void _confirmDelete(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Supprimer ?', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
        content: Text('Ce commentaire sera définitivement supprimé.', style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('comments').delete().eq('id', comment.id);
        ref.invalidate(commentsProvider(widget.postId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commentaire supprimé'), backgroundColor: ThixPolicy.success),
          );
        }
      } catch (e) {
        debugPrint('[Comments] Delete error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger),
          );
        }
      }
    }
  }

  Future<void> _showReportDialog(Comment comment) async {
    const reasons = [
      'Spam ou publicité',
      'Contenu inapproprié',
      'Harcèlement',
      'Désinformation',
      'Autre',
    ];

    String? selectedReason;
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          title: Row(
            children: [
              const Icon(Icons.flag_outlined, color: ThixPolicy.warning, size: 22),
              const SizedBox(width: 8),
              Text('Signaler ce commentaire', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pourquoi signalez-vous ce commentaire ?', style: ThixPolicy.bodySmallStyle),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      hint: Text('Choisir un motif', style: ThixPolicy.bodySmallStyle),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setDialogState(() => selectedReason = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Détails (optionnel)',
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedReason == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.warning, foregroundColor: Colors.white),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await Supabase.instance.client.from('comment_reports').insert({
        'comment_id': comment.id,
        'reporter_id': uid,
        'reason': selectedReason,
        'details': _CommentValidators.sanitize(detailsController.text.trim(), maxLength: 300),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement envoyé'), backgroundColor: ThixPolicy.success),
        );
      }
    } catch (e) {
      debugPrint('[Comments] Report error: $e');
      final msg = e.toString().contains('duplicate') ? 'Déjà signalé' : 'Erreur';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  void _insertSticker(String sticker) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) {
      _controller.text = '$text$sticker';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    } else {
      final newText = text.replaceRange(sel.start, sel.end, sticker);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: sel.start + sticker.length);
    }
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? widget.currentProfileId;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text('Commentaires', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        iconTheme: const IconThemeData(color: ThixPolicy.textMain),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(commentsProvider(widget.postId)),
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textSecondary),
          ),
        ],
      ),
      body: _isLoadingPost && _post == null
          ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      await _loadPost();
                      ref.invalidate(commentsProvider(widget.postId));
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (_post != null)
                          SliverToBoxAdapter(
                            child: PostCard(
                              post: _post!,
                              currentProfileId: widget.currentProfileId,
                              onTap: () {},
                              onRefresh: _loadPost,
                            ),
                          ),
                        commentsAsync.when(
                          loading: () => const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
                            ),
                          ),
                          error: (e, _) => SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text('Erreur: $e', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
                              ),
                            ),
                          ),
                          data: (comments) => comments.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.comment_outlined, size: 60, color: ThixPolicy.textMuted),
                                        const SizedBox(height: 12),
                                        Text('Soyez le premier à commenter !', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildCommentThread(comments[index], currentUserId, depth: 0),
                                    childCount: comments.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildInputBar(),
                if (_showStickers) _buildStickerPicker(),
              ],
            ),
    );
  }

  // ─── THREAD IMBRIQUÉ STYLE RÉSEAUX SOCIAUX ───
  Widget _buildCommentThread(Comment comment, String? currentUserId, {int depth = 0}) {
    final hasReplies = comment.replies.isNotEmpty;
    final isExpanded = _expandedComments.contains(comment.id);

    List<Widget> threadChildren = [
      _CommentBubble(
        comment: comment,
        currentUserId: currentUserId,
        isReply: depth > 0,
        depth: depth,
        isLastReply: !hasReplies,
        onLongPress: () => _showCommentActions(comment, currentUserId ?? ''),
        onMenuTap: () => _showCommentActions(comment, currentUserId ?? ''),
        onLike: () => _toggleLikeComment(comment),
        onReply: () => _startReply(comment.userName, comment.id),
      ),
    ];

    if (hasReplies) {
      if (!isExpanded && comment.replies.length > 1) {
        final hiddenCount = comment.replies.length - 1;
        threadChildren.add(_buildViewMoreRepliesBtn(comment, hiddenCount, depth));
        final lastReply = comment.replies.last;
        threadChildren.add(
          _CommentBubble(
            comment: lastReply,
            currentUserId: currentUserId,
            isReply: true,
            depth: depth + 1,
            isLastReply: true,
            onLongPress: () => _showCommentActions(lastReply, currentUserId ?? ''),
            onMenuTap: () => _showCommentActions(lastReply, currentUserId ?? ''),
            onLike: () => _toggleLikeComment(lastReply),
            onReply: () => _startReply(lastReply.userName, lastReply.parentId ?? lastReply.id),
          ),
        );
      } else {
        for (int i = 0; i < comment.replies.length; i++) {
          final reply = comment.replies[i];
          threadChildren.add(
            _CommentBubble(
              comment: reply,
              currentUserId: currentUserId,
              isReply: true,
              depth: depth + 1,
              isLastReply: i == comment.replies.length - 1,
              onLongPress: () => _showCommentActions(reply, currentUserId ?? ''),
              onMenuTap: () => _showCommentActions(reply, currentUserId ?? ''),
              onLike: () => _toggleLikeComment(reply),
              onReply: () => _startReply(reply.userName, reply.parentId ?? reply.id),
            ),
          );
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: depth > 0 ? (depth * 20.0).clamp(0.0, 60.0) : 0.0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: threadChildren,
      ),
    );
  }

  Widget _buildViewMoreRepliesBtn(Comment comment, int hiddenCount, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: 52 + (depth > 0 ? 8.0 : 0.0), top: 4, bottom: 4),
      child: GestureDetector(
        onTap: () {
          setState(() { _expandedComments.add(comment.id); });
          HapticFeedback.selectionClick();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.expand_more_rounded, size: 16, color: ThixPolicy.primary),
              const SizedBox(width: 6),
              Text(
                'Voir les $hiddenCount réponse${hiddenCount > 1 ? 's' : ''} précédente${hiddenCount > 1 ? 's' : ''}',
                style: ThixPolicy.labelStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                  color: ThixPolicy.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BARRE DE SAISIE ───
  Widget _buildInputBar() {
    final hasTextOrImage = _controller.text.trim().isNotEmpty || _imageBytes != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.tint,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: ThixPolicy.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'En réponse à $_replyingToName',
                        style: ThixPolicy.captionStyle.copyWith(
                          fontWeight: ThixPolicy.semiBold,
                          color: ThixPolicy.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _clearReply,
                      child: const Icon(Icons.close, size: 16, color: ThixPolicy.textSecondary),
                    ),
                  ],
                ),
              ),

            if (_imageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: Image.memory(_imageBytes!, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: ThixPolicy.danger),
                      onPressed: () => setState(() => _imageBytes = null),
                    ),
                  ],
                ),
              ),

            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                  border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: ThixPolicy.danger, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enregistrement... ${_recordDuration.toString().padLeft(2, '0')}s / ${_CommentValidators.maxAudioDurationSeconds}s',
                        style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                      ),
                    ),
                    GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                  ],
                ),
              )
            else if (_localAudioPath != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                ),
                child: Row(
                  children: [
                    Expanded(child: _CommentAudioPlayer(audioUrl: _localAudioPath!, isLocal: true)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                      onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; }),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))
                            : const Icon(Icons.send_rounded, color: ThixPolicy.primary, size: 14),
                        onPressed: _isSubmitting ? null : () => _submitComment(),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_rounded, color: ThixPolicy.textSecondary),
                        onPressed: _pickImage,
                      ),
                      IconButton(
                        icon: Icon(
                          _showStickers ? Icons.keyboard_rounded : Icons.emoji_emotions_rounded,
                          color: _showStickers ? ThixPolicy.primary : ThixPolicy.textSecondary,
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _showStickers = !_showStickers);
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: 4,
                          minLines: 1,
                          // ✅ Limite de caractères dynamique : 280 pour les comptes gratuits, 2000 sinon.
                          maxLength: _maxCommentLengthForUser,
                          onTap: () {
                            if (_showStickers) setState(() => _showStickers = false);
                          },
                          style: ThixPolicy.bodyStyle,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: _replyingTo != null ? 'Votre réponse...' : 'Votre commentaire...',
                            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: ThixPolicy.surfaceSoft,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_isSubmitting) return;
                          if (hasTextOrImage) {
                            _submitComment();
                          } else {
                            _startRecording();
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: hasTextOrImage
                                ? const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)])
                                : const LinearGradient(colors: [ThixPolicy.gold, Color(0xFFFFA500)]),
                            shape: BoxShape.circle,
                            boxShadow: ThixPolicy.shadowNode(color: hasTextOrImage ? ThixPolicy.primary : ThixPolicy.gold),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(
                                  hasTextOrImage ? Icons.send_rounded : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                  // ✅ Indication de la limite pour les comptes gratuits, discrète sous le champ.
                  if (_isFree)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_controller.text.length}/${_CommentValidators.maxCommentLengthFree}',
                          style: ThixPolicy.microStyle.copyWith(
                            color: _controller.text.length >= _CommentValidators.maxCommentLengthFree
                                ? ThixPolicy.danger
                                : ThixPolicy.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerPicker() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textSecondary,
              indicatorColor: ThixPolicy.primary,
              labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
              tabs: const [
                Tab(text: 'Émojis'),
                Tab(text: 'Réactions'),
                Tab(text: 'Drapeaux'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStickerGrid(_emojis),
                  _buildStickerGrid(_reactions),
                  _buildStickerGrid(_flags),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => _insertSticker(items[index]),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Center(
          child: Text(items[index], style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

// ============================================================================
// BULLE DE COMMENTAIRE AVEC MENU 3 POINTS
// ============================================================================
class _CommentBubble extends ConsumerWidget {
  final Comment comment;
  final String? currentUserId;
  final bool isReply;
  final int depth;
  final bool isLastReply;
  final VoidCallback onLongPress;
  final VoidCallback onMenuTap;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentBubble({
    Key? key,
    required this.comment,
    required this.currentUserId,
    required this.isReply,
    required this.depth,
    required this.isLastReply,
    required this.onLongPress,
    required this.onMenuTap,
    required this.onLike,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAudio = comment.audioUrl != null && comment.audioUrl!.isNotEmpty;
    final hasImage = comment.imageUrl != null && comment.imageUrl!.isNotEmpty;

    final authorProfile = ref.watch(userProfileProvider(comment.userId)).valueOrNull;
    CertificationTier? tier;
    CertificationStatus? status;
    bool isCertified = false;
    bool isLegacyVerified = false;

    if (authorProfile != null) {
      tier = CertificationTierX.parse(authorProfile['certification_tier']);
      status = CertificationStatusX.parse(authorProfile['certification_status']);
      isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
      isLegacyVerified = authorProfile['is_verified'] == true;
    }

    // Couleur de la barre latérale selon la profondeur
    final Color depthColor = depth == 0
        ? ThixPolicy.primary
        : depth == 1
            ? ThixPolicy.gold
            : depth == 2
                ? ThixPolicy.success
                : ThixPolicy.domainMedia;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            SizedBox(
              width: 40,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: isLastReply ? null : 0,
                    height: isLastReply ? 24 : null,
                    child: Container(width: 2, color: depthColor.withOpacity(0.3)),
                  ),
                  Positioned(
                    left: 20,
                    top: 24,
                    child: Container(width: 14, height: 2, color: depthColor.withOpacity(0.3)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isReply ? 0 : 12, right: 12, bottom: 4),
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
                    boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
                  ),
                  child: Stack(
                    children: [
                      // Barre latérale colorée pour la profondeur
                      Positioned(
                        left: 0,
                        top: 8,
                        bottom: 8,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: depthColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 4),
                            leading: CircleAvatar(
                              radius: isReply ? 14 : 16,
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty
                                  ? CachedNetworkImageProvider(comment.userAvatar!)
                                  : null,
                              child: comment.userAvatar == null || comment.userAvatar!.isEmpty
                                  ? Icon(Icons.person, size: isReply ? 14 : 16, color: ThixPolicy.textMuted)
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _CommentValidators.sanitize(comment.userName),
                                    style: ThixPolicy.labelStyle.copyWith(
                                      fontWeight: ThixPolicy.bold,
                                      color: ThixPolicy.textMain,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCertified)
                                  CertificationNameBadge(
                                    tier: tier,
                                    status: status,
                                    showLabel: false,
                                    iconSize: 13,
                                    padding: const EdgeInsets.only(left: 4),
                                  )
                                else if (isLegacyVerified)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 13),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  timeago.format(comment.createdAt, locale: 'fr'),
                                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: ThixPolicy.textSecondary),
                              onPressed: onMenuTap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          if (comment.content.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              child: Text(
                                _CommentValidators.sanitize(comment.content),
                                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4),
                              ),
                            ),
                          if (hasImage)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                child: CachedNetworkImage(
                                  imageUrl: comment.imageUrl!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    height: 160,
                                    color: ThixPolicy.surfaceSoft,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    height: 160,
                                    color: ThixPolicy.surfaceSoft,
                                    child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
                                  ),
                                ),
                              ),
                            ),
                          if (hasAudio)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
                              child: _CommentAudioPlayer(audioUrl: comment.audioUrl!, isLocal: false),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                _actionButton(
                                  icon: comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  iconColor: comment.isLiked ? ThixPolicy.danger : ThixPolicy.textSecondary,
                                  label: comment.likesCount > 0 ? '${comment.likesCount}' : '',
                                  onTap: onLike,
                                ),
                                const SizedBox(width: 8),
                                _actionButton(
                                  icon: Icons.reply_rounded,
                                  iconColor: ThixPolicy.textSecondary,
                                  label: 'Répondre',
                                  onTap: onReply,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: iconColor)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO DE COMMENTAIRE
// ============================================================================
class _CommentAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;

  const _CommentAudioPlayer({required this.audioUrl, this.isLocal = false});

  @override
  State<_CommentAudioPlayer> createState() => _CommentAudioPlayerState();
}

class _CommentAudioPlayerState extends State<_CommentAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<double> _wavePattern = [0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.3, 0.7, 0.8, 0.4, 0.6];

  @override
  void initState() {
    super.initState();
    if (widget.isLocal) {
      if (kIsWeb) {
        _audioPlayer.setSourceUrl(widget.audioUrl);
      } else {
        _audioPlayer.setSourceDeviceFile(widget.audioUrl);
      }
    } else {
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.resume();
              }
              HapticFeedback.selectionClick();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: ThixPolicy.inkDeep,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const barWidth = 3.0;
                const spacing = 2.0;
                final barCount = (constraints.maxWidth / (barWidth + spacing)).floor();

                return GestureDetector(
                  onTapDown: (details) {
                    if (_duration.inMilliseconds > 0) {
                      _audioPlayer.seek(Duration(
                        milliseconds: (_duration.inMilliseconds * (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)).round(),
                      ));
                    }
                  },
                  child: Container(
                    height: 24,
                    color: Colors.transparent,
                    child: Row(
                      children: List.generate(barCount, (index) {
                        final isPlayed = (index / barCount) <= progress;
                        return Container(
                          width: barWidth,
                          height: 24 * _wavePattern[index % _wavePattern.length],
                          margin: const EdgeInsets.only(right: spacing),
                          decoration: BoxDecoration(
                            color: isPlayed ? ThixPolicy.gold : Colors.white30,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position),
            style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
          ),
        ],
      ),
    );
  }
}
