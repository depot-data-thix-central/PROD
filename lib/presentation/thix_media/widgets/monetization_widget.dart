import 'package:flutter/material.dart';
import '../utils/create_post_constants.dart';
import '../utils/validators.dart';

class MonetizationWidget extends StatefulWidget {
  final bool isPaid;
  final String priceText;
  final ValueChanged<bool> onPaidChanged;
  final ValueChanged<String> onPriceChanged;

  const MonetizationWidget({
    super.key,
    required this.isPaid,
    required this.priceText,
    required this.onPaidChanged,
    required this.onPriceChanged,
  });

  @override
  State<MonetizationWidget> createState() => _MonetizationWidgetState();
}

class _MonetizationWidgetState extends State<MonetizationWidget> {
  late TextEditingController _priceController;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.priceText);
  }

  @override
  void didUpdateWidget(MonetizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.priceText != oldWidget.priceText) {
      _priceController.text = widget.priceText;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _validatePrice(String value) {
    final error = CreatePostValidators.validatePrice(value, widget.isPaid);
    setState(() => _priceError = error);
    widget.onPriceChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Contenu Premium',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: widget.isPaid,
                activeColor: Colors.white,
                activeTrackColor: CreatePostColors.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                inactiveThumbColor: Colors.white54,
                onChanged: (val) {
                  widget.onPaidChanged(val);
                  if (!val) {
                    _priceController.clear();
                    setState(() => _priceError = null);
                    widget.onPriceChanged('');
                  }
                },
              ),
            ],
          ),
          if (widget.isPaid) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              onChanged: _validatePrice,
              decoration: InputDecoration(
                labelText: 'Prix en USD',
                labelStyle: const TextStyle(color: CreatePostColors.textMuted, fontSize: 14),
                errorText: _priceError,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.white54, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CreatePostColors.danger),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
