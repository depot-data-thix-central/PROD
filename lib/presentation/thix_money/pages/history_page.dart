// lib/presentation/thix_money/pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_item.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(transactionProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historique - THIX MONEY')),
      body: state.isLoading && state.items.isEmpty
         ? const Center(child: CircularProgressIndicator())
          : state.error!= null && state.items.isEmpty
             ? Center(child: Text('Erreur: ${state.error}'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(transactionProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: state.items.length + (state.hasMore? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == state.items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      return TransactionItem(tx: state.items[i]);
                    },
                  ),
                ),
    );
  }
}
