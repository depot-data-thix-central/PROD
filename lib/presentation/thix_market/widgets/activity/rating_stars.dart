import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RatingStars extends StatefulWidget {
  final String userId;
  final double size;
  final bool interactive;

  const RatingStars({
    super.key,
    required this.userId,
    this.size = 20,
    this.interactive = false,
  });

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {
  double _rating = 0;
  int _totalRatings = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_ratings')
          .select('rating, count')
          .eq('rated_user_id', widget.userId);
      
      final avg = response.isNotEmpty ? (response[0]['rating'] ?? 0.0) : 0.0;
      final count = response.isNotEmpty ? (response[0]['count'] ?? 0) : 0;
      
      setState(() {
        _rating = avg.toDouble();
        _totalRatings = count;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading rating: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating(double value) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour évaluer')),
      );
      return;
    }
    if (currentUserId == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas vous évaluer vous-même')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client
          .from('user_ratings')
          .upsert({
            'rater_user_id': currentUserId,
            'rated_user_id': widget.userId,
            'rating': value,
            'updated_at': DateTime.now().toIso8601String(),
          });
      await _loadRating();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Évaluation enregistrée')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 100,
        height: 20,
        child: LinearProgressIndicator(),
      );
    }

    return Column(
      children: [
        RatingBar.builder(
          initialRating: _rating,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemSize: widget.size,
          ignoreGestures: !widget.interactive || _isSubmitting,
          itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
          onRatingUpdate: (value) {
            if (widget.interactive) {
              _submitRating(value);
            }
          },
        ),
        if (_totalRatings > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$_totalRatings évaluation(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}
