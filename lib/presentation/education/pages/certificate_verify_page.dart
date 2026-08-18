// lib/presentation/education/pages/certificate_verify_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CertificateVerifyPage extends StatefulWidget {
  final String hash;
  const CertificateVerifyPage({super.key, required this.hash});

  @override
  State<CertificateVerifyPage> createState() => _CertificateVerifyPageState();
}

class _CertificateVerifyPageState extends State<CertificateVerifyPage> {
  bool _loading = true;
  Map<String, dynamic>? _cert;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final res = await Supabase.instance.client
          .from('certificates')
          .select('''
            id, issued_at, serial_number, issued_to_name, verification_hash,
            formation:formations(title, instructor_name)
          ''')
          .eq('verification_hash', widget.hash)
          .maybeSingle();

      if (!mounted) return;
      if (res == null) {
        setState(() {
          _error = 'Aucun certificat trouvé pour ce code.';
          _loading = false;
        });
      } else {
        setState(() {
          _cert = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de vérification : $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _cert != null && _error == null;
    final formation = _cert?['formation'];
    final title = formation is Map ? formation['title'] : null;
    final academy = formation is Map ? formation['instructor_name'] : null;
    final issued = _cert?['issued_at'] != null
        ? DateTime.tryParse(_cert!['issued_at'].toString())
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Vérification certificat',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: valid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        valid
                            ? Icons.verified_rounded
                            : Icons.gpp_bad_rounded,
                        size: 72,
                        color: valid
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        valid
                            ? 'Certificat authentique'
                            : 'Certificat invalide',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: valid
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (valid) ...[
                        _row('Titulaire',
                            _cert!['issued_to_name'] ?? '—'),
                        _row('Formation', title?.toString() ?? '—'),
                        _row('Académie', academy?.toString() ?? '—'),
                        _row(
                          'Délivré le',
                          issued != null
                              ? '\( {issued.day}/ \){issued.month}/${issued.year}'
                              : '—',
                        ),
                        _row('N° série',
                            _cert!['serial_number'] ?? '—'),
                      ] else
                        Text(
                          _error ?? 'Code inconnu',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
