import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/bus_search_provider.dart';

class PassengerPickerSheet extends ConsumerStatefulWidget {
  const PassengerPickerSheet({super.key});

  @override
  ConsumerState<PassengerPickerSheet> createState() => _PassengerPickerSheetState();
}

class _PassengerPickerSheetState extends ConsumerState<PassengerPickerSheet> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Passengers', style: ThixPolicy.h3Style),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _count > 1 ? () => setState(() => _count--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('$_count', style: ThixPolicy.h2Style),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _count < 10 ? () => setState(() => _count++) : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(busSearchProvider.notifier).setPassengers(_count);
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
