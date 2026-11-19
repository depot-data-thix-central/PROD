// lib/presentation/vault/vault_theme.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'vault_state.dart';

class VT {
  VT._();
  static const bg = Color(0xFFF4F4F1);
  static const ink = Color(0xFF101513);
  static const forest = Color(0xFF123B30);
  static const forest2 = Color(0xFF1B5243);
  static const forestSoft = Color(0xFFE3EEE9);
  static const mint = Color(0xFF9BE8C8);
  static const line = Color(0xFFE7E7E2);
  static const sub = Color(0xFF666E69);
  static const mute = Color(0xFFA2A8A4);
  static const ok = Color(0xFF1F9D6B);
  static const red = Color(0xFFE5484D);
  static const amber = Color(0xFFE8890C);
  static const blue = Color(0xFF3B6EF5);
  static const violet = Color(0xFF7A52E8);
}

// ---------------------------------------------------------------- Helpers
String fmtDate(dynamic v) {
  final d = v is DateTime ? v : DateTime.tryParse((v ?? '').toString());
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

String fmtDT(DateTime d) {
  final l = d.toLocal();
  return '${fmtDate(l)} à ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String fmtSize(int b) => b < 1024 * 1024
    ? '${(b / 1024).toStringAsFixed(0)} Ko'
    : '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';

String shortHash(String? h) =>
    (h == null || h.length < 16) ? '—' : '${h.substring(0, 8)}…${h.substring(h.length - 6)}';

bool isImageMime(String? mime, String? name) {
  final m = (mime ?? '').toLowerCase();
  final n = (name ?? '').toLowerCase();
  return m.startsWith('image/') ||
      n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.webp');
}

Color typeColor(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  if (m.contains('image')) return VT.violet;
  if (m.contains('pdf')) return VT.red;
  if (m.contains('word')) return VT.blue;
  if (m.contains('sheet') || m.contains('excel')) return VT.ok;
  return VT.forest;
}

IconData typeIcon(String? mime, String? docType) {
  final m = (mime ?? '').toLowerCase();
  final t = (docType ?? '').toLowerCase();
  if (m.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (m.contains('image')) return Icons.image_rounded;
  if (t == 'cin' || t == 'passeport' || t == 'permis') return Icons.badge_rounded;
  if (t.contains('dipl')) return Icons.school_rounded;
  return Icons.description_rounded;
}

bool isShareLocked(JsonMap s) {
  final st = (s['status'] as String?) ?? 'pending';
  final af = DateTime.tryParse((s['available_from'] ?? '').toString());
  return af != null &&
      af.isAfter(DateTime.now()) &&
      st != 'opened' &&
      st != 'destroyed' &&
      st != 'expired';
}

Widget? shareCountdown(JsonMap s) {
  final af = DateTime.tryParse((s['available_from'] ?? '').toString());
  final ad = DateTime.tryParse((s['auto_destruct_at'] ?? '').toString());
  final cd = DateTime.tryParse((s['created_at'] ?? '').toString()) ?? DateTime.now();
  if (isShareLocked(s) && af != null) {
    return VCountdown(start: cd, target: af, label: 'Déverrouillage dans', color: VT.blue);
  }
  if (ad != null) {
    return VCountdown(start: cd, target: ad, label: 'Autodestruction dans', color: VT.red);
  }
  return null;
}

Future<bool> launchOut(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  for (final mode in [LaunchMode.externalApplication, LaunchMode.platformDefault]) {
    try {
      if (await launchUrl(uri, mode: mode, webOnlyWindowName: kIsWeb ? '_blank' : null)) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}

void vSnackOn(ScaffoldMessengerState m, String msg, {bool error = false}) {
  m.showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: error ? VT.red : VT.ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: const Duration(seconds: 3),
  ));
}

void vSnack(BuildContext c, String msg, {bool error = false}) {
  if (!c.mounted) return;
  final m = ScaffoldMessenger.maybeOf(c);
  if (m != null) vSnackOn(m, msg, error: error);
}

InputDecoration vInput(String label, {String? hint, IconData? icon}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hint,
    labelStyle: const TextStyle(color: VT.sub, fontSize: 12.5),
    hintStyle: const TextStyle(color: VT.mute, fontSize: 12.5),
    prefixIcon: icon == null ? null : Icon(icon, size: 18, color: VT.sub),
    filled: true,
    fillColor: Colors.white,
    border: b(VT.line),
    enabledBorder: b(VT.line),
    focusedBorder: b(VT.forest, 1.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

Future<T?> showVSheet<T>(BuildContext context,
    {required WidgetBuilder builder, double maxFactor = 0.92}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * maxFactor),
          child: Container(
            decoration: const BoxDecoration(
              color: VT.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: VT.line, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      child: builder(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- Widgets
class VCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color? borderColor;
  final double radius;
  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.color = Colors.white,
    this.borderColor,
    this.radius = 22,
  });
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Material(
      color: color,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
              borderRadius: r, border: Border.all(color: borderColor ?? VT.line)),
          child: child,
        ),
      ),
    );
  }
}

class VTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const VTag(this.text, this.color, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 4)],
          Text(text,
              style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
        ]),
      );
}

enum VKind { dark, mint, soft, danger, outline }

class VButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VKind kind;
  final bool busy;
  final bool expand;
  final double height;
  const VButton(this.label,
      {super.key,
      this.icon,
      this.onTap,
      this.kind = VKind.dark,
      this.busy = false,
      this.expand = true,
      this.height = 46});
  @override
  Widget build(BuildContext context) {
    Color bg = VT.ink, fg = Colors.white;
    Color? bd;
    switch (kind) {
      case VKind.dark:
        break;
      case VKind.mint:
        bg = VT.mint;
        fg = VT.forest;
        break;
      case VKind.soft:
        bg = VT.forestSoft;
        fg = VT.forest;
        break;
      case VKind.danger:
        bg = const Color(0xFFFDECEC);
        fg = VT.red;
        break;
      case VKind.outline:
        bg = Colors.white;
        fg = VT.ink;
        bd = VT.line;
        break;
    }
    final disabled = onTap == null || busy;
    final r = BorderRadius.circular(15);
    return Opacity(
      opacity: (onTap == null && !busy) ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: disabled ? null : onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                borderRadius: r, border: bd == null ? null : Border.all(color: bd)),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else if (icon != null)
                  Icon(icon, size: 17, color: fg),
                if (busy || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VCountdown extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;
  const VCountdown(
      {super.key,
      required this.start,
      required this.target,
      required this.label,
      this.color = VT.red});
  @override
  State<VCountdown> createState() => _VCountdownState();
}

class _VCountdownState extends State<VCountdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _f(Duration d) {
    if (d.isNegative) return '00:00:00';
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.target.difference(widget.start).inMilliseconds;
    final elapsed = DateTime.now().difference(widget.start).inMilliseconds;
    final p = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(widget.label,
            style: TextStyle(
                fontSize: 10, color: widget.color, fontWeight: FontWeight.w700)),
        Text(_f(widget.target.difference(DateTime.now())),
            style: TextStyle(
                fontSize: 11, color: widget.color, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: p,
          minHeight: 5,
          backgroundColor: widget.color.withOpacity(0.14),
          valueColor: AlwaysStoppedAnimation(widget.color),
        ),
      ),
    ]);
  }
}

Widget vSpinner() => const Center(
    child: Padding(
        padding: EdgeInsets.all(28),
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: VT.forest))));
