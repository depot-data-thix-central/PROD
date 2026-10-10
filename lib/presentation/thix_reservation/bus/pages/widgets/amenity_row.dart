import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

class AmenityRow extends StatefulWidget {
  const AmenityRow({super.key});

  @override
  State<AmenityRow> createState() => _AmenityRowState();
}

class _AmenityRowState extends State<AmenityRow> {
  
  /// Helper de traduction tolérant.
  /// Si la clé n'existe pas encore dans le dictionnaire, `l10n.t()` retourne la clé elle-même.
  /// Cette méthode détecte ce cas et retourne le texte de secours (fallback) pour ne pas casser l'UI.
  String _t(BuildContext context, String key, String fallback) {
    final translated = context.l10n.t(key);
    return translated == key ? fallback : translated;
  }

  List<Map<String, dynamic>> _getFallbackItems(BuildContext context) {
    return [
      {"label": _t(context, 'admin_action_seats', 'Sièges'), "icon_name": "seat"},
      {"label": _t(context, 'amenity_wifi', 'Wi-Fi'), "icon_name": "wifi"},
      {"label": _t(context, 'amenity_ac', 'Clim'), "icon_name": "ac"},
      {"label": _t(context, 'amenity_luggage', 'Bagages'), "icon_name": "luggage"},
      {"label": _t(context, 'settings_security', 'Sécurité'), "icon_name": "security"},
    ];
  }

  IconData _iconFrom(String? name) {
    switch (name) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'luggage':
        return Icons.work_rounded;
      case 'seat':
        return Icons.airline_seat_recline_extra_rounded;
      case 'security':
        return Icons.verified_user_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Supabase.instance.client
          .from('bus_amenities')
          .select()
          .eq('is_active', true)
          .limit(5),
      builder: (ctx, snap) {
        List<Map<String, dynamic>> items;
        
        if (snap.hasData && (snap.data as List).isNotEmpty) {
          items = List<Map<String, dynamic>>.from(snap.data as List);
        } else {
          // Utilisation du contexte du builder pour la localisation
          items = _getFallbackItems(ctx); 
        }

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: ThixPolicy.s16, 
            horizontal: ThixPolicy.s8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((amenity) {
              final iconName = amenity['icon_name'] as String?;
              final label = amenity['label'] as String;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ThixPolicy.tint,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: Icon(
                      _iconFrom(iconName),
                      size: 18,
                      color: ThixPolicy.primary,
                    ),
                  ),
                  SizedBox(height: ThixPolicy.s6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.microStyle.copyWith(
                      fontWeight: ThixPolicy.semiBold,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
