import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AdvancedSearchBar extends StatefulWidget {
  final Function(String query, Map<String, dynamic> filters) onSearch;
  final Function(Map<String, dynamic> product)? onProductTap;
  final List<String>? recentSearches;
  final Function(String)? onRecentSearchTap;
  final Function()? onClearRecent;

  const AdvancedSearchBar({
    super.key,
    required this.onSearch,
    this.onProductTap,
    this.recentSearches,
    this.onRecentSearchTap,
    this.onClearRecent,
  });

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<Map<String, dynamic>> _suggestions = [];
  String? _selectedCategory;
  String? _selectedSortBy;

  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'Toutes catégories', 'icon': Icons.category},
    {'id': 'fashion', 'name': 'Mode', 'icon': Icons.checkroom},
    {'id': 'electronics', 'name': 'Électronique', 'icon': Icons.phone_android},
    {'id': 'home', 'name': 'Maison', 'icon': Icons.home},
    {'id': 'services', 'name': 'Services', 'icon': Icons.build},
    {'id': 'vehicles', 'name': 'Véhicules', 'icon': Icons.directions_car},
    {'id': 'realestate', 'name': 'Immobilier', 'icon': Icons.house},
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'id': 'relevance', 'name': 'Pertinence', 'icon': Icons.trending_up},
    {'id': 'price_asc', 'name': 'Prix croissant', 'icon': Icons.arrow_upward},
    {'id': 'price_desc', 'name': 'Prix décroissant', 'icon': Icons.arrow_downward},
    {'id': 'rating', 'name': 'Meilleures notes', 'icon': Icons.star},
    {'id': 'newest', 'name': 'Plus récents', 'icon': Icons.fiber_new},
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;
    if (query.length >= 2) {
      setState(() => _isSearching = true);
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _fetchSuggestions(query);
      });
    } else {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final response = await Supabase.instance.client
          .rpc('search_suggestions', params: {
            'search_query': query,
            'limit': 10,
          });

      if (mounted) {
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _performSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      _focusNode.unfocus();
      widget.onSearch(query, {
        'category': _selectedCategory,
        'sort_by': _selectedSortBy,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche principale
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _focusNode.hasFocus ? gold : Colors.grey[200]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: textMuted, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher produits, boutiques...',
                            hintStyle: TextStyle(color: textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: textMuted, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _suggestions = [];
                              _isSearching = false;
                            });
                          },
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Filtre catégorie
              GestureDetector(
                onTap: () => _showCategorySelector(),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _selectedCategory != null && _selectedCategory != 'all'
                        ? gold.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _selectedCategory != null && _selectedCategory != 'all'
                          ? gold
                          : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _categories.firstWhere(
                          (c) => c['id'] == (_selectedCategory ?? 'all'),
                          orElse: () => _categories[0],
                        )['icon'],
                        size: 18,
                        color: _selectedCategory != null && _selectedCategory != 'all'
                            ? gold
                            : textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCategory != null && _selectedCategory != 'all'
                            ? _categories.firstWhere((c) => c['id'] == _selectedCategory)['name']
                            : 'Catégorie',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedCategory != null && _selectedCategory != 'all'
                              ? gold
                              : textMuted,
                          fontWeight: _selectedCategory != null && _selectedCategory != 'all'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Suggestions
        if (_isSearching && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ..._suggestions.map((suggestion) => ListTile(
                  leading: const Icon(Icons.search, size: 18, color: textMuted),
                  title: Text(
                    suggestion['text'] ?? '',
                    style: const TextStyle(fontSize: 14, color: navy),
                  ),
                  trailing: Text(
                    suggestion['type'] == 'product' ? 'Produit' : 'Boutique',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                  onTap: () {
                    _controller.text = suggestion['text'] ?? '';
                    _performSearch();
                  },
                )),
              ],
            ),
          ),

        // Recherches récentes
        if (!_isSearching && widget.recentSearches != null && widget.recentSearches!.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recherches récentes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onClearRecent,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Effacer',
                          style: TextStyle(fontSize: 12, color: danger),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.recentSearches!.map((search) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bgApp,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: InkWell(
                      onTap: () {
                        _controller.text = search;
                        _performSearch();
                        widget.onRecentSearchTap?.call(search);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 14, color: textMuted),
                          const SizedBox(width: 6),
                          Text(
                            search,
                            style: const TextStyle(fontSize: 13, color: navy),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catégories',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((category) {
                final isSelected = category['id'] == _selectedCategory;
                return FilterChip(
                  label: Text(category['name']),
                  avatar: Icon(category['icon'], size: 18),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = category['id'] == 'all' ? null : category['id'];
                    });
                    Navigator.pop(context);
                    if (_controller.text.isNotEmpty) {
                      _performSearch();
                    }
                  },
                  selectedColor: gold.withOpacity(0.1),
                  checkmarkColor: gold,
                  side: BorderSide(
                    color: isSelected ? gold : Colors.grey[200]!,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
