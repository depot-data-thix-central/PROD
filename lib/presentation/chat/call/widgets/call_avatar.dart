// Route: lib/presentation/chat/call/widgets/call_avatar.dart
// PRODUCTION - Avatar animé avec pulse - Image + Initiales + Badge
import 'dart:async';
import 'package:flutter/material.dart';

class CallAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool isVideo;
  final bool isRinging;

  const CallAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 110,
    this.isVideo = false,
    this.isRinging = true,
  });

  @override
  State<CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<CallAvatar>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutQuad),
    );

    _fadeAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut),
    );

    if (widget.isRinging) {
      _pulseCtrl.repeat(reverse: true);
      _fadeCtrl.repeat(reverse: true);
    }
  }

  String get _initials {
    final n = widget.name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  void didUpdateWidget(covariant CallAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRinging &&!oldWidget.isRinging) {
      _pulseCtrl.repeat(reverse: true);
      _fadeCtrl.repeat(reverse: true);
    } else if (!widget.isRinging && oldWidget.isRinging) {
      _pulseCtrl.stop();
      _fadeCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.imageUrl!= null && widget.imageUrl!.trim().isNotEmpty;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _fadeAnim]),
      builder: (_, child) {
        return Transform.scale(
          scale: widget.isRinging? _pulseAnim.value : 1.0,
          child: FadeTransition(
            opacity: widget.isRinging? _fadeAnim : const AlwaysStoppedAnimation(1.0),
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glow externe
          Container(
            width: widget.size + 22,
            height: widget.size + 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D6CDF).withOpacity(0.32),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFFE3B23C).withOpacity(0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),

          // Avatar principal
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF123B7A),
              border: Border.all(
                color: const Color(0xFFE3B23C),
                width: 2.2,
              ),
              image: hasImage
                ? DecorationImage(
                      image: NetworkImage(widget.imageUrl!),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    )
                  : null,
            ),
            child: hasImage
              ? null
                : Center(
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.size * 0.38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                  ),
          ),

          // Badge type d'appel
          if (widget.isVideo)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: widget.size * 0.30,
                height: widget.size * 0.30,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FA971),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A1F44), width: 2.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  size: widget.size * 0.16,
                  color: Colors.white,
                ),
              ),
            )
          else
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: widget.size * 0.28,
                height: widget.size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6CDF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A1F44), width: 2.2),
                ),
                child: Icon(
                  Icons.call_rounded,
                  size: widget.size * 0.14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
