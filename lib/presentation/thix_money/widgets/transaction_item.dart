// lib/presentation/thix_money/widgets/transaction_item.dart
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/formatter.dart';

class TransactionItem extends StatelessWidget {
  final TransactionModel tx;
  const TransactionItem({super.key, required this.tx});
  @override
  Widget build(BuildContext context) {
    final isSuccess = tx.statut == 'succes' || tx.statut == 'recu';
    final isPending = tx.statut == 'pending';
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _getColor().withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(_getIcon(), color: _getColor(), size: 20),
      ),
      title: Text('${tx.actionDetail} • ${tx.devise}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ThixFormatter.formatPhone(tx.phoneDest?? tx.phone), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(ThixFormatter.formatDate(tx.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${tx.type == 'C2B'? '+' : '-'} ${ThixFormatter.formatAmount(tx.montant, tx.devise)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: tx.type == 'C2B'? Colors.green : Colors.black87)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: isSuccess? Colors.green.withOpacity(0.1) : isPending? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(tx.statut, style: TextStyle(fontSize: 9, color: isSuccess? Colors.green : isPending? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }

  Color _getColor() {
    if (tx.actionDetail == 'RECHARGE') return Colors.green;
    if (tx.actionDetail == 'ENVOI') return Colors.blue;
    return Colors.orange;
  }

  IconData _getIcon() {
    if (tx.actionDetail == 'RECHARGE') return Icons.add_circle;
    if (tx.actionDetail == 'ENVOI') return Icons.send;
    return Icons.atm;
  }
}
