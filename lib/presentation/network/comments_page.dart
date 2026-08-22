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

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/models/comment.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/comments_provider.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

// ✅ CERTIFICATION & SYNCHRO PROFIL
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE BLANC ÉPURÉ (Mise à jour)
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Colors.white;
  static const bubbleBg = Color(0xFFF8FAFC); 
  static const primary = Color(0xFF2D6CDF);
  static const navyText = Color(0xFF0A1F44);
  static const border = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF8A94A6);
  static const red = Color(0xFFFF6B6B);
  static const gold = Color(0xFFE3B23C);
}

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

  // ─── MÉDIAS (Audio & Photo) ───
  Uint8List? _imageBytes;
  Uint8List? _audioBytes;
  String? _localAudioPath;
  
  // ─── AUDIO RECORDING (Limite : 30 sec) ───
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;

  bool _showStickers = false;

  // ─── LOGIQUE DES LIMITES ET SÉCURITÉ ───
  bool _isLoadingLimits = true;
  String _userTier = 'gratuit'; 
  bool get _isFree => _userTier == 'gratuit' || _userTier == 'none';

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
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (_isFree && text.length > 280) {
      _controller.text = text.substring(0, 280);
      _controller.selection = TextSelection.collapsed(offset: 280);
      HapticFeedback.lightImpact();
    }
    setState(() {});
  }

  Future<void> _loadPost() async {
    try {
      final p = await ref.read(networkServiceProvider).getPostById(widget.postId);
      if (mounted) setState(() { _post = p; _isLoadingPost = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPost = false);
    }
  }

  // ─── DIALOGUES DE SÉCURITÉ ET D'ABONNEMENT ───
  void _showUpgradeDialog(String featureName, String requiredTier) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: _C.gold, size: 28),
            const SizedBox(width: 8),
            const Text('Fonctionnalité bloquée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.navyText)),
          ],
        ),
        content: Text(
          "$featureName est réservée aux comptes $requiredTier et supérieurs.\n\nMettez à niveau votre compte pour débloquer de nouveaux outils et retirer la limite de 280 caractères.",
          style: const TextStyle(fontSize: 14, color: _C.navyText, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard', style: TextStyle(color: _C.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: const Text('Voir les offres', style: TextStyle(color: _C.navyText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (!mounted) return false;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: _C.navyText, size: 28),
            SizedBox(width: 10),
            Text("Autorisation requise", style: TextStyle(color: _C.navyText, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          explanation,
          style: const TextStyle(color: _C.navyText, fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: _C.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Compris", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (userAgreed != true) return false;
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  // ─── LOGIQUE AUDIO (Bloqué pour Gratuit, Limite 30s) ───
  Future<void> _startRecording() async {
    if (_isFree) {
      _showUpgradeDialog('Les commentaires vocaux', 'Standard');
      return;
    }

    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.microphone,
      "Pour vous permettre d'enregistrer et de poster une note vocale dans les commentaires, THIX ID a besoin d'accéder à votre microphone."
    );
    if (!hasPerm) return;

    try {
      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = p.join(dir.path, 'comment_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: path,
      );

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
        if (_recordDuration >= 30) {
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Durée maximale atteinte (30s)')));
        }
      });
    } catch (e) {
      debugPrint('Erreur record: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du démarrage du micro')));
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
      debugPrint('Erreur stop record: $e');
    }
  }

  // ─── LOGIQUE PHOTO ───
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        _showStickers = false;
      });
    }
  }

  // ─── SOUMISSION DÉFINITIVE ───
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

      String finalContent = text;
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: _C.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearReply() => setState(() { _replyingTo = null; _replyingToName = null; });

  void _startReply(String userName, String commentId) {
    setState(() { _replyingTo = commentId; _replyingToName = userName; });
    _focusNode.requestFocus();
  }

  Future<void> _toggleLikeComment(Comment comment) async {
    final oldLiked = comment.isLiked;
    final oldCount = comment.likesCount;
    setState(() { comment.isLiked = !oldLiked; comment.likesCount = oldLiked ? oldCount - 1 : oldCount + 1; });
    try {
      if (comment.isLiked) await ref.read(networkServiceProvider).likeComment(comment.id);
      else await ref.read(networkServiceProvider).unlikeComment(comment.id);
    } catch (_) {
      setState(() { comment.isLiked = oldLiked; comment.likesCount = oldCount; });
    }
  }

  void _showCommentActions(Comment comment, String currentUserId) {
    FocusScope.of(context).unfocus();
    final isOwnComment = comment.userId == currentUserId;
    final isPostOwner = _post?.userId == currentUserId;
    final canDelete = isOwnComment || isPostOwner;

    showModalBottomSheet(
      context: context,
      backgroundColor: _C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2))),
              
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: _C.navyText),
                title: const Text('Répondre', style: TextStyle(color: _C.navyText)),
                onTap: () { Navigator.pop(context); _startReply(comment.userName, comment.parentId ?? comment.id); },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: _C.navyText),
                title: const Text('Copier le texte', style: TextStyle(color: _C.navyText)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: comment.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texte copié !')));
                },
              ),
              
              if (isOwnComment && (comment.audioUrl == null || comment.audioUrl!.isEmpty))
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: _C.navyText),
                  title: const Text('Modifier', style: TextStyle(color: _C.navyText)),
                  onTap: () { Navigator.pop(context); _editComment(comment); },
                ),
                
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: _C.red),
                  title: const Text('Supprimer', style: TextStyle(color: _C.red, fontWeight: FontWeight.bold)),
                  onTap: () { Navigator.pop(context); _confirmDelete(comment); },
                ),

              if (!isOwnComment)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                  title: const Text('Signaler ce commentaire', style: TextStyle(color: Colors.orange)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé aux modérateurs.')));
                  },
                ),
            ],
          ),
        );
      }
    );
  }

  void _editComment(Comment comment) async {
    final ctrl = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: _C.bg,
        title: const Text('Modifier le commentaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.navyText)), 
        content: TextField(
          controller: ctrl, maxLines: 4, 
          style: const TextStyle(color: _C.navyText),
          decoration: InputDecoration(
            filled: true, 
            fillColor: _C.bubbleBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          )
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler', style: TextStyle(color: _C.textMuted))), 
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text), style: ElevatedButton.styleFrom(backgroundColor: _C.navyText), child: const Text('Enregistrer', style: TextStyle(color: Colors.white)))
        ]
      )
    );

    if (newContent != null && newContent.trim().isNotEmpty && newContent != comment.content) {
      try { 
        await Supabase.instance.client.from('comments').update({'content': newContent}).eq('id', comment.id);
        ref.invalidate(commentsProvider(widget.postId));
      } catch (e) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'))); 
      }
    }
  }

  void _confirmDelete(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        title: const Text('Supprimer ?', style: TextStyle(color: _C.red)),
        content: const Text('Ce commentaire sera définitivement supprimé.', style: TextStyle(color: _C.navyText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _C.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _C.red), child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
        ],
      )
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('comments').delete().eq('id', comment.id);
        ref.invalidate(commentsProvider(widget.postId));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? widget.currentProfileId;

    return Scaffold(
      backgroundColor: _C.bg, // 🌟 Mode Blanc Épuré
      appBar: AppBar(
        title: const Text('Commentaires', style: TextStyle(color: _C.navyText, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.navyText),
        actions: [IconButton(onPressed: () => ref.invalidate(commentsProvider(widget.postId)), icon: const Icon(Icons.refresh_rounded, color: _C.textMuted))],
      ),
      body: _isLoadingPost && _post == null
         ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: _C.primary,
                    backgroundColor: Colors.white,
                    onRefresh: () async { await _loadPost(); ref.invalidate(commentsProvider(widget.postId)); },
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (_post != null)
                          SliverToBoxAdapter(
                            child: PostCard(
                              post: _post!, 
                              currentProfileId: widget.currentProfileId, 
                              onTap: () {}, 
                              onRefresh: _loadPost
                            )
                          ),
                        commentsAsync.when(
                          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _C.primary)))),
                          error: (e, _) => SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Erreur: $e', style: const TextStyle(color: _C.textMuted))))),
                          data: (comments) => comments.isEmpty
                             ? SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.comment_outlined, size: 60, color: _C.border), const SizedBox(height: 12), Text('Soyez le premier à commenter !', style: TextStyle(color: _C.textMuted))])))
                              : SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildCommentThread(comments[index], currentUserId), childCount: comments.length)),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildInputBar(),
                if (_showStickers) _buildStickerPicker(),
              ]
            ),
    );
  }

  // ─── THREAD STYLE FACEBOOK (Imbrication / Nesting optimisé) ───
  Widget _buildCommentThread(Comment comment, String? currentUserId) {
    final hasReplies = comment.replies.isNotEmpty;
    final isExpanded = _expandedComments.contains(comment.id);
    final hiddenCount = comment.replies.length - 1; 

    List<Widget> threadChildren = [
      _CommentBubble(
        comment: comment,
        currentUserId: currentUserId,
        isReply: false,
        isLastReply: !hasReplies,
        onLongPress: () => _showCommentActions(comment, currentUserId ?? ''),
        onLike: () => _toggleLikeComment(comment),
        onReply: () => _startReply(comment.userName, comment.id),
      ),
    ];

    if (hasReplies) {
      if (!isExpanded && comment.replies.length > 1) {
        threadChildren.add(_buildViewMoreRepliesBtn(comment, hiddenCount));
        final lastReply = comment.replies.last;
        threadChildren.add(
          _CommentBubble(
            comment: lastReply,
            currentUserId: currentUserId,
            isReply: true,
            isLastReply: true,
            onLongPress: () => _showCommentActions(lastReply, currentUserId ?? ''),
            onLike: () => _toggleLikeComment(lastReply),
            onReply: () => _startReply(lastReply.userName, lastReply.parentId ?? lastReply.id),
          )
        );
      } else {
        for (int i = 0; i < comment.replies.length; i++) {
          final reply = comment.replies[i];
          threadChildren.add(
            _CommentBubble(
              comment: reply,
              currentUserId: currentUserId,
              isReply: true,
              isLastReply: i == comment.replies.length - 1,
              onLongPress: () => _showCommentActions(reply, currentUserId ?? ''),
              onLike: () => _toggleLikeComment(reply),
              onReply: () => _startReply(reply.userName, reply.parentId ?? reply.id),
            )
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: threadChildren,
      ),
    );
  }

  Widget _buildViewMoreRepliesBtn(Comment comment, int hiddenCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          height: 36,
          child: Stack(
            children: [
              Positioned(left: 28, top: 0, bottom: 0, child: Container(width: 2, color: _C.border)),
              Positioned(left: 28, top: 18, child: Container(width: 14, height: 2, color: _C.border)),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() { _expandedComments.add(comment.id); });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Voir les $hiddenCount réponses précédentes', 
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _C.navyText)
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── BARRE DE SAISIE SÉCURISÉE (Blanc Épuré) ───
  Widget _buildInputBar() {
    final hasTextOrImage = _controller.text.trim().isNotEmpty || _imageBytes != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8), 
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(color: _C.bubbleBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)), 
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: _C.navyText), 
                    const SizedBox(width: 6), 
                    Text('En réponse à $_replyingToName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.navyText)), 
                    const Spacer(), 
                    InkWell(onTap: _clearReply, child: const Icon(Icons.close, size: 16, color: _C.navyText))
                  ]
                )
              ),
              
            if (_imageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_imageBytes!, width: 50, height: 50, fit: BoxFit.cover)),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.cancel, color: _C.red), onPressed: () => setState(() => _imageBytes = null))
                  ],
                ),
              ),

            if (_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _C.red.withOpacity(0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: _C.red.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: _C.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Enregistrement... 00:${_recordDuration.toString().padLeft(2, '0')} / 00:30', style: const TextStyle(color: _C.red, fontWeight: FontWeight.w800)),
                    ),
                    GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: _C.red, size: 30)),
                  ],
                ),
              )
            else if (_localAudioPath != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: _C.navyText, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    Expanded(child: _CommentAudioPlayer(audioUrl: _localAudioPath!, isLocal: true)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70), onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; })),
                    CircleAvatar(
                      radius: 16, backgroundColor: _C.primary, 
                      child: IconButton(icon: _isSubmitting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 14), onPressed: _isSubmitting ? null : () => _submitComment())
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
                      IconButton(icon: const Icon(Icons.camera_alt_rounded, color: _C.textMuted), onPressed: _pickImage),
                      IconButton(
                        icon: Icon(_showStickers ? Icons.keyboard_rounded : Icons.emoji_emotions_rounded, color: _showStickers ? _C.primary : _C.textMuted),
                        onPressed: () { FocusScope.of(context).unfocus(); setState(() => _showStickers = !_showStickers); },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller, focusNode: _focusNode, maxLines: 4, minLines: 1,
                          maxLength: _isFree ? 280 : null, // 🌟 Limite appliquée nativement
                          onTap: () { if (_showStickers) setState(() => _showStickers = false); },
                          style: const TextStyle(color: _C.navyText, fontSize: 14),
                          decoration: InputDecoration(
                            counterText: "", 
                            hintText: _replyingTo != null ? 'Votre réponse...' : 'Votre commentaire...', 
                            hintStyle: const TextStyle(color: _C.textMuted),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), 
                            filled: true, 
                            fillColor: _C.bubbleBg, 
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                          )
                        )
                      ),
                      const SizedBox(width: 8),
                      
                      GestureDetector(
                        onTap: () {
                          if (_isSubmitting) return;
                          if (hasTextOrImage) _submitComment();
                          else _startRecording(); // 🌟 Vérifie nativement _isFree et bloque le vocal
                        },
                        child: CircleAvatar(
                          radius: 20, backgroundColor: hasTextOrImage ? _C.primary : _C.gold, 
                          child: _isSubmitting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : Icon(hasTextOrImage ? Icons.send_rounded : Icons.mic_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ]
                  ),
                  // 🌟 Affichage du compteur personnalisé pour les comptes gratuits
                  if (_isFree && _controller.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 55, top: 4),
                      child: Text(
                        '${_controller.text.length} / 280',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _controller.text.length >= 280 ? _C.red : _C.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
          ]
        ),
      ),
    );
  }

  Widget _buildStickerPicker() {
    return SizedBox(
      height: 250,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(labelColor: _C.primary, unselectedLabelColor: _C.textMuted, indicatorColor: _C.primary, tabs: [Tab(text: 'Émojis'), Tab(text: 'Réactions'), Tab(text: 'Drapeaux')]),
            Expanded(child: TabBarView(children: [_buildStickerGrid(_emojis), _buildStickerGrid(_reactions), _buildStickerGrid(_flags)]))
          ]
        )
      )
    );
  }

  Widget _buildStickerGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: items.length, itemBuilder: (context, index) => InkWell(onTap: () => _insertSticker(items[index]), child: Center(child: Text(items[index], style: const TextStyle(fontSize: 24)))),
    );
  }
}

