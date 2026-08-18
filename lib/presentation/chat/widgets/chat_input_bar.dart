// lib/presentation/chat/widgets/chat_input_bar.dart
import 'package:flutter/material.dart';

class _C {
  static const navy = Color(0xFF0A1F44);
  static const primary = Color(0xFF1D4ED8);
  static const gold = Color(0xFFE3B23C);
  static const orange = Color(0xFFF59E0B);
  static const border = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF64748B);
  static const surface = Color(0xFFF1F5F9);
}

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
    if (widget.isSending || !_hasText) return;
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final isNote = widget.isInternalNote;
    final bg = isNote ? const Color(0xFFFFF7ED) : Colors.white;
    final topBorder =
        isNote ? const Color(0xFFFED7AA) : _C.border;
    final hint = isNote
        ? 'Écrire une note interne…'
        : 'Écrire un message…';
    final sendColor = isNote ? _C.orange : _C.navy;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: topBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Bande d’outils ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(
                children: [
                  _ToolChip(
                    icon: Icons.attach_file_rounded,
                    label: 'Fichier',
                    onTap: widget.onAttach,
                  ),
                  _ToolChip(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Sticker',
                    onTap: widget.onStickerTap,
                  ),
                  _ToolChip(
                    icon: widget.isEphemeral
                        ? Icons.timer_rounded
                        : Icons.timer_outlined,
                    label: 'Éphémère',
                    onTap: widget.onEphemeralToggle,
                    active: widget.isEphemeral,
                    activeColor: _C.gold,
                  ),
                  _ToolChip(
                    icon: Icons.lock_outline_rounded,
                    label: 'Protégé',
                    onTap: widget.onSecureMessage,
                  ),
                  if (widget.onInternalNoteToggle != null)
                    _ToolChip(
                      icon: Icons.speaker_notes_outlined,
                      label: 'Note',
                      onTap: widget.onInternalNoteToggle,
                      active: isNote,
                      activeColor: _C.orange,
                    ),
                ],
              ),
            ),

            // ── Banner mode note ──
            if (isNote)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: _C.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mode note interne — visible uniquement par les agents',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.orange,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 14, color: _C.gold),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Message éphémère activé',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
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
                      onTap: widget.onAudio,
                      tooltip: 'Message audio',
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Champ texte
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 42,
                        maxHeight: 130,
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        onChanged: (v) {
                          widget.onTyping?.call(v);
                          _onTextChanged();
                        },
                        maxLines: null,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: const TextStyle(
                            color: _C.textMuted,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: isNote
                              ? const Color(0xFFFFEDD5)
                              : _C.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: isNote
                                  ? const Color(0xFFFED7AA)
                                  : Colors.transparent,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: isNote ? _C.orange : _C.primary,
                              width: 1.2,
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

// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────

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
    this.activeColor = _C.gold,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : _C.textMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active
            ? activeColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
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
    );
  }
}

class _IconRound extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconRound({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: _C.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 22, color: _C.textMuted),
        ),
      ),
    );

    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : const Color(0xFFCBD5E1),
      shape: const CircleBorder(),
      elevation: enabled ? 1 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
