import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class PopularRouteSkeletonList extends StatefulWidget {
  const PopularRouteSkeletonList({super.key});

  @override
  State<PopularRouteSkeletonList> createState() =>
      _PopularRouteSkeletonListState();
}

class _PopularRouteSkeletonListState extends State<PopularRouteSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      listenable: _ctrl,
      builder: (ctx, _) {
        final alpha = (0.5 + (_ctrl.value * 0.3)).clamp(0.0, 1.0);
        final color = ThixPolicy.surfaceStrong.withValues(alpha: alpha);

        return SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => SizedBox(width: ThixPolicy.s12),
            itemBuilder: (_, __) => Container(
              width: 168,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 90, width: double.infinity, color: color),
                  Padding(
                    padding: EdgeInsets.all(ThixPolicy.s10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 12, color: color),
                        SizedBox(height: ThixPolicy.s6),
                        Container(width: 80, height: 10, color: color),
                        SizedBox(height: ThixPolicy.s8),
                        Container(width: 60, height: 12, color: color),
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
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}
