// lib/presentation/education/providers/book_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart'; // Assurez-vous que le chemin vers votre modèle Book est correct

/// Provider pour récupérer la liste des livres depuis Supabase
final myBooksProvider = FutureProvider.family<List<Book>, String>((ref, userId) async {
  try {
    // Requête vers votre table 'books'
    final response = await Supabase.instance.client
        .from('books')
        // .eq('created_by', userId) // 💡 Décommentez cette ligne si vous voulez afficher UNIQUEMENT les livres ajoutés par cet utilisateur
        .select()
        .order('created_at', ascending: false);

    // Conversion de la réponse JSON en liste d'objets Book
    return (response as List<dynamic>).map((data) => Book.fromJson(data)).toList();
  } catch (e) {
    throw Exception('Erreur lors du chargement des livres : $e');
  }
});