class _CommentBubble extends ConsumerWidget {
  final Comment comment;
  final String? currentUserId;
  final bool isReply;
  final bool isLastReply;
  final VoidCallback onLongPress;
  final VoidCallback onLike;
  final VoidCallback onReply;

  const _CommentBubble({
    Key? key,
    required this.comment,
    required this.currentUserId,
    required this.isReply,
    required this.isLastReply,
    required this.onLongPress,
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            SizedBox(
              width: 52,
              child: Stack(
                children: [
                  Positioned(left: 28, top: 0, bottom: isLastReply ? null : 0, height: isLastReply ? 24 : null, child: Container(width: 2, color: _C.border)),
                  Positioned(left: 28, top: 24, child: Container(width: 14, height: 2, color: _C.border)),
                ],
              ),
            ),
            
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isReply ? 0 : 16, right: 16, bottom: 8),
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.bubbleBg, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: _C.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                        leading: CircleAvatar(
                          radius: isReply ? 14 : 16, 
                          backgroundColor: Colors.white,
                          backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty ? NetworkImage(comment.userAvatar!) : null, 
                          child: comment.userAvatar == null || comment.userAvatar!.isEmpty ? Icon(Icons.person, size: isReply ? 14 : 16, color: _C.textMuted) : null
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                comment.userName, 
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _C.navyText), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis
                              )
                            ), 
                            if (isCertified)
                              CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 13, padding: const EdgeInsets.only(left: 4))
                            else if (isLegacyVerified)
                              const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: _C.gold, size: 13)),
                            const SizedBox(width: 6),
                            Text(timeago.format(comment.createdAt, locale: 'fr'), style: const TextStyle(color: _C.textMuted, fontSize: 10))
                          ]
                        ),
                      ),
                      
                      if (comment.content.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), 
                          child: Text(comment.content, style: const TextStyle(fontSize: 13.5, height: 1.4, color: _C.navyText))
                        ),

                      if (hasImage)
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
                          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(comment.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover)),
                        ),
                        
                      if (hasAudio)
                        Padding(
                          padding: const EdgeInsets.only(left: 14, right: 14, top: 8),
                          child: _CommentAudioPlayer(audioUrl: comment.audioUrl!, isLocal: false), 
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        child: Row(
                          children: [
                            _actionButton(
                              icon: comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                              iconColor: comment.isLiked ? _C.red : _C.textMuted, 
                              label: comment.likesCount > 0 ? '${comment.likesCount}' : '', 
                              onTap: onLike
                            ),
                            const SizedBox(width: 8),
                            _actionButton(
                              icon: Icons.reply_rounded, 
                              iconColor: _C.textMuted, 
                              label: 'Répondre', 
                              onTap: onReply
                            ),
                          ]
                        )
                      ),
                    ]
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
      borderRadius: BorderRadius.circular(20), 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), 
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Icon(icon, size: 16, color: iconColor), 
            if (label.isNotEmpty)...[const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textMuted))]
          ]
        )
      )
    );
  }
}

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
      if (kIsWeb) _audioPlayer.setSourceUrl(widget.audioUrl);
      else _audioPlayer.setSourceDeviceFile(widget.audioUrl);
    } else {
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }

    _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
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
      decoration: BoxDecoration(color: _C.navyText, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.resume(); },
            child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: _C.gold, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _C.navyText, size: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const barWidth = 3.0; const spacing = 2.0;
                final barCount = (constraints.maxWidth / (barWidth + spacing)).floor();

                return GestureDetector(
                  onTapDown: (details) { if (_duration.inMilliseconds > 0) _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)).round())); },
                  child: Container(
                    height: 24, color: Colors.transparent,
                    child: Row(
                      children: List.generate(barCount, (index) {
                        final isPlayed = (index / barCount) <= progress;
                        return Container(width: barWidth, height: 24 * _wavePattern[index % _wavePattern.length], margin: const EdgeInsets.only(right: spacing), decoration: BoxDecoration(color: isPlayed ? _C.gold : Colors.white30, borderRadius: BorderRadius.circular(2)));
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
