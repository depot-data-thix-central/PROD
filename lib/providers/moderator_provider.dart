// lib/providers/moderator_provider.dart
import 'package:flutter/material.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';

class ModeratorProvider extends ChangeNotifier {
  final EventService _eventService;

  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;

  ModeratorProvider(this._eventService);

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllEvents({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // On récupère tous les événements via le service (qui doit autoriser l'admin)
      final all = await _eventService.getEventsForModerator(status: status);
      _events = all;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ loadAllEvents error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Event?> createEvent(Map<String, dynamic> data) async {
    try {
      final event = await _eventService.createEvent(
        title: data['title'],
        description: data['description'],
        category: data['category'],
        startDate: DateTime.parse(data['start_date']),
        location: data['location'],
        price: data['price'] ?? 0,
        isFree: data['is_free'] ?? false,
        capacity: data['capacity'],
        imageUrl: data['image_url'],
        city: data['city'],
        address: data['address'],
        isFeatured: data['is_featured'] ?? false,
      );
      await loadAllEvents();
      return event;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      await _eventService.updateEvent(id, data);
      await loadAllEvents();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _eventService.deleteEvent(id);
      await loadAllEvents();
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _eventService.getAdminStats();
  }

  Future<String?> uploadImage(String path) async {
    return await _eventService.uploadImage(path);
  }
}
