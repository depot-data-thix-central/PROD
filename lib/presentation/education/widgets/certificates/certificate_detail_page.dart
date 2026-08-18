// lib/presentation/education/pages/certificate_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/education/models/certificate.dart';
import 'package:thix_id/presentation/education/widgets/certificate_canvas.dart';

class CertificateDetailPage extends StatefulWidget {
  final Certificate certificate;

  const CertificateDetailPage({super.key, required this.certificate});

  @override
  State<CertificateDetailPage> createState() => _CertificateDetailPageState();
}

class _CertificateDetailPageState extends State<CertificateDetailPage> {
  Map<String, dynamic>? _formation;
  bool _loading = true;

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
      if (mounted) {
        setState(() {
          _formation = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _verifyPath =>
      '/verify/${widget.certificate.verificationHash}';

  String get _verifyUrl {
    // Adapte à ton domaine de prod / GitHub Pages
    return 'https://depot-data-thix-central.github.io/final/#$_verifyPath';
  }

  CertificateData _toCanvasData() {
    final c = widget.certificate;
    final f = _formation;
    final academy = f?['instructor_name'] as String? ??
        f?['organized_by'] as String? ??
        f?['provider'] as String? ??
        'THIX Academy';
    final issued = c.issuedAt;
    final dateStr =
        '${issued.day.toString().padLeft(2, '0')}/${issued.month.toString().padLeft(2, '0')}/${issued.year}';


    return CertificateData(
      academyName: academy,
      header: f?['certificate_header'] as String? ?? 'certifie que',
      learnerName: c.issuedToName ?? 'Apprenant',
      body: f?['certificate_body'] as String? ??
          'a complété avec succès l\'intégralité de la formation.',
      courseTitle: f?['title'] as String? ??
          c.formationTitle ??
          'Formation',
      footer: f?['certificate_footer'] as String? ?? 'Fait à Kinshasa',
      signatoryName:
          f?['certificate_signatory_name'] as String? ?? academy,
      signatoryTitle:
          f?['certificate_signatory_title'] as String? ?? '',
      logoUrl: f?['certificate_logo_url'] as String?,
      signatureUrl: f?['certificate_signature_url'] as String?,
      serial: c.serialNumber ?? '—',
      dateLabel: dateStr,
      templateId: c.templateId ??
          f?['certificate_template_id'] as String? ??
          'classic_navy',
    );
  }

  void _share() {
    Share.share(
      'Mon certificat THIX\n'
      '${widget.certificate.issuedToName ?? ""}\n'
      'Vérifier : $_verifyUrl\n'
      'N° ${widget.certificate.serialNumber ?? widget.certificate.id}',
      subject: 'Certificat de formation',
    );
  }

  void _copyHash() {
    Clipboard.setData(
      ClipboardData(text: widget.certificate.verificationHash),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code de vérification copié')),
    );
  }

  void _openVerify() {
    context.push(_verifyPath);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.certificate;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Certificat',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copier le hash',
            onPressed: _copyHash,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                children: [
                  // ── Canvas pro ──
                  Center(
                    child: CertificateCanvas(
                      data: _toCanvasData(),
                      width: w - 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Infos ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Détails',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _row('Titulaire', c.issuedToName ?? '—'),
                        _row(
                          'Formation',
                          _formation?['title']?.toString() ??
                              c.formationTitle ??
                              c.formationId,
                        ),
                        _row(
                          'N° série',
                          c.serialNumber ?? '—',
                        ),
                        _row(
                          'Émis le',
                          '\( {c.issuedAt.day}/ \){c.issuedAt.month}/${c.issuedAt.year}',
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Code anti-fraude',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          c.verificationHash,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openVerify,
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text(
                              'Vérifier l\'authenticité',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D6CDF),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Produit par THIX ID CENTRAL',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
