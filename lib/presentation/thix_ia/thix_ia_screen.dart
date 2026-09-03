// lib/presentation/ai/thix_ia_screen.dart
//
// THIX IA — "Monochrome Glass" (Production Enterprise)
//
// ✅ Design 100% refait : 2 couleurs seulement (blanc + encre)
// ✅ Glassmorphism pur : surfaces blanches translucides sur fond encre
// ✅ Barre du bas SUPPRIMÉE : composer flottant intégré au flux
// ✅ Logique 100% préservée : AiService, Tavily, historique, retry, copie
// ✅ i18n + Semantics + throttling + mounted checks + logs structurés
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../services/ai/ai_service.dart';

// ============================================================================
// PALETTE MONOCHROME (2 couleurs : blanc + encre)
// ============================================================================

class _IaPalette {
  _IaPalette._();

  static const Color ink = Color(0xFF0B1220); // Encre profonde (fond)
  static const Color white = Color(0xFFFFFFFF);

  // Surfaces glass (blanc translucide)
  static Color get glassStrong => white.withValues(alpha: 0.14);
  static Color get glass => white.withValues(alpha: 0.08);
  static Color get glassSoft => white.withValues(alpha: 0.05);
  static Color get glassBorder => white.withValues(alpha: 0.16);
  static Color get glassBorderSoft => white.withValues(alpha: 0.10);

  // Texte (blanc + opacités)
  static Color get textPrimary => white;
  static Color get textSecondary => white.withValues(alpha: 0.62);
  static Color get textMuted => white.withValues(alpha: 0.40);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kSendThrottle = Duration(milliseconds: 500);
const Duration _kProfileTimeout = Duration(seconds: 8);
const int _kMaxMessageLength = 4000;
const double _kGlassBlur = kIsWeb ? 8 : 14;
const double _kOrbBlur = kIsWeb ? 40 : 70;

// ============================================================================
// LOGGING
// ============================================================================

class _IaLogger {
  static const _tag = 'ThixIA';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// GLASS SURFACE (réutilisable, monochrome)
// ============================================================================

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final bool bordered;

  const _Glass({
    required this.child,
    this.radius = 24,
    this.alpha = 0.08,
    this.blur = _kGlassBlur,
    this.padding,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _IaPalette.white.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: bordered
                ? Border.all(color: _IaPalette.glassBorderSoft, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE
// ============================================================================

class ThixIaScreen extends ConsumerStatefulWidget {
  const ThixIaScreen({super.key});

  @override
  ConsumerState<ThixIaScreen> createState() => _ThixIaScreenState();
}

class _ThixIaScreenState extends ConsumerState<ThixIaScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AiService _aiService;
  final AiProvider _selectedProvider = AiProvider.mistral;

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _useTavilyWebSearch = true;
  String _userName = "Partenaire";
  DateTime? _lastSendTime;

  // PROMPT ENTREPRISE (Focus RDC, OHADA, Afrique) — logique préservée
  final String _enterpriseSystemPrompt = """
Tu es THIX IA, un assistant exécutif et conseiller stratégique d'entreprise de haut niveau. 
Ton expertise principale couvre le marché de la République Démocratique du Congo (RDC), 
le droit OHADA, l'écosystème tech est-africain, et les réalités économiques du continent africain.
Tes réponses doivent être professionnelles, précises et directement applicables par un entrepreneur ou un décideur.
N'utilise JAMAIS d'astérisques (*) dans tes réponses. Utilise des tirets (-), des numéros (1, 2, 3) et des sauts de ligne pour structurer les longs textes.
""";

  @override
  void initState() {
    super.initState();
    _aiService = AiService(Supabase.instance.client);
    _loadUserName();
    _IaLogger.info('Screen initialized');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _IaLogger.info('Screen disposed');
    super.dispose();
  }

  bool _canSend() {
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!) < _kSendThrottle) {
      _IaLogger.warn('Send throttled');
      return false;
    }
    _lastSendTime = now;
    return true;
  }

  Future<void> _loadUserName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, display_name')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_kProfileTimeout, onTimeout: () => null);
      if (profile != null && mounted) {
        setState(() {
          _userName =
              profile['display_name'] ?? profile['full_name'] ?? "Partenaire";
          _userName = _userName.split(' ').first;
        });
      }
    } catch (e) {
      _IaLogger.warn('Load user name failed', {'error': '$e'});
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // ENVOI (logique préservée)
  // ════════════════════════════════════════════════════════════════════

  Future<void> _sendMessage({String? textOverride}) async {
    if (!_canSend()) return;

    final text = textOverride ?? _messageController.text.trim();
    if (text.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    if (text.length > _kMaxMessageLength) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('ai_message_too_long',
            args: {'max': '$_kMaxMessageLength'})),
        backgroundColor: _IaPalette.white,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': DateTime.now()});
      _isLoading = true;
    });

