import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/core/extensions/context_ext.dart';

class HeroCarousel extends StatefulWidget {
  final Color domainColor;
  final String userName;
  
  const HeroCarousel({
    super.key, 
    required this.domainColor, 
    required this.userName,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _controller = PageController(viewportFraction: 1);
  Timer? _timer;
  int _currentIndex = 0;
  
  static const int _slideCount = 3;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _currentIndex = (_currentIndex + 1) % _slideCount;
      _controller.animateToPage(
        _currentIndex, 
        duration: const Duration(milliseconds: 450), 
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() { 
    _timer?.cancel(); 
    _controller.dispose(); 
    super.dispose(); 
  }

  List<Map<String, dynamic>> _buildSlides(BuildContext context) {
    final l10n = context.l10n;
    return [
      {
        "title": l10n.t('reservation_book'),
        "subtitle": l10n.t('reservation_transport'),
        "icon": Icons.directions_bus_filled_rounded, 
        "image": "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=1200&q=80",
      },
      {
        "title": l10n.t('ticket_vip'),
        "subtitle": l10n.t('certification_tier_premium'),
        "icon": Icons.star_rounded, 
        "image": "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=1200&q=80",
      },
      {
        "title": l10n.t('sos_banner_safe_title'),
        "subtitle": l10n.t('sos_banner_safe_subtitle'),
        "icon": Icons.shield_outlined, 
        "image": "https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=1200&q=80",
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final slides = _buildSlides(context);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThixPolicy.rXl), 
      child: SizedBox(
        height: 172, 
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller, 
              itemCount: slides.length, 
              onPageChanged: (i) => setState(() => _currentIndex = i), 
              itemBuilder: (_, i) => _buildSlide(slides[i]),
            ),
            Positioned(
              left: 0, 
              right: 0, 
              bottom: ThixPolicy.s10, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: List.generate(
                  slides.length, 
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300), 
                    margin: EdgeInsets.symmetric(horizontal: ThixPolicy.s2), 
                    width: i == _currentIndex ? 20 : 6, 
                    height: 4, 
                    decoration: BoxDecoration(
                      color: i == _currentIndex ? Colors.white : Colors.white54, 
                      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    return Stack(
      fit: StackFit.expand, 
      children: [
        CachedNetworkImage(
          imageUrl: slide["image"] as String, 
          fit: BoxFit.cover, 
          placeholder: (_, __) => Container(color: widget.domainColor.withValues(alpha: 0.3)), 
          errorWidget: (_, __, ___) => Container(color: widget.domainColor),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, 
              end: Alignment.centerRight, 
              colors: [
                widget.domainColor.withValues(alpha: 0.92), 
                widget.domainColor.withValues(alpha: 0.4), 
                Colors.transparent,
              ], 
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(ThixPolicy.s16), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Icon(slide["icon"] as IconData, color: Colors.white, size: 24),
              SizedBox(height: ThixPolicy.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220), 
                child: Text(
                  slide["title"] as String, 
                  style: ThixPolicy.h2Style.copyWith(color: Colors.white, height: 1.15), 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: ThixPolicy.s4),
              Text(
                slide["subtitle"] as String, 
                style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
