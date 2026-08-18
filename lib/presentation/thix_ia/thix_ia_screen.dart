// lib/presentation/ai/thix_ia_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

// 🌟 Ton vrai service IA
import '../../services/ai/ai_service.dart'; 

class ThixIaScreen extends ConsumerStatefulWidget {
  const ThixIaScreen({super.key});

  @override
  ConsumerState<ThixIaScreen> createState() => _ThixIaScreenState();
}

class _ThixIaScreenState extends ConsumerState<ThixIaScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 🌟 Vrai service activé
  late final AiService _aiService;
  final AiProvider _selectedProvider = AiProvider.mistral; 
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _useTavilyWebSearch = true; 
  
  String _userName = "Partenaire";

  // 🌟 PROMPT ENTREPRISE (Focus RDC, OHADA, Afrique)
  // L'instruction demande explicitement d'éviter les astérisques pour un rendu propre
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
  }

  Future<void> _loadUserName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, display_name')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _userName = profile['display_name'] ?? profile['full_name'] ?? "Partenaire";
            _userName = _userName.split(' ').first; 
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🌟 VRAIE FONCTION D'ENVOI (Sans Mocks)
  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'time': DateTime.now()});
      _isLoading = true;
    });
    
    _messageController.clear();
    _scrollToBottom();

    try {
      // Injection de la consigne de recherche Live si activée
      final String currentPrompt = _useTavilyWebSearch
          ? "$_enterpriseSystemPrompt\nIMPORTANT : Effectue une recherche web (Live Search) pour obtenir des données d'actualité en temps réel avant de formuler ta réponse."
          : _enterpriseSystemPrompt;

      // 🌟 Appel réel à ton backend (Mistral / Tavily)
      final response = await _aiService.askAi(
        prompt: text,
        provider: _selectedProvider,
        systemPrompt: currentPrompt,
      );

      // Nettoyage de sécurité au cas où l'IA mettrait quand même des astérisques
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
      }
    } catch (e) {
      debugPrint("Erreur THIX IA: $e");
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai', 
            'text': 'Erreur de connexion sécurisée au serveur THIX. Veuillez vérifier votre connexion.',
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ThixPolicy.surfaceSoft,
      drawer: _buildHistoryDrawer(),
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_open_rounded, color: ThixPolicy.textMain),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.graphic_eq_rounded, color: ThixPolicy.primary, size: 18),
                SizedBox(width: 8),
                Text('THIX IA', style: TextStyle(fontWeight: FontWeight.w900, color: ThixPolicy.textMain, fontSize: 16, letterSpacing: -0.5)),
              ],
            ),
            Text('Expertise RDC & Afrique', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: ThixPolicy.primary),
            tooltip: 'Nouvelle session',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _messages.clear());
            },
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: ThixPolicy.border, height: 1)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
                ? _buildEnterpriseWelcome()
                : _buildChatList(),
          ),
          
          if (_isLoading) _buildTypingIndicator(),

          _buildPremiumInputArea(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DRAWER HISTORIQUE (Prêt à être connecté à Supabase)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: ThixPolicy.surfaceSoft,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: ThixPolicy.textMain),
                  const SizedBox(width: ThixPolicy.s12),
                  const Text('Historique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                ],
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12),
                children: [
                  _historyItem('Session Actuelle', 'Discussion en cours', true),
                  // Ici, tu pourras faire un .map() sur tes données Supabase thix_ia_sessions
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
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      leading: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isActive ? ThixPolicy.primary : ThixPolicy.textSecondary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, color: isActive ? ThixPolicy.primaryDeep : ThixPolicy.textMain)),
      subtitle: Text(date, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
      tileColor: isActive ? ThixPolicy.tint : Colors.transparent,
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ÉCRAN D'ACCUEIL EXPERT RDC/AFRIQUE
  // ─────────────────────────────────────────────────────────────
  Widget _buildEnterpriseWelcome() {
    final actions = [
      {"icon": Icons.gavel_rounded, "title": "Droit OHADA", "desc": "Quels sont les avantages de créer une SAS en RDC selon le droit OHADA ?"},
      {"icon": Icons.trending_up_rounded, "title": "Marché RDC", "desc": "Donne-moi une analyse sectorielle des opportunités Tech à Kinshasa en 2026."},
      {"icon": Icons.language_rounded, "title": "Tech Afrique", "desc": "Quelles sont les grandes tendances de la Fintech en Afrique de l'Est cette année ?"},
      {"icon": Icons.lightbulb_outline_rounded, "title": "Stratégie", "desc": "Comment structurer un Business Plan pour lever des fonds auprès d'investisseurs africains ?"},
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, boxShadow: ThixPolicy.shadowSoft(), border: Border.all(color: ThixPolicy.tint, width: 4)),
              child: const Icon(Icons.graphic_eq_rounded, color: ThixPolicy.primaryDeep, size: 40),
            ),
            const SizedBox(height: ThixPolicy.s24),
            Text('Bonjour, $_userName.', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
            const SizedBox(height: ThixPolicy.s8),
            const Text('Votre conseiller stratégique est prêt.\nComment puis-je vous assister aujourd\'hui ?', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: ThixPolicy.textSecondary, height: 1.4)),
            const SizedBox(height: ThixPolicy.s32),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: ThixPolicy.s12,
                mainAxisSpacing: ThixPolicy.s12,
                childAspectRatio: 1.5, // Ajusté pour lire le texte complet
              ),
              itemCount: actions.length,
              itemBuilder: (ctx, i) {
                final a = actions[i];
                return InkWell(
                  onTap: () => _sendMessage(textOverride: a["desc"] as String),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  child: Container(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a["icon"] as IconData, color: ThixPolicy.primary, size: 20),
                        const SizedBox(height: 8),
                        Text(a["title"] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                        const SizedBox(height: 4),
                        Expanded(child: Text(a["desc"] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, height: 1.3))),
                      ],
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

  // ─────────────────────────────────────────────────────────────
  // LISTE DES MESSAGES (CAPACITÉ TEXTES LONGS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: ThixPolicy.s16, right: ThixPolicy.s16, top: ThixPolicy.s16, bottom: 24),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final isError = msg['isError'] == true;
        final usedWeb = msg['usedWeb'] == true;

        if (isUser) {
          return Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85), // Plus large pour les questions longues
              child: Container(
                margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                decoration: const BoxDecoration(
                  color: ThixPolicy.primary,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(ThixPolicy.rLg), topRight: Radius.circular(ThixPolicy.rSm), bottomLeft: Radius.circular(ThixPolicy.rLg), bottomRight: Radius.circular(ThixPolicy.rLg)),
                ),
                child: SelectableText(msg['text']!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500)),
              ),
            ),
          );
        } else {
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92), // Très large pour bien lire les longs rapports
              child: Container(
                margin: const EdgeInsets.only(bottom: ThixPolicy.s24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.only(right: ThixPolicy.s12, top: 4),
                      decoration: BoxDecoration(color: isError ? ThixPolicy.danger : ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                      child: Icon(isError ? Icons.error_outline : Icons.graphic_eq_rounded, color: isError ? Colors.white : ThixPolicy.primaryDeep, size: 14),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(isError ? "Erreur" : "THIX IA", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ThixPolicy.textMain)),
                              if (usedWeb) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(4)),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.travel_explore_rounded, size: 10, color: ThixPolicy.primary),
                                      SizedBox(width: 4),
                                      Text("Tavily Live", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ThixPolicy.primary)),
                                    ],
                                  ),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(ThixPolicy.s16),
                            decoration: BoxDecoration(
                              color: isError ? ThixPolicy.danger.withOpacity(0.05) : ThixPolicy.card,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(ThixPolicy.rSm), topRight: Radius.circular(ThixPolicy.rLg), bottomLeft: Radius.circular(ThixPolicy.rLg), bottomRight: Radius.circular(ThixPolicy.rLg)),
                              border: Border.all(color: isError ? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border),
                              boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
                            ),
                            // SelectableText permet de scroller et copier les très longs textes sans casser l'UI
                            child: SelectableText(msg['text']!, style: TextStyle(color: isError ? ThixPolicy.danger : ThixPolicy.textMain, fontSize: 14, height: 1.6)),
                          ),
                          const SizedBox(height: 4),
                          if (!isError)
                            Row(
                              children: [
                                _bubbleAction(Icons.copy_rounded, "Copier", () {
                                  Clipboard.setData(ClipboardData(text: msg['text']));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texte de l\'IA copié')));
                                }),
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
        }
      },
    );
  }

  Widget _bubbleAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 12, color: ThixPolicy.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 16),
      child: Row(
        children: const [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.5, color: ThixPolicy.primary)),
          SizedBox(width: 12),
          Text("Génération de l'analyse...", style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BARRE DE SAISIE (GESTION DES LONGS TEXTES)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPremiumInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s12, ThixPolicy.s16, MediaQuery.paddingOf(context).bottom + ThixPolicy.s12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: const Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _useTavilyWebSearch = !_useTavilyWebSearch);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _useTavilyWebSearch ? ThixPolicy.tint : ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      border: Border.all(color: _useTavilyWebSearch ? ThixPolicy.primary.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, size: 14, color: _useTavilyWebSearch ? ThixPolicy.primary : ThixPolicy.textSecondary),
                        const SizedBox(width: 6),
                        Text('Recherche Live (Tavily)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _useTavilyWebSearch ? ThixPolicy.primary : ThixPolicy.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file_rounded, color: ThixPolicy.textSecondary),
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pièces jointes bientôt disponibles')));
                },
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        // TextField avec Scrollbar intégrée pour les très longs prompts de l'utilisateur
                        child: Scrollbar(
                          child: TextField(
                            controller: _messageController,
                            maxLines: 7, // Permet de saisir des pavés de texte confortablement
                            minLines: 1,
                            style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Demandez à l\'expert THIX...',
                              hintStyle: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _isLoading ? ThixPolicy.surfaceStrong : ThixPolicy.inkDeep,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                            onPressed: _isLoading ? null : () => _sendMessage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
