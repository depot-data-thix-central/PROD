// lib/presentation/admin/pages/create_news_page.dart
import 'package:flutter/material.dart';

// Décommenter si nécessaire dans le futur
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:provider/provider.dart';
// import '../../../providers/news_provider.dart';
// import '../../../models/news_article.dart';

class CreateNewsPage extends StatefulWidget {
  final dynamic article; // Remplacé NewsArticle par dynamic pour éviter les erreurs

  const CreateNewsPage({super.key, this.article});

  @override
  State<CreateNewsPage> createState() => _CreateNewsPageState();
}

class _CreateNewsPageState extends State<CreateNewsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B3D),
        elevation: 0,
        title: Text(
          widget.article != null ? 'Modifier l\'article' : 'Nouvel article',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text('Formulaire de création (Squelette)'),
      ),
    );
  }
}
