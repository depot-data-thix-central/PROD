import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import '../../core/theme/thix_design_policy.dart';

class VaultAppBar extends ConsumerWidget {
  final VoidCallback onSearch;
  final ValueChanged<String> onSearchChanged;
  final String searchQuery;

  const VaultAppBar({
    super.key,
    required this.onSearch,
    required this.onSearchChanged,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: ThixPolicy.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _BackButton(onTap: () {
                    if (auth.isAuthenticated) {
                      final t = auth.currentUser?.accountType;
                      context.go(t == AccountType.enterprise
                          ? AppRoutes.enterpriseDashboard
                          : AppRoutes.userDashboard);
                    } else {
                      context.go(AppRoutes.home);
                    }
                  }),
                  const SizedBox(width: 12),
                  const _VaultLogo(),
                ],
              ),
              Row(
                children: [
                  const _SecurityBadge(),
                  const SizedBox(width: 12),
                  _SearchButton(onTap: onSearch),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar
          _SearchField(
            onChanged: onSearchChanged,
            initialValue: searchQuery,
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: ThixPolicy.textMain,
          size: 18,
        ),
      ),
    );
  }
}

class _VaultLogo extends StatelessWidget {
  const _VaultLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THIX VAULT',
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Coffre-fort sécurisé',
              style: TextStyle(
                color: ThixPolicy.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ThixPolicy.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: ThixPolicy.success, size: 14),
          const SizedBox(width: 6),
          Text(
            'CHIFFRÉ E2E',
            style: TextStyle(
              color: ThixPolicy.success,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.search_rounded,
          color: ThixPolicy.textMain,
          size: 20,
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String initialValue;

  const _SearchField({required this.onChanged, required this.initialValue});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: TextStyle(
          color: ThixPolicy.textMain,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher par titre, type ou ID...',
          hintStyle: TextStyle(
            color: ThixPolicy.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.filter_list_rounded,
            size: 20,
            color: ThixPolicy.textSecondary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
