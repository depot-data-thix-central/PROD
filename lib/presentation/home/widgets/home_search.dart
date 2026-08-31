// lib/presentation/home/widgets/home_search.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kSearchHeight = 44.0;
const double _kSearchBorderRadius = 14.0;
const double _kButtonSize = 32.0;
const double _kButtonBorderRadius = 10.0;
const int _kMaxInputLength = 100;

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomeSearch extends StatefulWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onVerify;

  const HomeSearch({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onVerify,
  });

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      HapticFeedback.selectionClick();
      debugPrint('[HomeSearch] 🔍 Search focused');
    }
  }

  void _handleScanner() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[HomeSearch] 📷 Scanner tap');
    context.push('/scanner_activation');
  }

  void _handleVerify() {
    if (!mounted || widget.isSearching) return;
    HapticFeedback.lightImpact();
    debugPrint('[HomeSearch] ✓ Verify tap');
    widget.onVerify();
  }

  void _handleSubmitted(String value) {
    if (!mounted || widget.isSearching) return;
    if (value.trim().isEmpty) return;
    _handleVerify();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.t('home_search_semantics'),
      textField: true,
      child: Container(
        height: _kSearchHeight,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(_kSearchBorderRadius),
          border: Border.all(
            color: _focusNode.hasFocus 
                ? ThixPolicy.primary.withOpacity(0.3)
                : ThixPolicy.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: ThixPolicy.textSecondary,
            ),
            const SizedBox(width: 8),

            // Champ de recherche
            Expanded(
              child: _SearchField(
                controller: widget.controller,
                focusNode: _focusNode,
                isSearching: widget.isSearching,
                hintText: l10n.t('home_search_hint'),
                onSubmitted: _handleSubmitted,
              ),
            ),

            // Bouton Scanner
            _ActionButton(
              icon: Icons.qr_code_scanner_rounded,
              color: ThixPolicy.textMain,
              backgroundColor: ThixPolicy.surfaceSoft,
              borderColor: ThixPolicy.border,
              semanticsLabel: l10n.t('home_scan_qr'),
              onTap: _handleScanner,
              isDisabled: widget.isSearching,
            ),

            const SizedBox(width: 6),

            // Bouton Vérifier
            _ActionButton(
              icon: Icons.person_search_rounded,
              color: ThixPolicy.primary,
              backgroundColor: ThixPolicy.tint,
              borderColor: ThixPolicy.primary.withOpacity(0.1),
              semanticsLabel: l10n.t('home_verify_id'),
              onTap: _handleVerify,
              isDisabled: widget.isSearching,
              isLoading: widget.isSearching,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final String hintText;
  final ValueChanged<String> onSubmitted;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.hintText,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !isSearching,
      textAlignVertical: TextAlignVertical.center,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      maxLength: _kMaxInputLength,
      style: ThixPolicy.labelStyle.copyWith(
        color: ThixPolicy.textMain,
        fontSize: 12.5,
        fontWeight: ThixPolicy.semiBold,
        letterSpacing: 0.3,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: Colors.transparent,
        filled: false,
        hintText: hintText,
        hintStyle: ThixPolicy.captionStyle.copyWith(
          color: ThixPolicy.textSecondary,
          fontSize: 11.5,
          fontWeight: ThixPolicy.regular,
        ),
        contentPadding: EdgeInsets.zero,
        counterText: '', // Masque le compteur maxLength
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.semanticsLabel,
    required this.onTap,
    this.isDisabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: !isDisabled,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: _kButtonSize,
            width: _kButtonSize,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(_kButtonBorderRadius),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 15),
          ),
        ),
      ),
    );
  }
}
