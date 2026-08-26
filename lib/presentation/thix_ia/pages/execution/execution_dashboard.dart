import 'package:flutter/material.dart';
import 'execution_dashboard_final.dart';

// Wrapper pour compatibilité avec ton ProjectDetailPage
class ExecutionDashboard extends StatelessWidget {
  const ExecutionDashboard({super.key, required this.projectCode});
  final String projectCode;

  @override
  Widget build(BuildContext context) {
    return ExecutionDashboardFinal(
      projectCode: projectCode,
      projectName: projectCode, // Le nom sera récupéré via provider dans la V2
    );
  }
}
