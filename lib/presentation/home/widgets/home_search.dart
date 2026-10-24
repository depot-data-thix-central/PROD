// lib/presentation/home/widgets/home_search.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'home_theme.dart';

const double _kSearchHeight = 50.0;
const double _kButtonSize = 36.0;
const int _kMaxInputLength = 100;

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
    if (_focusNode.hasFocus) HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  void _handleVerify() {
    if (!mounted || widget.isSearching) return;
    HapticFeedback.lightImpact();
    widget.onVerify();
  }

  void _handleSubmitted(String value) {
    if (!mounted || widget.isSearching || value.trim().isEmpty) return;
    _handleVerify();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final focused = _focusNode.hasFocus;

    return Semantics(
      label: l10n.t('home_search_semantics'),
      textField: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _kSearchHeight,
        padding: const EdgeInsets.only(left: 16, right: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(focused ? 0.95 : 0.82),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: focused ? HomeTheme.sky.withOpacity(0.7) : Colors.white,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: HomeTheme.skyDeep.withOpacity(focused ? 0.16 : 0.08),
              blurRadius: focused ? 26 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: focused ? HomeTheme.skyDeep : HomeTheme.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: !widget.isSearching,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSubmitted,
                maxLength: _kMaxInputLength,
                style: ThixPolicy.labelStyle.copyWith(
                  color: HomeTheme.ink,
                  fontSize: 13,
                  fontWeight: ThixPolicy.semiBold,
                  letterSpacing: 0.3,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: l10n.t('home_search_hint'),
                  hintStyle: ThixPolicy.captionStyle.copyWith(
                    color: HomeTheme.inkSoft.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: ThixPolicy.regular,
                  ),
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
              ),
            ),
            _VerifyButton(
              semanticsLabel: l10n.t('home_verify_id'),
              onTap: _handleVerify,
              isLoading: widget.isSearching,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool isLoading;
  const _VerifyButton({required this.semanticsLabel, required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: !isLoading,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: _kButtonSize,
          height: _kButtonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HomeTheme.sky, HomeTheme.skyDeep],
            ),
            boxShadow: [BoxShadow(color: HomeTheme.skyDeep.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_search_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
