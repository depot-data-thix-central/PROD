// lib/presentation/education/pages/certificate_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/education/models/certificate.dart';

class CertificateDetailPage extends StatefulWidget {
  final Certificate certificate;
  const CertificateDetailPage({super.key, required this.certificate});

  @override
  State<CertificateDetailPage> createState() => _CertificateDetailPageState();
}

class _CertificateDetailPageState extends State<CertificateDetailPage> {
  Map<String, dynamic>? _formation;
  bool _loading = true;

  static const _templateColors = {
    'classic_navy': Color(0xFF1E3A5F),
    'modern_minimal': Color(0xFF334155),
    'royal_gold': Color(0xFFB45309),
    'academic_serif': Color(0xFF1E293B),
    'tech_blue': Color(0xFF0369A1),
    'emerald_elite': Color(0xFF047857),
    'crimson_honor': Color(0xFFB91C1C),
    'slate_pro': Color(0xFF475569),
    'ivory_tradition': Color(0xFF78716C),
    'midnight_prestige': Color(0xFF0F172A),
  };

  @override
  void initState() {
    super.initState();
    _loadFormation();
  }

  Future<void> _loadFormation() async {
    try {
      final res = await Supabase.instance.client
          .from('formations')
          .select('''
            title, instructor_name, organized_by, provider,
            certificate_header, certificate_body, certificate_footer,
            certificate_logo_url, certificate_signature_url,
            certificate_signatory_name, certificate_signatory_title,
            certificate_template_id
          ''')
          .eq('id', widget.certificate.formationId)
          .maybeSingle();
      if (mounted) setState(() {
        _formation = res;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _verifyUrl {
    // Adapte à ton domaine GitHub Pages / prod
    return 'https://depot-data-thix-central.github.io/final/#/verify/${widget.certificate.verificationHash}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.certificate;
    final accent = _templateColors[
            c.templateId ?? _formation?['certificate_template_id']] ??
        const Color(0xFF1E3A5F);

    final header = _formation?['certificate_header'] as String? ?? 'certifie que';
    final body = _formation?['certificate_body'] as String? ??
        'a complété avec succès la formation.';
    final footer =
        _formation?['certificate_footer'] as String? ?? 'Fait à Kinshasa';
    final academy = _formation?['instructor_name'] as String? ??
        _formation?['organized_by'] as String? ??
        'THIX Academy';
    final title = _formation?['title'] as String? ??
        c.formationTitle ??
        'Formation';
    final logo = _formation?['certificate_logo_url'] as String?;
    final sign = _formation?['certificate_signature_url'] as String?;
    final signName =
        _formation?['certificate_signatory_name'] as String? ?? academy;
    final signTitle =
        _formation?['certificate_signatory_title'] as String? ?? '';

    final dateStr =
        '${c.issuedAt.day.toString().padLeft(2, '0')}/${c.issuedAt.month.toString().padLeft(2, '0')}/${c.issuedAt.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Certificat',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copier le code de vérification',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: c.verificationHash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hash copié')),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Carte certificat ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (logo != null && logo.isNotEmpty)
                          Image.network(logo, height: 56, fit: BoxFit.contain)
                        else
                          Icon(Icons.workspace_premium_rounded,
                              size: 48, color: accent),
                        const SizedBox(height: 12),
                        Text(
                          academy.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          header,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          c.issuedToName ?? 'Apprenant',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '« $title »',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  if (sign != null && sign.isNotEmpty)
                                    Image.network(sign,
                                        height: 40, fit: BoxFit.contain),
                                  const Divider(height: 16),
                                  Text(signName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  if (signTitle.isNotEmpty)
                                    Text(signTitle,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            QrImageView(
                              data: _verifyUrl,
                              size: 88,
                              backgroundColor: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$footer  ·  $dateStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.serialNumber ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vérification anti-fraude',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          c.verificationHash,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scannez le QR ou ouvrez /verify/${c.verificationHash.substring(0, 12)}…',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
