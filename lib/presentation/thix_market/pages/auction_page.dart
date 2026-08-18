import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/live/live_auction_widget.dart';

class AuctionPage extends StatefulWidget {
  final String auctionId;

  const AuctionPage({super.key, required this.auctionId});

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Enchère en direct',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: LiveAuctionWidget(
        auctionId: widget.auctionId,
        onBidPlaced: (bidAmount) {
          // Optionnel : afficher un snackbar lors d'une nouvelle enchère
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enchère de $bidAmount FCFA placée !'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}
