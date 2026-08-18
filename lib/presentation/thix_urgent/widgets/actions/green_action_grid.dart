// lib/presentation/thix_urgent/widgets/actions/green_action_grid.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/urgent_controller.dart';
import 'green_action_button.dart';
import '../sheets/denoncer_sheet.dart';
import '../sheets/accident_sheet.dart';
import '../sheets/police_sheet.dart';
import '../sheets/agression_sheet.dart';

class GreenActionGrid extends StatelessWidget {
  const GreenActionGrid({super.key});

  void _openSheet(BuildContext context, EmergencyType type) {
    final sheet = switch (type) {
      EmergencyType.denoncer => const DenoncerSheet(),
      EmergencyType.accident => const AccidentSheet(),
      EmergencyType.police => const PoliceSheet(),
      EmergencyType.personne => const AgressionSheet(),
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UrgentController>(
      builder: (_, ctrl, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            GreenActionButton(
              icon: Icons.report_problem_rounded,
              label: 'DÉNONCER',
              type: EmergencyType.denoncer,
              isSelected: ctrl.selectedType == EmergencyType.denoncer,
              onTap: () {
                ctrl.selectType(EmergencyType.denoncer);
                _openSheet(context, EmergencyType.denoncer);
              },
            ),
            const SizedBox(width: 10),
            GreenActionButton(
              icon: Icons.car_crash_rounded,
              label: 'ACCIDENT',
              type: EmergencyType.accident,
              isSelected: ctrl.selectedType == EmergencyType.accident,
              onTap: () {
                ctrl.selectType(EmergencyType.accident);
                _openSheet(context, EmergencyType.accident);
              },
            ),
            const SizedBox(width: 10),
            GreenActionButton(
              icon: Icons.local_police_rounded,
              label: 'POLICE',
              type: EmergencyType.police,
              isSelected: ctrl.selectedType == EmergencyType.police,
              onTap: () {
                ctrl.selectType(EmergencyType.police);
                _openSheet(context, EmergencyType.police);
              },
            ),
            const SizedBox(width: 10),
            GreenActionButton(
              icon: Icons.person_search_rounded,
              label: 'PERSONNE',
              type: EmergencyType.personne,
              isSelected: ctrl.selectedType == EmergencyType.personne,
              onTap: () {
                ctrl.selectType(EmergencyType.personne);
                _openSheet(context, EmergencyType.personne);
              },
            ),
          ],
        ),
      ),
    );
  }
}
