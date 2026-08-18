import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/nav.dart';

class ThixIdStartPage extends StatefulWidget {
  const ThixIdStartPage({super.key});

  @override
  State<ThixIdStartPage> createState() => _ThixIdStartPageState();
}

class _ThixIdStartPageState extends State<ThixIdStartPage> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // Déclenche l'animation d'apparition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _revealed = true);
    });
    
    // Lance le minuteur simple
    _startTimer();
  }

  void _startTimer() async {
    // Attendre 2.5 secondes
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      // On demande d'aller à l'accueil.
      // C'est votre app_router.dart qui va intercepter cette demande 
      // et rediriger vers le Login si l'utilisateur n'est pas connecté !
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // Un fond simple avec un dégradé, sans éléments qui débordent (plus de barre blanche !)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1A3A),
              Color(0xFF0B3B8F),
              Color(0xFF0E2C63),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              opacity: _revealed ? 1 : 0,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  
                  // Le Logo
                  const _LogoPanel(),
                  
                  const SizedBox(height: 28),
                  
                  Text(
                    'THIX CENTRAL',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'une identité vérifiée, avenir de confiance',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Indicateur de chargement simple
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFEAF2FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chargement...',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Signature
                  Text(
                    'BY SONATHIX GROUP',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                      letterSpacing: 2.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoPanel extends StatelessWidget {
  const _LogoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Image.asset(
        'assets/images/sonathix_logo.png',
        height: 84,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 46, color: Colors.white.withValues(alpha: 0.95)),
            const SizedBox(height: 8),
            Text('SONATHIX', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          ],
        ),
      ),
    );
  }
}
