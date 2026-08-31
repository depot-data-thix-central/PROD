// lib/presentation/chat/widgets/chat_input_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kInputMinHeight = 42.0;
const double _kInputMaxHeight = 130.0;
const double _kInputRadius = 22.0;
const double _kToolChipRadius = 20.0;
const double _kMicButtonSize = 42.0;
const double _kSendButtonSize = 44.0;
const double _kIconSize = 16.0;
const double _kSendIconSize = 20.0;
const double _kMicIconSize = 22.0;
const double _kLoaderSize = 18.0;
const int _kMaxMessageLength = 5000;

// ============================================================================
// CHAT INPUT BAR
// ============================================================================
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onAudio;
  final VoidCallback onSecureMessage;
  final VoidCallback onEphemeralToggle;
  final bool isEphemeral;
  final ValueChanged<String>? onTyping;
  final VoidCallback? onInternalNoteToggle;
  final VoidCallback? onStickerTap;
  final bool isInternalNote;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isSending,
    required this.onAttach,
    required this.onAudio,
    required this.onSecureMessage,
    required this.onEphemeralToggle,
    required this.isEphemeral,
    this.onTyping,
    this.onInternalNoteToggle,
    this.onStickerTap,
    this.isInternalNote = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (_hasText != has) {
      setState(() => _hasText = has);
    }
  }

  void _handleSend() {
    if (widget.isSending || !_hasText) {
      debugPrint('[ChatInput] ⚠️ Send blocked: isSending=${widget.isSending}, hasText=$_hasText');
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    debugPrint('[ChatInput] 📤 Send triggered');
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNote = widget.isInternalNote;

    // Couleurs dynamiques selon le mode
    final bg = isNote ? ThixPolicy.warning.withOpacity(0.08) : ThixPolicy.card;
    final topBorder = isNote ? ThixPolicy.warning.withOpacity(0.3) : ThixPolicy.border;
    final hint = isNote ? l10n.t('input_note_hint') : l10n.t('input_message_hint');
    final sendColor = isNote ? ThixPolicy.warning : ThixPolicy.primary;
    final inputFill = isNote ? ThixPolicy.warning.withOpacity(0.12) : ThixPolicy.surfaceSoft;
    final inputBorder = isNote ? ThixPolicy.warning.withOpacity(0.3) : Colors.transparent;
    final focusBorder = isNote ? ThixPolicy.warning : ThixPolicy.primary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: topBorder)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Bande d'outils ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(
                children: [
                  _ToolChip(
                    icon: Icons.attach_file_rounded,
                    label: l10n.t('input_attach_file'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      debugPrint('[ChatInput] 📎 Attach tapped');
                      widget.onAttach();
                    },
                  ),
                  _ToolChip(
                    icon: Icons.emoji_emotions_outlined,
                    label: l10n.t('input_sticker'),
                    onTap: widget.onStickerTap != null
                        ? () {
                            HapticFeedback.selectionClick();
                            debugPrint('[ChatInput] 😊 Sticker tapped');
                            widget.onStickerTap!();
                          }
                        : null,
                  ),
                  _ToolChip(
                    icon: widget.isEphemeral
                        ? Icons.timer_rounded
                        : Icons.timer_outlined,
                    label: l10n.t('input_ephemeral'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      debugPrint('[ChatInput] ⏱️ Ephemeral toggled: ${!widget.isEphemeral}');
                      widget.onEphemeralToggle();
                    },
                    active: widget.isEphemeral,
                    activeColor: ThixPolicy.gold,
                  ),
                  _ToolChip(
                    icon: Icons.lock_outline_rounded,
                    label: l10n.t('input_secure'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      debugPrint('[ChatInput] 🔒 Secure message tapped');
                      widget.onSecureMessage();
                    },
                  ),
                  if (widget.onInternalNoteToggle != null)
                    _ToolChip(
                      icon: Icons.speaker_notes_outlined,
                      label: l10n.t('input_note'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        debugPrint('[ChatInput] 📝 Note toggled: ${!isNote}');
                        widget.onInternalNoteToggle!();
                      },
                      active: isNote,
                      activeColor: ThixPolicy.warning,
                    ),
                ],
              ),
            ),

            // ── Banner mode note ──
            if (isNote)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThixPolicy.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: ThixPolicy.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.t('input_note_banner'),
                        style: ThixPolicy.microStyle.copyWith(
                          fontSize: 11,
                          fontWeight: ThixPolicy.semiBold,
                          color: ThixPolicy.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Banner éphémère ──
            if (widget.isEphemeral && !isNote)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ThixPolicy.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, size: 14, color: ThixPolicy.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.t('input_ephemeral_banner'),
                        style: ThixPolicy.microStyle.copyWith(
                          fontSize: 11,
                          fontWeight: ThixPolicy.semiBold,
                          color: ThixPolicy.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Zone de saisie ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Micro (si pas de texte)
                  if (!_hasText) ...[
                    _IconRound(
                      icon: Icons.mic_none_rounded,
                      semanticsLabel: l10n.t('input_audio'),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        debugPrint('[ChatInput] 🎤 Audio tapped');
                        widget.onAudio();
                      },
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Champ texte
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _kInputMinHeight,
                        maxHeight: _kInputMaxHeight,
                      ),
                      child: Semantics(
                        label: l10n.t('input_text_label'),
                        textField: true,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          onChanged: (v) {
                            widget.onTyping?.call(v);
                            _onTextChanged();
                          },
                          maxLines: null,
                          minLines: 1,
                          maxLength: _kMaxMessageLength,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: ThixPolicy.bodyStyle.copyWith(
                            fontSize: 15,
                            color: ThixPolicy.textMain,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: hint,
                            hintStyle: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(_kInputRadius),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(_kInputRadius),
                              borderSide: BorderSide(color: inputBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(_kInputRadius),
                              borderSide: BorderSide(color: focusBorder, width: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Envoi
                  _SendButton(
                    enabled: _hasText && !widget.isSending,
                    loading: widget.isSending,
                    color: sendColor,
                    semanticsLabel: l10n.t('input_send'),
                    onTap: _handleSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOOL CHIP
// ============================================================================
class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  const _ToolChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.activeColor = ThixPolicy.gold,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : ThixPolicy.textMuted;
    final bgColor = active ? activeColor.withOpacity(0.12) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        enabled: onTap != null,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(_kToolChipRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_kToolChipRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: _kIconSize, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ICON ROUND (MIC)
// ============================================================================
class _IconRound extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _IconRound({
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: ThixPolicy.surfaceSoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _kMicButtonSize,
            height: _kMicButtonSize,
            child: Icon(icon, size: _kMicIconSize, color: ThixPolicy.textMuted),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SEND BUTTON
// ============================================================================
class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final Color color;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = enabled ? color : ThixPolicy.textMuted.withOpacity(0.3);

    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: enabled,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        elevation: enabled ? 1 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: _kSendButtonSize,
            height: _kSendButtonSize,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: _kLoaderSize,
                      height: _kLoaderSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: _kSendIconSize,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
