import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/thix_design_policy.dart';

class CountdownBar extends StatefulWidget {
  final DateTime start;
  final DateTime target;
  final String label;
  final Color color;

  const CountdownBar({
    super.key,
    required this.start,
    required this.target,
    required this.label,
    this.color = const Color(0xFF2563EB),
  });

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = widget.target.difference(widget.start).inMilliseconds;
    final elapsed = now.difference(widget.start).inMilliseconds;
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final remaining = widget.target.difference(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                color: ThixPolicy.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _fmt(remaining),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: widget.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: widget.color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ],
    );
  }
}
