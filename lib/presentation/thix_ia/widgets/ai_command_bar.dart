// lib/presentation/thix_ia/widgets/ai_command_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

/// ============================================================================
/// AI COMMAND BAR - Barre de commande THIX IA style Linear/Notion
/// ============================================================================

class AiCommandBar extends StatefulWidget {
  const AiCommandBar({
    super.key,
    required this.onSubmit,
    this.hintText = 'Demandez à THIX IA...',
    this.isLoading = false,
  });

  final Function(String) onSubmit;
  final String hintText;
  final bool isLoading;

  @override
  State<AiCommandBar> createState() => _AiCommandBarState();
}

class _AiCommandBarState extends State<AiCommandBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  final _suggestions = const [
    'Analyse le marché en RDC',
    'Vérifie la réglementation',
    'Calcule le modèle financier',
    'Qui sont les concurrents?',
    'Génère le business plan',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s10, ThixPolicy.s16, ThixPolicy.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      return GestureDetector(
                        onTap: () => widget.onSubmit(_suggestions[i]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: ThixPolicy.border)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 12, color: ThixPolicy.textSecondary),
                              const SizedBox(width: 6),
                              Text(_suggestions[i], style: ThixPolicy.captionStyle),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: ThixPolicy.s10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
                        child: Row(
                          children: [
                            const SizedBox(width: ThixPolicy.s12),
                            Icon(Icons.bolt_rounded, size: 18, color: ThixPolicy.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focus,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(hintText: widget.hintText, hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                                style: ThixPolicy.bodyStyle,
                                minLines: 1,
                                maxLines: 4,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s10),
                    GestureDetector(
                      onTap: widget.isLoading? null : _submit,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(gradient: ThixPolicy.brandGradient, borderRadius: BorderRadius.circular(ThixPolicy.rFull), boxShadow: ThixPolicy.shadowSoft()),
                        child: widget.isLoading
                          ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
