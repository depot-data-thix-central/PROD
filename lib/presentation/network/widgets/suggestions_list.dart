import 'package:flutter/material.dart';
import 'package:thix_id/models/network_connection.dart';

class SuggestionsList extends StatefulWidget {
  final List<NetworkConnection> suggestions;
  final Future<void> Function(String) onConnect;
  const SuggestionsList({super.key, required this.suggestions, required this.onConnect});
  @override State<SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<SuggestionsList> {
  final Set<String> _connecting = {};

  Future<void> _handle(String id) async {
    if (_connecting.contains(id)) return;
    setState(() => _connecting.add(id));
    try { await widget.onConnect(id); } finally { if (mounted) setState(() => _connecting.remove(id)); }
  }

  Widget _avatar(NetworkConnection c) {
    final hasImg = c.avatar!= null && c.avatar!.trim().isNotEmpty;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade200,
      child: hasImg
       ? ClipOval(child: Image.network(c.avatar!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial(c)))
        : _initial(c),
    );
  }

  Widget _initial(NetworkConnection c) {
    final t = c.name.isNotEmpty? c.name[0].toUpperCase() : '?';
    return Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
          SizedBox(height: 12),
          Text('Aucune suggestion pour le moment', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          SizedBox(height: 6),
          Text('Revenez plus tard', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      );
    }

    // Si tu es dans un CustomScrollView, utilise SuggestionsSliverList plus bas
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: widget.suggestions.length,
      separatorBuilder: (_, __) => SizedBox(height: 2),
      itemBuilder: (context, i) {
        final c = widget.suggestions[i];
        final mutual = c.mutualConnections?? 0;
        final isLoading = _connecting.contains(c.id);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            _avatar(c),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text(c.title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('$mutual connexion${mutual>1?'s':''} commune${mutual>1?'s':''}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ])),
            OutlinedButton(
              onPressed: isLoading? null : () => _handle(c.id),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Color(0xFFD4AF37)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), minimumSize: Size(90, 32)),
              child: isLoading? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))) : Text('Se connecter', style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37))),
            ),
          ]),
        );
      },
    );
  }
}

// Version scalable pour CustomScrollView / feed infini
class SuggestionsSliverList extends StatelessWidget {
  final List<NetworkConnection> suggestions;
  final Future<void> Function(String) onConnect;
  const SuggestionsSliverList({super.key, required this.suggestions, required this.onConnect});
  @override Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, i) => SuggestionsList(suggestions: [suggestions[i]], onConnect: onConnect),
    );
  }
}
