// lib/presentation/thix_info/widgets/search_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchBarWidget extends StatelessWidget {
  final bool autoFocus;
  final TextEditingController? controller;
  final Function(String)? onSearch;

  const SearchBarWidget({
    super.key,
    this.autoFocus = false,
    this.controller,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onSearch == null) {
          context.push('/thix-info/search');
        }
      },
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: Colors.grey[500]),
            const SizedBox(width: 10),
            Expanded(
              child: onSearch != null && controller != null
                  ? TextField(
                      controller: controller,
                      autofocus: autoFocus,
                      onChanged: onSearch,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une actualité, un sujet...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 13),
                    )
                  : Text(
                      'Rechercher une actualité, un sujet...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
            ),
            if (controller != null && controller!.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller?.clear();
                  onSearch?.call('');
                },
                child: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchBarWithFilter extends StatefulWidget {
  final Function(String) onSearch;
  final List<String> filters;
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const SearchBarWithFilter({
    super.key,
    required this.onSearch,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<SearchBarWithFilter> createState() => _SearchBarWithFilterState();
}

class _SearchBarWithFilterState extends State<SearchBarWithFilter> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBarWidget(
          controller: _controller,
          onSearch: widget.onSearch,
          autoFocus: true,
        ),
        if (widget.filters.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: widget.filters.map((filter) {
                final isSelected = widget.selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(filter, style: const TextStyle(fontSize: 12)),
                    onSelected: (_) => widget.onFilterChanged(filter),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFD4AF37).withOpacity(0.15),
                    side: BorderSide(color: isSelected ? const Color(0xFFD4AF37) : Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
