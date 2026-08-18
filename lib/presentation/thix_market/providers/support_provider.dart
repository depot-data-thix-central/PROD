import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _faqs = [];
  List<Map<String, dynamic>> _filteredFaqs = [];
  List<Map<String, dynamic>> _supportTickets = [];
  bool _isLoading = false;
  bool _isLoadingTickets = false;

  List<Map<String, dynamic>> get filteredFAQs => _filteredFaqs;
  List<Map<String, dynamic>> get supportTickets => _supportTickets;
  bool get isLoading => _isLoading;
  bool get isLoadingTickets => _isLoadingTickets;

  Future<void> loadFAQs({String? category}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.from('market_faqs').select().order('sort_order');
      _faqs = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _faqs = [
        {
          'question': 'Comment acheter un produit ?',
          'answer': 'Choisissez un produit, ajoutez-le au panier puis validez votre commande.',
          'category': 'general',
        },
        {
          'question': 'Comment suivre ma commande ?',
          'answer': 'Consultez vos commandes dans l’onglet activité du Market.',
          'category': 'shipping',
        },
      ];
    }
    _filteredFaqs = category == null ? _faqs : _faqs.where((faq) => faq['category'] == category).toList();
    _isLoading = false;
    notifyListeners();
  }

  void searchFAQs(String query) {
    if (query.trim().isEmpty) {
      _filteredFaqs = List<Map<String, dynamic>>.from(_faqs);
    } else {
      final lower = query.toLowerCase();
      _filteredFaqs = _faqs.where((faq) {
        return (faq['question'] ?? '').toString().toLowerCase().contains(lower) ||
            (faq['answer'] ?? '').toString().toLowerCase().contains(lower);
      }).toList();
    }
    notifyListeners();
  }

  Future<void> loadSupportTickets() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _isLoadingTickets = true;
    notifyListeners();
    try {
      final response = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      _supportTickets = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _supportTickets = [];
    } finally {
      _isLoadingTickets = false;
      notifyListeners();
    }
  }

  Future<void> createTicket(String category, String message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final ticket = {
      'user_id': userId,
      'category': category,
      'subject': 'Support $category',
      'message': message,
      'status': 'open',
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final created = await _supabase.from('support_tickets').insert(ticket).select().single();
      _supportTickets.insert(0, created);
    } catch (_) {
      _supportTickets.insert(0, {'id': DateTime.now().millisecondsSinceEpoch.toString(), ...ticket});
    }
    notifyListeners();
  }
}