    _messageController.clear();
    _messageFocusNode.unfocus();
    _scrollToBottom();

    try {
      final currentPrompt = _useTavilyWebSearch
          ? "$_enterpriseSystemPrompt\nIMPORTANT : Effectue une recherche web (Live Search) pour obtenir des données d'actualité en temps réel avant de formuler ta réponse."
          : _enterpriseSystemPrompt;

      final response = await _aiService.askAi(
        prompt: text,
        provider: _selectedProvider,
        systemPrompt: currentPrompt,
      );

      final cleanResponse = response.replaceAll('*', '');

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': cleanResponse,
            'time': DateTime.now(),
            'usedWeb': _useTavilyWebSearch,
          });
        });
        _IaLogger.info('AI response received',
            {'length': cleanResponse.length, 'usedWeb': _useTavilyWebSearch});
      }
    } catch (e) {
      _IaLogger.error('AI request failed', {'error': '$e'});
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text':
                'Erreur de connexion sécurisée au serveur THIX. Veuillez vérifier votre connexion.',
            'isError': true,
            'time': DateTime.now(),
          });
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _confirmNewSession(AppLocalizations l10n) async {
    if (_messages.isEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _messages.clear());
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _Glass(
        radius: 24,
        alpha: 0.12,
        child: AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(l10n.t('ai_confirm_new_title'),
              style: const TextStyle(
                  color: _IaPalette.textPrimary,
                  fontWeight: FontWeight.w800)),
          content: Text(l10n.t('ai_confirm_new_message'),
              style: const TextStyle(color: _IaPalette.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'),
                  style: const TextStyle(color: _IaPalette.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('ai_confirm_new_confirm'),
                  style: const TextStyle(color: _IaPalette.textPrimary)),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _messages.clear());
      _IaLogger.info('New session started');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _IaPalette.ink,
      drawer: _buildHistoryDrawer(l10n),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
            child: Container(
              color: _IaPalette.ink.withValues(alpha: 0.55),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _IaPalette.glassBorderSoft),
                ),
              ),
            ),
          ),
        ),
        leading: Semantics(
          button: true,
          label: l10n.t('common_menu'),
          child: IconButton(
            icon: const Icon(Icons.menu_open_rounded,
                color: _IaPalette.textPrimary),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.graphic_eq_rounded,
                    color: _IaPalette.textPrimary, size: 18),
                SizedBox(width: 8),
                Text('THIX IA',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _IaPalette.textPrimary,
                        fontSize: 16,
                        letterSpacing: -0.5)),
              ],
            ),
            Text(l10n.t('ai_expertise_subtitle'),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _IaPalette.textSecondary)),
          ],
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('ai_new_session'),
            child: IconButton(
              icon: const Icon(Icons.add_box_rounded,
                  color: _IaPalette.textPrimary),
              tooltip: l10n.t('ai_new_session'),
              onPressed: () => _confirmNewSession(l10n),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Orbes monochromes (blanc sur encre)
          Positioned(
              top: -60,
              right: -110,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.10), 340)),
          Positioned(
              bottom: 180,
              left: -120,
              child: _buildOrb(_IaPalette.white.withValues(alpha: 0.07), 300)),

          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildWelcome(l10n)
                    : _buildChatList(l10n),
              ),

              if (_isLoading)
                RepaintBoundary(child: _buildTypingIndicator(l10n)),

              // ✅ COMPOSER FLOTTANT (pas une barre) — intégré au flux
              _buildFloatingComposer(l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _kOrbBlur, sigmaY: _kOrbBlur),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DRAWER HISTORIQUE (glass monochrome)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildHistoryDrawer(AppLocalizations l10n) {
    return Drawer(
      backgroundColor: _IaPalette.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: const [
                  Icon(Icons.history_rounded, color: _IaPalette.textPrimary),
                  SizedBox(width: 12),
                  Text('Historique',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _IaPalette.textPrimary)),
                ],
              ),
            ),
            Divider(height: 1, color: _IaPalette.glassBorderSoft),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _historyItem(l10n.t('ai_history_now'),
                      l10n.t('ai_history_current'), true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(String date, String title, bool isActive) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(Icons.chat_bubble_outline_rounded,
          size: 18,
          color: isActive ? _IaPalette.textPrimary : _IaPalette.textSecondary),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color:
                  isActive ? _IaPalette.textPrimary : _IaPalette.textSecondary)),
      subtitle:
          Text(date, style: const TextStyle(fontSize: 11, color: _IaPalette.textMuted)),
      tileColor: isActive ? _IaPalette.glass : Colors.transparent,
      onTap: () => Navigator.pop(context),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // ACCUEIL (glass monochrome)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildWelcome(AppLocalizations l10n) {
    final actions = [
      {
        "icon": Icons.gavel_rounded,
        "title": l10n.t('ai_action_ohada'),
        "desc": l10n.t('ai_action_ohada_prompt'),
      },
      {
        "icon": Icons.trending_up_rounded,
        "title": l10n.t('ai_action_market'),
        "desc": l10n.t('ai_action_market_prompt'),
      },
      {
        "icon": Icons.language_rounded,
        "title": l10n.t('ai_action_tech'),
        "desc": l10n.t('ai_action_tech_prompt'),
      },
      {
        "icon": Icons.lightbulb_outline_rounded,
        "title": l10n.t('ai_action_strategy'),
        "desc": l10n.t('ai_action_strategy_prompt'),
      },
    ];

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, MediaQuery.paddingOf(context).top + 70, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Glass(
              radius: 60,
              alpha: 0.12,
              padding: const EdgeInsets.all(22),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: _IaPalette.textPrimary, size: 40),
            ),
            const SizedBox(height: 24),
            Text('${l10n.t('ai_greeting')}, $_userName.',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _IaPalette.textPrimary,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(l10n.t('ai_welcome_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: _IaPalette.textSecondary,
                    height: 1.4)),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: actions.length,
              itemBuilder: (ctx, i) {
                final a = actions[i];
                return Semantics(
                  button: true,
                  label: a["title"] as String,
                  child: _Glass(
                    radius: 20,
                    alpha: 0.08,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () =>
                            _sendMessage(textOverride: a["desc"] as String),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(a["icon"] as IconData,
                                  color: _IaPalette.textPrimary, size: 20),
                              const SizedBox(height: 8),
                              Text(a["title"] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _IaPalette.textPrimary)),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(a["desc"] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _IaPalette.textSecondary,
                                        height: 1.3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LISTE DES MESSAGES (bulles monochromes)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildChatList(AppLocalizations l10n) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top + 70, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final isError = msg['isError'] == true;
        final usedWeb = msg['usedWeb'] == true;

        if (isUser) {
          // Bulle utilisateur : blanc plein, texte encre
          return Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _IaPalette.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SelectableText(msg['text']!,
                    style: const TextStyle(
                        color: _IaPalette.ink,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          );
        }

        // Bulle IA : glass blanc, texte blanc
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.92),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 10, top: 4),
                    decoration: BoxDecoration(
                      color: isError
                          ? _IaPalette.white.withValues(alpha: 0.25)
                          : _IaPalette.glass,
                      shape: BoxShape.circle,
                      border: Border.all(color: _IaPalette.glassBorder),
                    ),
                    child: Icon(
                        isError ? Icons.error_outline : Icons.graphic_eq_rounded,
                        color: _IaPalette.textPrimary,
                        size: 14),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(isError ? l10n.t('ai_error_label') : "THIX IA",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: _IaPalette.textPrimary)),
                            if (usedWeb) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _IaPalette.glass,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _IaPalette.glassBorderSoft),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.travel_explore_rounded,
                                        size: 10,
                                        color: _IaPalette.textSecondary),
                                    SizedBox(width: 4),
                                    Text("Tavily Live",
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: _IaPalette.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _Glass(
                          radius: 20,
                          alpha: isError ? 0.20 : 0.08,
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(msg['text']!,
                              style: TextStyle(
                                  color: isError
                                      ? _IaPalette.textPrimary
                                      : _IaPalette.textPrimary,
                                  fontSize: 14,
                                  height: 1.6)),
                        ),
                        const SizedBox(height: 4),
                        if (!isError)
                          Row(
                            children: [
                              Semantics(
                                button: true,
                                label: l10n.t('ai_action_copy'),
                                child: _bubbleAction(
                                  Icons.copy_rounded,
                                  l10n.t('ai_action_copy'),
                                  () {
                                    HapticFeedback.selectionClick();
                                    Clipboard.setData(
                                        ClipboardData(text: msg['text']));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content:
                                          Text(l10n.t('ai_copied_success')),
                                      backgroundColor: _IaPalette.white,
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  },
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: l10n.t('ai_action_retry'),
                                child: _bubbleAction(
                                  Icons.refresh_rounded,
                                  l10n.t('ai_action_retry'),
                                  () {
                                    final userIndex = _messages.lastIndexWhere(
                                        (m) =>
                                            m['role'] == 'user' &&
                                            _messages.indexOf(m) < index);
                                    if (userIndex >= 0) {
                                      setState(
                                          () => _messages.removeAt(index));
                                      _sendMessage(textOverride:
                                          _messages[userIndex]['text']);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bubbleAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 12, color: _IaPalette.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _IaPalette.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 12),
      child: Row(
        children: const [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _IaPalette.textPrimary)),
          SizedBox(width: 12),
          Text("Génération de l'analyse...",
              style: TextStyle(
                  color: _IaPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // COMPOSER FLOTTANT (barre du bas SUPPRIMÉE)
  // ════════════════════════════════════════════════════════════════════

  Widget _buildFloatingComposer(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, MediaQuery.paddingOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chip Tavily (flottant, pas une barre)
          Semantics(
            button: true,
            toggled: _useTavilyWebSearch,
            label: l10n.t('ai_tavily_toggle'),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _useTavilyWebSearch = !_useTavilyWebSearch);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8, left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _useTavilyWebSearch
                      ? _IaPalette.white
                      : _IaPalette.glassSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _useTavilyWebSearch
                          ? _IaPalette.white
                          : _IaPalette.glassBorderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded,
                        size: 13,
                        color: _useTavilyWebSearch
                            ? _IaPalette.ink
                            : _IaPalette.textSecondary),
                    const SizedBox(width: 6),
                    Text(l10n.t('ai_tavily_label'),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _useTavilyWebSearch
                                ? _IaPalette.ink
                                : _IaPalette.textSecondary)),
                  ],
                ),
              ),
            ),
          ),

          // Pilule de saisie flottante (glass)
          _Glass(
            radius: 28,
            alpha: 0.10,
            blur: _kGlassBlur,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: Scrollbar(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        maxLines: 5,
                        minLines: 1,
                        maxLength: _kMaxMessageLength,
                        style: const TextStyle(
                            fontSize: 14, color: _IaPalette.textPrimary),
                        textCapitalization: TextCapitalization.sentences,
                        cursorColor: _IaPalette.white,
                        decoration: InputDecoration(
                          hintText: l10n.t('ai_input_hint'),
                          counterText: '',
                          hintStyle: const TextStyle(
                              color: _IaPalette.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    button: true,
                    label: l10n.t('ai_send'),
                    child: GestureDetector(
                      onTap: _isLoading ? null : () => _sendMessage(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isLoading
                              ? _IaPalette.white.withValues(alpha: 0.25)
                              : _IaPalette.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_upward_rounded,
                            color: _IaPalette.ink, size: 18),
                      ),
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
}
