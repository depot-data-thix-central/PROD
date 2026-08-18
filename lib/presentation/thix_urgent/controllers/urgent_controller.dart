import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

enum EmergencyType { denoncer, accident, police, personne }

class UrgentController extends ChangeNotifier {
  EmergencyType selectedType = EmergencyType.police;
  bool isAlerting = false;
  bool sireneActive = true;
  List<Map<String,dynamic>> gardiens = []; // tes contacts de secours
  String criseId = '';

  final supabase = Supabase.instance.client;

  void selectType(EmergencyType t) {
    selectedType = t;
    notifyListeners();
  }

  Future<void> loadGardiens() async {
    final user = supabase.auth.currentUser;
    if(user==null) return;
    // tu peux lier à ta table contacts existante
    final res = await supabase.from('emergency_contacts_notified')
      .select().eq('alert_id', '').limit(1); // vide pour l'instant
    gardiens = [
      {'name': 'Gardien 1', 'thixId': 'THIX-...'},
      {'name': 'Maman', 'thixId': 'THIX-...'},
    ];
    notifyListeners();
  }

  Future<bool> declencherAlerte() async {
    try {
      isAlerting = true;
      notifyListeners();
      
      final pos = await Geolocator.getCurrentPosition();
      final user = supabase.auth.currentUser;
      
      final alert = await supabase.from('emergency_alerts').insert({
        'user_id': user!.id,
        'type': selectedType.name,
        'status': 'active',
        'is_sirene': sireneActive,
        'is_live': true,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'description': 'Alerte ${selectedType.name} depuis THIX URGENT',
      }).select().single();
      
      criseId = alert['id'];
      
      await supabase.from('emergency_locations').insert({
        'alert_id': criseId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
      });
      
      isAlerting = false;
      notifyListeners();
      return true;
    } catch(e) {
      debugPrint('Erreur alerte: $e');
      isAlerting = false;
      notifyListeners();
      return false;
    }
  }
}
