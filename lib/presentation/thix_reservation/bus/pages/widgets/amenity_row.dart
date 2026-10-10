import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class AmenityRow extends StatefulWidget {
  const AmenityRow({super.key});
  @override
  State<AmenityRow> createState() => _AmenityRowState();
}

class _AmenityRowState extends State<AmenityRow> {
  static const _fallback = [
    {"label": "Sièges", "icon_name": "seat"},
    {"label": "Wi-Fi", "icon_name": "wifi"},
    {"label": "Clim", "icon_name": "ac"},
    {"label": "Bagages", "icon_name": "luggage"},
    {"label": "Sécurité", "icon_name": "security"},
  ];

  IconData _iconFrom(String? n) {
    switch (n) {
      case 'wifi': return Icons.wifi_rounded;
      case 'ac': return Icons.ac_unit_rounded;
      case 'luggage': return Icons.work_rounded;
      case 'seat': return Icons.airline_seat_recline_extra_rounded;
      case 'security': return Icons.verified_user_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: Supabase.instance.client.from('bus_amenities').select().eq('is_active', true).limit(5), builder: (ctx, snap) {
      List<Map<String, dynamic>> items;
      if (snap.hasData && (snap.data as List).isNotEmpty) {
        items = List<Map<String, dynamic>>.from(snap.data as List);
      } else {
        items = _fallback.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return Container(padding: EdgeInsets.symmetric(vertical: ThixPolicy.s16, horizontal: ThixPolicy.s8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: items.map((a) => Column(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)), child: Icon(_iconFrom(a['icon_name'] as String?), size: 18, color: ThixPolicy.primary)), SizedBox(height: ThixPolicy.s6), Text(a['label'] as String, textAlign: TextAlign.center, style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain))])).toList()));
    });
  }
}
