// lib/presentation/thix_money/pages/scanner_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../services/qr_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_handled) return;
    final raw = cap.barcodes.first.rawValue;
    if (raw == null) return;
    _handled = true;
    await _controller.stop();

    final data = QrService.decodeThixQr(raw);
    if (data == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR THIX invalide')));
      _handled = false;
      await _controller.start();
      return;
    }

    // Vérifie en base que thix_id existe
    if (data['thix_id']!= null) {
      final exists = await Supabase.instance.client.from('profiles').select('display_name').eq('thix_id', data['thix_id']).maybeSingle();
      if (exists == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID non trouvé en base'), backgroundColor: Colors.red));
        _handled = false;
        await _controller.start();
        return;
      }
    }

    if (!mounted) return;
    context.pushReplacement('/thix-money/send', extra: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scanner THIX ID'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Align(alignment: Alignment.bottomCenter, child: Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Text('Placez le QR code THIX ID dans le cadre. Vérification automatique en base.', textAlign: TextAlign.center))),
      ]),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
