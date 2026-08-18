import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';

class ShareShopQr extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String? shopLogo;
  final String? shopUrl;

  const ShareShopQr({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopLogo,
    this.shopUrl,
  });

  @override
  State<ShareShopQr> createState() => _ShareShopQrState();
}

class _ShareShopQrState extends State<ShareShopQr> {
  bool _isNfcSupported = false;
  String? _nfcStatus;

  @override
  void initState() {
    super.initState();
    _checkNfcCapability();
  }

  Future<void> _checkNfcCapability() async {
    final isAvailable = await NfcManager.instance.isAvailable();

    if (!mounted) return;

    setState(() {
      _isNfcSupported = isAvailable;
      _nfcStatus = isAvailable ? 'NFC disponible' : 'NFC non disponible';
    });
  }

  Future<void> _writeToNfc() async {
    if (!_isNfcSupported) return;

    final shopUrl = widget.shopUrl ?? 'thix://shop/${widget.shopId}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Écriture NFC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Approchez une étiquette NFC'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
      },
      onDiscovered: (NfcTag tag) async {
        await NfcManager.instance.stopSession();

        if (!mounted) return;

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC détecté')),
        );
      },
    );
  }

  Future<void> _shareViaNfc() async {
    if (!_isNfcSupported) return;

    final shopUrl = widget.shopUrl ?? 'thix://shop/${widget.shopId}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Partage NFC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Approchez deux téléphones'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );

    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
      },
      onDiscovered: (NfcTag tag) async {
        await NfcManager.instance.stopSession();

        if (!mounted) return;

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC partagé')),
        );
      },
    );
  }

  Future<void> _shareViaSocialMedia() async {
    final String shareText = '''
Découvrez ${widget.shopName} sur THIX Market !
${widget.shopUrl ?? 'https://thix.com/shop/${widget.shopId}'}

#THIXMarket #Shopping
''';

    await Share.share(
      shareText,
      subject: 'Boutique ${widget.shopName}',
    );
  }

  Future<void> _shareLink() async {
    final shopUrl =
        widget.shopUrl ?? 'https://thix.com/shop/${widget.shopId}';

    await Share.share(
      shopUrl,
      subject: widget.shopName,
    );
  }

  void _saveQrCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR sauvegardé (simulation)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopUrl =
        widget.shopUrl ?? 'https://thix.com/shop/${widget.shopId}';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partager ma boutique',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          /// 🔥 QR CODE
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: shopUrl,
                    version: QrVersions.auto,
                    size: 200,
                    embeddedImage: widget.shopLogo != null
                        ? NetworkImage(widget.shopLogo!)
                        : null,
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(40, 40),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _saveQrCode,
                        icon: const Icon(Icons.download),
                      ),
                      IconButton(
                        onPressed: _shareLink,
                        icon: const Icon(Icons.share),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          /// SHARE BUTTONS
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _btn(Icons.share, "Social", Colors.blue, _shareViaSocialMedia),
              _btn(Icons.link, "Lien", Colors.green, _shareLink),
              if (_isNfcSupported)
                _btn(Icons.nfc, "NFC", Colors.purple, _shareViaNfc),
              if (_isNfcSupported)
                _btn(Icons.storage, "Écrire NFC", Colors.orange, _writeToNfc),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
