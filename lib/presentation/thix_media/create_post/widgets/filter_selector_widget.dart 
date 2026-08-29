import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/create_post_constants.dart';

class FilterSelectorWidget extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const FilterSelectorWidget({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtre appliqué',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: CreatePostConstants.filters.length,
            itemBuilder: (context, index) {
              final filter = CreatePostConstants.filters[index];
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onFilterChanged(filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? CreatePostColors.navyDeep : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
