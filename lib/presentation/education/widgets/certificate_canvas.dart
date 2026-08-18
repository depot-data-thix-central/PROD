// lib/presentation/education/widgets/certificate_canvas.dart
import 'dart:math';
import 'package:flutter/material.dart';

class CertificateData {
  final String academyName;
  final String header;
  final String learnerName;
  final String body;
  final String courseTitle;
  final String footer;
  final String signatoryName;
  final String signatoryTitle;
  final String? logoUrl;
  final String? signatureUrl;
  final String serial;
  final String dateLabel;
  final String templateId;

  const CertificateData({
    required this.academyName,
    required this.header,
    required this.learnerName,
    required this.body,
    required this.courseTitle,
    required this.footer,
    required this.signatoryName,
    required this.signatoryTitle,
    this.logoUrl,
    this.signatureUrl,
    required this.serial,
    required this.dateLabel,
    required this.templateId,
  });
}

/// Style visuel de la mise en page du certificat.
enum _CertLayout { diagonal, curved, ornate, framed }

class CertificateCanvas extends StatelessWidget {
  final CertificateData data;
  final double width;

  const CertificateCanvas({
    super.key,
    required this.data,
    this.width = 360,
  });

  static const templates = <String, _TStyle>{
    'classic_navy': _TStyle(
      name: 'Classic Navy',
      primary: Color(0xFF0B1F3A),
      accent: Color(0xFFC9A227),
      bg: Color(0xFFFFFDF8),
      layout: _CertLayout.diagonal,
    ),
    'royal_gold': _TStyle(
      name: 'Royal Gold',
      primary: Color(0xFF10206B),
      accent: Color(0xFFD4AF37),
      bg: Color(0xFFFFFBF0),
      layout: _CertLayout.curved,
    ),
    'modern_minimal': _TStyle(
      name: 'Modern Minimal',
      primary: Color(0xFF0F172A),
      accent: Color(0xFF64748B),
      bg: Colors.white,
      layout: _CertLayout.framed,
    ),
    'academic_serif': _TStyle(
      name: 'Academic Serif',
      primary: Color(0xFF1E293B),
      accent: Color(0xFFB45309),
      bg: Color(0xFFFAF7F2),
      layout: _CertLayout.ornate,
    ),
    'tech_blue': _TStyle(
      name: 'Tech Blue',
      primary: Color(0xFF0C4A6E),
      accent: Color(0xFF38BDF8),
      bg: Color(0xFFF0F9FF),
      layout: _CertLayout.curved,
    ),
    'emerald_elite': _TStyle(
      name: 'Emerald Elite',
      primary: Color(0xFF064E3B),
      accent: Color(0xFF34D399),
      bg: Color(0xFFECFDF5),
      layout: _CertLayout.ornate,
    ),
    'crimson_honor': _TStyle(
      name: 'Crimson Honor',
      primary: Color(0xFF7F1D1D),
      accent: Color(0xFFFBBF24),
      bg: Color(0xFFFFFBEB),
      layout: _CertLayout.diagonal,
    ),
    'slate_pro': _TStyle(
      name: 'Slate Pro',
      primary: Color(0xFF334155),
      accent: Color(0xFF94A3B8),
      bg: Color(0xFFF8FAFC),
      layout: _CertLayout.framed,
    ),
    'ivory_tradition': _TStyle(
      name: 'Ivory Tradition',
      primary: Color(0xFF44403C),
      accent: Color(0xFFA8A29E),
      bg: Color(0xFFFAFAF9),
      layout: _CertLayout.ornate,
    ),
    'midnight_prestige': _TStyle(
      name: 'Midnight Prestige',
      primary: Color(0xFF020617),
      accent: Color(0xFFE2E8F0),
      bg: Color(0xFF0F172A),
      lightText: true,
      layout: _CertLayout.curved,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = templates[data.templateId] ?? templates['classic_navy']!;
    final h = width * 1.35;

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Cadre double (base commune à tous les styles)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: style.accent, width: 2.5),
                ),
                child: Container(
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: style.primary.withOpacity(style.lightText ? 0.5 : 0.85),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // Décor spécifique au style
            ..._decorFor(style, h),

            // Contenu
            Padding(
              padding: _paddingFor(style.layout),
              child: _buildBody(style),
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _paddingFor(_CertLayout layout) {
    switch (layout) {
      case _CertLayout.curved:
        return const EdgeInsets.fromLTRB(88, 24, 28, 18);
      case _CertLayout.diagonal:
      case _CertLayout.ornate:
      case _CertLayout.framed:
        return const EdgeInsets.fromLTRB(28, 24, 28, 18);
    }
  }

  List<Widget> _decorFor(_TStyle style, double h) {
    switch (style.layout) {
      case _CertLayout.diagonal:
        return [
          Positioned(
            top: 0,
            left: 0,
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _DiagonalCornerPainter(
                fill: style.primary,
                edge: style.accent,
                topLeft: true,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _DiagonalCornerPainter(
                fill: style.primary.withOpacity(0.85),
                edge: style.accent,
                topLeft: false,
              ),
            ),
          ),
        ];

      case _CertLayout.curved:
        return [
          Positioned(
            top: 0,
            left: 0,
            bottom: 0,
            width: width * 0.42,
            child: CustomPaint(
              painter: _WaveBandPainter(fill: style.primary, edge: style.accent),
            ),
          ),
        ];

      case _CertLayout.ornate:
        return [
          ..._corners(style),
          Positioned(
            top: 16,
            right: 16,
            width: 30,
            height: 30,
            child: CustomPaint(painter: _RosettePainter(color: style.accent)),
          ),
        ];

      case _CertLayout.framed:
        return const [];
    }
  }

  Widget _buildBody(_TStyle style) {
    return Column(
      children: [
        // Logo / académie
        if (data.logoUrl != null && data.logoUrl!.isNotEmpty)
          Image.network(data.logoUrl!, height: 36, fit: BoxFit.contain)
        else
          Icon(Icons.workspace_premium, size: 32, color: style.accent),
        const SizedBox(height: 6),
        Text(
          data.academyName.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: style.lightText ? style.accent : style.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'CERTIFICATE',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: style.lightText ? Colors.white : style.primary,
          ),
        ),
        Text(
          'OF COMPLETION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: style.accent,
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 48, height: 2, color: style.accent),
        const SizedBox(height: 10),
        Text(
          data.header,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: style.lightText ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.learnerName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: style.accent,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: 120,
          height: 1,
          color: style.accent.withOpacity(0.5),
        ),
        Text(
          data.body,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            height: 1.35,
            color: style.lightText ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '« ${data.courseTitle} »',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: style.lightText ? Colors.white : style.primary,
          ),
        ),
        const Spacer(),
        // Sceau — rosette pour le style "framed", icône classique sinon
        if (style.layout == _CertLayout.framed) ...[
          SizedBox(
            width: 40,
            height: 40,
            child: CustomPaint(painter: _RosettePainter(color: style.accent)),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: ClipPath(
                  clipper: _RibbonTailClipper(),
                  child: Container(width: 12, height: 20, color: style.primary),
                ),
              ),
              const SizedBox(width: 4),
              Transform.rotate(
                angle: 0.25,
                child: ClipPath(
                  clipper: _RibbonTailClipper(),
                  child: Container(width: 12, height: 20, color: style.primary),
                ),
              ),
            ],
          ),
        ] else
          Icon(Icons.military_tech_rounded, size: 28, color: style.accent),
        const SizedBox(height: 8),
        // Signature + date
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  if (data.signatureUrl != null && data.signatureUrl!.isNotEmpty)
                    Image.network(data.signatureUrl!, height: 28, fit: BoxFit.contain)
                  else
                    Text(
                      '________________',
                      style: TextStyle(
                        color: style.lightText ? Colors.white54 : Colors.black26,
                        fontSize: 10,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    data.signatoryName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: style.lightText ? Colors.white : style.primary,
                    ),
                  ),
                  Text(
                    data.signatoryTitle,
                    style: TextStyle(
                      fontSize: 8,
                      color: style.lightText ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    data.dateLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: style.lightText ? Colors.white : style.primary,
                    ),
                  ),
                  Text(
                    data.footer,
                    style: TextStyle(
                      fontSize: 8,
                      color: style.lightText ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          data.serial,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: style.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Produit par THIX ID CENTRAL',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: style.lightText ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  List<Widget> _corners(_TStyle s) {
    const size = 28.0;
    Widget corner(Alignment a) {
      return Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(
              top: a == Alignment.topLeft || a == Alignment.topRight
                  ? BorderSide(color: s.accent, width: 3)
                  : BorderSide.none,
              bottom: a == Alignment.bottomLeft || a == Alignment.bottomRight
                  ? BorderSide(color: s.accent, width: 3)
                  : BorderSide.none,
              left: a == Alignment.topLeft || a == Alignment.bottomLeft
                  ? BorderSide(color: s.accent, width: 3)
                  : BorderSide.none,
              right: a == Alignment.topRight || a == Alignment.bottomRight
                  ? BorderSide(color: s.accent, width: 3)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }
}

class _TStyle {
  final String name;
  final Color primary;
  final Color accent;
  final Color bg;
  final bool lightText;
  final _CertLayout layout;
  const _TStyle({
    required this.name,
    required this.primary,
    required this.accent,
    required this.bg,
    this.lightText = false,
    required this.layout,
  });
}

// ─── PEINTRES PERSONNALISÉS ────────────────────────────────────────────

/// Triangle de coin (style diagonal, inspiré du certificat navy/or).
class _DiagonalCornerPainter extends CustomPainter {
  final Color fill;
  final Color edge;
  final bool topLeft;
  _DiagonalCornerPainter({required this.fill, required this.edge, required this.topLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fill..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();
    if (topLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), edgePaint);
    } else {
      path.moveTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.lineTo(size.width, 0);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalCornerPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.edge != edge || oldDelegate.topLeft != topLeft;
}

/// Bande courbe latérale (style "curved", inspiré du certificat bleu/or).
class _WaveBandPainter extends CustomPainter {
  final Color fill;
  final Color edge;
  _WaveBandPainter({required this.fill, required this.edge});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.6, 0)
      ..quadraticBezierTo(size.width * 0.15, size.height * 0.5, size.width * 0.6, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = fill);

    final edgePath = Path()
      ..moveTo(size.width * 0.6, 0)
      ..quadraticBezierTo(size.width * 0.15, size.height * 0.5, size.width * 0.6, size.height);

    canvas.drawPath(
      edgePath,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveBandPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.edge != edge;
}

/// Médaillon en forme de rosette (style "framed"/"ornate", inspiré du sceau doré).
class _RosettePainter extends CustomPainter {
  final Color color;
  _RosettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    const points = 12;
    final path = Path();

    for (var i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i;
      final radius = i.isEven ? r : r * 0.75;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(center, r * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RosettePainter oldDelegate) => oldDelegate.color != color;
}

/// Découpe en pointe pour les rubans du sceau (style "framed").
class _RibbonTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height * 0.7)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
