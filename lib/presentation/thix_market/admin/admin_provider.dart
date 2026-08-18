import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;

  // Données dashboard
  DashboardStats _dashboardStats = DashboardStats.empty();
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _recentActivities = [];

  // Données produits
  List<Map<String, dynamic>> _products = [];
  int _totalProducts = 0;

  // Données boutiques
  List<Map<String, dynamic>> _shops = [];
  int _totalShops = 0;

  // Données utilisateurs
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;

  // Données commandes
  List<Map<String, dynamic>> _orders = [];
  int _totalOrders = 0;

  // Données litiges
  List<Map<String, dynamic>> _disputes = [];
  int _totalDisputes = 0;

  // Données promotions
  List<Map<String, dynamic>> _promotions = [];
  List<Map<String, dynamic>> _banners = [];

  // Pagination
  int _currentPage = 0;
  int _pageSize = 20;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'created_at';
  bool _sortAscending = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin => _isAdmin;

  DashboardStats get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get recentOrders => _recentOrders;
  List<Map<String, dynamic>> get recentActivities => _recentActivities;

  List<Map<String, dynamic>> get products => _products;
  int get totalProducts => _totalProducts;

  List<Map<String, dynamic>> get shops => _shops;
  int get totalShops => _totalShops;

  List<Map<String, dynamic>> get users => _users;
  int get totalUsers => _totalUsers;

  List<Map<String, dynamic>> get orders => _orders;
  int get totalOrders => _totalOrders;

  List<Map<String, dynamic>> get disputes => _disputes;
  int get totalDisputes => _totalDisputes;

  List<Map<String, dynamic>> get promotions => _promotions;
  List<Map<String, dynamic>> get banners => _banners;

  int get currentPage => _currentPage;

  // ============================================================
  // Initialisation
  // ============================================================

  Future<bool> checkAdminStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      _isAdmin = response['role'] == 'admin';
      notifyListeners();
      return _isAdmin;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // Dashboard
  // ============================================================

  Future<void> loadDashboard() async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      final statsResponse = await _supabase.rpc('get_admin_dashboard_stats');
      _dashboardStats = DashboardStats.fromJson(statsResponse);

      final ordersResponse = await _supabase
          .from('orders')
          .select('*, user:users(name)')
          .order('created_at', ascending: false)
          .limit(10);
      _recentOrders = List<Map<String, dynamic>>.from(ordersResponse);

      final activitiesResponse = await _supabase
          .from('admin_activities')
          .select('*, admin:users(name)')
          .order('created_at', ascending: false)
          .limit(10);
      _recentActivities = List<Map<String, dynamic>>.from(activitiesResponse);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des produits
  // ============================================================

  Future<void> loadProducts({bool refresh = false}) async {
    if (!_isAdmin) return;
    if (refresh) {
      _currentPage = 0;
      _products.clear();
    }
    setState(() => _isLoading = true);
    try {
      // 1. Requête de base avec filtres (type PostgrestFilterBuilder)
      var query = _supabase
          .from('products')
          .select('*, shop:shops(name)');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('title', '%$_searchQuery%');
      }
      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      // 2. Appliquer le tri → nouvelle variable (type PostgrestTransformBuilder)
      final orderedQuery = query.order(_sortBy, ascending: _sortAscending);

      // 3. Compter les résultats
      final countResult = await orderedQuery.count();
      _totalProducts = countResult.count ?? 0;

      // 4. Paginer → nouvelle variable
      final paginatedQuery = orderedQuery.range(
          _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);
      final response = await paginatedQuery;

      _products = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateProductStatus(String productId, String status) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('products')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', productId);
      await loadProducts(refresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des boutiques
  // ============================================================

  Future<void> loadShops({bool refresh = false}) async {
    if (!_isAdmin) return;
    if (refresh) {
      _currentPage = 0;
      _shops.clear();
    }
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('shops')
          .select('*, owner:users(name, email)');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }
      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      // Pas de tri personnalisé pour les boutiques, mais on garde un ordre simple
      final orderedQuery = query.order('created_at', ascending: false);

      final countResult = await orderedQuery.count();
      _totalShops = countResult.count ?? 0;

      final paginatedQuery = orderedQuery.range(
          _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);
      final response = await paginatedQuery;

      _shops = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateShopStatus(String shopId, String status) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('shops')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', shopId);
      await loadShops(refresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des utilisateurs
  // ============================================================

  Future<void> loadUsers({bool refresh = false}) async {
    if (!_isAdmin) return;
    if (refresh) {
      _currentPage = 0;
      _users.clear();
    }
    setState(() => _isLoading = true);
    try {
      var query = _supabase.from('users').select('*');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      final orderedQuery = query.order('created_at', ascending: false);

      final countResult = await orderedQuery.count();
      _totalUsers = countResult.count ?? 0;

      final paginatedQuery = orderedQuery.range(
          _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);
      final response = await paginatedQuery;

      _users = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('users')
          .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
      await loadUsers(refresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des commandes
  // ============================================================

  Future<void> loadOrders({bool refresh = false}) async {
    if (!_isAdmin) return;
    if (refresh) {
      _currentPage = 0;
      _orders.clear();
    }
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('orders')
          .select('*, user:users(name, email)');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('id', '%$_searchQuery%');
      }
      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      final orderedQuery = query.order(_sortBy, ascending: _sortAscending);

      final countResult = await orderedQuery.count();
      _totalOrders = countResult.count ?? 0;

      final paginatedQuery = orderedQuery.range(
          _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);
      final response = await paginatedQuery;

      _orders = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      final updates = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'delivered') {
        updates['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _supabase
          .from('orders')
          .update(updates)
          .eq('id', orderId);
      await loadOrders(refresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des litiges
  // ============================================================

  Future<void> loadDisputes({bool refresh = false}) async {
    if (!_isAdmin) return;
    if (refresh) {
      _currentPage = 0;
      _disputes.clear();
    }
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('disputes')
          .select('*, order:orders(id, total), user:users(name)');

      if (_statusFilter != 'all') {
        query = query.eq('status', _statusFilter);
      }

      final orderedQuery = query.order('created_at', ascending: false);

      final countResult = await orderedQuery.count();
      _totalDisputes = countResult.count ?? 0;

      final paginatedQuery = orderedQuery.range(
          _currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);
      final response = await paginatedQuery;

      _disputes = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateDisputeStatus(String disputeId, String status) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('disputes')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', disputeId);
      await loadDisputes(refresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Gestion des promotions
  // ============================================================

  Future<void> loadPromotions() async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('promotions')
          .select()
          .order('created_at', ascending: false);
      _promotions = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> loadBanners() async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('promo_banners')
          .select()
          .order('sort_order', ascending: true);
      _banners = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> createPromotion(Map<String, dynamic> data) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.from('promotions').insert({
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadPromotions();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updatePromotionStatus(String promoId, bool isActive) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('promotions')
          .update({'is_active': isActive})
          .eq('id', promoId);
      await loadPromotions();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> updateBannerStatus(String bannerId, bool isActive) async {
    if (!_isAdmin) return;
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('promo_banners')
          .update({'is_active': isActive})
          .eq('id', bannerId);
      await loadBanners();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Pagination et filtres
  // ============================================================

  void nextPage() {
    _currentPage++;
    _refreshCurrentList();
  }

  void previousPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _refreshCurrentList();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 0;
    _refreshCurrentList();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _currentPage = 0;
    _refreshCurrentList();
  }

  void setSortBy(String sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = false;
    }
    _refreshCurrentList();
  }

  void _refreshCurrentList() {
    notifyListeners();
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

class DashboardStats {
  final int totalUsers;
  final int totalShops;
  final int totalProducts;
  final int totalOrders;
  final double totalRevenue;
  final double thisMonthRevenue;
  final double revenueGrowth;

  DashboardStats({
    required this.totalUsers,
    required this.totalShops,
    required this.totalProducts,
    required this.totalOrders,
    required this.totalRevenue,
    required this.thisMonthRevenue,
    required this.revenueGrowth,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalUsers: 0,
      totalShops: 0,
      totalProducts: 0,
      totalOrders: 0,
      totalRevenue: 0,
      thisMonthRevenue: 0,
      revenueGrowth: 0,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['total_users'] ?? 0,
      totalShops: json['total_shops'] ?? 0,
      totalProducts: json['total_products'] ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      thisMonthRevenue: (json['this_month_revenue'] as num?)?.toDouble() ?? 0,
      revenueGrowth: (json['revenue_growth'] as num?)?.toDouble() ?? 0,
    );
  }
}
