import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingShimmer extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const LoadingShimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: child,
    );
  }
}

// Product card shimmer
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 160, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: double.infinity, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(height: 10, width: 80, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(height: 14, width: 100, color: Colors.grey[200]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shop card shimmer
class ShopCardShimmer extends StatelessWidget {
  const ShopCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(height: 90, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200])),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      children: [
                        Container(height: 12, width: double.infinity, color: Colors.grey[200]),
                        const SizedBox(height: 4),
                        Container(height: 10, width: 60, color: Colors.grey[200]),
                      ],
                    )),
                  ],
                ),
                const SizedBox(height: 6),
                Container(height: 20, color: Colors.grey[200]),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 40, height: 10, color: Colors.grey[200]),
                    const SizedBox(width: 8),
                    Container(width: 30, height: 10, color: Colors.grey[200]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// List tile shimmer
class ListTileShimmer extends StatelessWidget {
  const ListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(width: 50, height: 50, color: Colors.grey[200]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: double.infinity, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(height: 12, width: 120, color: Colors.grey[200]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Grid shimmer
class GridShimmer extends StatelessWidget {
  final int count;
  final int crossAxisCount;

  const GridShimmer({super.key, this.count = 4, this.crossAxisCount = 2});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (context, index) => const ProductCardShimmer(),
    );
  }
}
