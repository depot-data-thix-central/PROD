import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:thix_id/theme.dart';

/// A read-only text field that opens a calendar (`showDatePicker`) and writes
/// the selected date in ISO format: `YYYY-MM-DD`.
///
/// This prevents invalid values like `2009` being sent to Supabase `date`
/// columns.
class DatePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;

  const DatePickerField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.hintText,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
    this.allowClear = true,
  });

  static DateTime? _tryParseIsoDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    try {
      // DateTime.parse supports `YYYY-MM-DD`.
      final dt = DateTime.parse(v);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }

  static String _toIsoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDate(BuildContext context) async {
    if (!enabled) return;
    final now = DateTime.now();
    final initial = _tryParseIsoDate(controller.text) ?? DateTime(now.year, now.month, now.day);
    final min = firstDate ?? DateTime(1900, 1, 1);
    final max = lastDate ?? DateTime(now.year + 30, 12, 31);
    final safeInitial = initial.isBefore(min)
        ? min
        : (initial.isAfter(max)
            ? max
            : initial);

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: safeInitial,
        firstDate: min,
        lastDate: max,
        helpText: labelText,
        cancelText: 'Annuler',
        confirmText: 'OK',
      );
      if (picked == null) return;
      controller.text = _toIsoDate(picked);
    } catch (e) {
      debugPrint('DatePickerField: showDatePicker failed err=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = controller.text.trim().isNotEmpty;
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: () => _pickDate(context),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText ?? 'YYYY-MM-DD',
        prefixIcon: Icon(prefixIcon),
        suffixIcon: allowClear && enabled && hasValue
            ? IconButton(
                tooltip: 'Effacer',
                onPressed: () => controller.clear(),
                icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
              )
            : const Icon(Icons.calendar_month_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}
