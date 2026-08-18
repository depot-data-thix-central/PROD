// lib/presentation/thix_urgent/providers/thix_urgent_providers.dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter/material.dart';
import '../controllers/urgent_controller.dart';
import '../controllers/permission_controller.dart';
import '../controllers/recording_controller.dart';
import '../services/sirene_service.dart';

class ThixUrgentProviders {
  static List<SingleChildWidget> get all => [
    ChangeNotifierProvider<UrgentController>(create: (_) => UrgentController()),
    ChangeNotifierProvider<PermissionController>(create: (_) => PermissionController()),
    ChangeNotifierProvider<RecordingController>(create: (_) => RecordingController()),
    Provider<SireneService>(create: (_) => SireneService(), dispose: (_, s) => s.stop()),
  ];

  static Widget wrap(Widget child) {
    return MultiProvider(providers: all, child: child);
  }
}
