import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportDialog extends StatefulWidget {
  final String contentType; // 'post', 'user', 'comment'
  final String contentId;
  final String? reportedUserId;
  final String? postId;
  const ReportDialog({super.key, required this.contentType, required this.contentId, this.reportedUserId, this.postId});
  @override State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _selectedReason = 'contenu_inapproprié';
  final _details = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = {
    'contenu_inapproprié': 'Contenu inapproprié',
    'spam': 'Spam ou publicité',
    'harcelement': 'Harcèlement',
    'fausse_info': 'Fausse information',
    'violence': 'Violence / haine',
    'discrimination': 'Discrimination',
    'droit_auteur': 'Droits d\'auteur',
    'compte_factice': 'Compte factice',
    'autre': 'Autre',
  };

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (widget.reportedUserId != null && widget.reportedUserId == uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vous ne pouvez pas signaler votre propre contenu'), backgroundColor: Colors.orange));
      });
    }
  }

  @override
  void dispose() { _details.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_selectedReason == 'autre' && _details.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Décrivez au moins 10 caractères'), backgroundColor: Colors.orange));
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Confirmer ?'), content: Text('Signalement anonyme, examiné par notre équipe.'), actions: [TextButton(onPressed: ()=> Navigator.pop(context,false), child: Text('Annuler')), ElevatedButton(onPressed: ()=> Navigator.pop(context,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Signaler'))]));
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final supabase = Supabase.instance.client;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Non connecté');

      // Anti-spam: déjà signalé dans les 24h ?
      final existing = await supabase.from('reports').select('id').eq('reporter_id', user.id).eq('content_id', widget.contentId).gte('created_at', DateTime.now().subtract(Duration(hours: 24)).toIso8601String()).limit(1);
      if ((existing as List).isNotEmpty) throw Exception('Vous avez déjà signalé ce contenu');

      await supabase.from('reports').insert({
        'content_type': widget.contentType,
        'content_id': widget.contentId,
        'reported_user_id': widget.reportedUserId,
        'post_id': widget.postId,
        'reporter_id': user.id,
        'reason': _selectedReason,
        'details': _details.text.trim(),
        'status': 'pending',
      });

      if (!mounted) return;
      Navigator.pop(context, true); // on pop AVANT le snackbar
      messenger.showSnackBar(SnackBar(content: Text('Merci, signalement envoyé'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(20),
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(widget.contentType=='post'?'Signaler la publication': widget.contentType=='user'?'Signaler l\'utilisateur':'Signaler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(icon: Icon(Icons.close), onPressed: ()=> Navigator.pop(context))]),
          SizedBox(height: 12),
          Text('Pourquoi ?', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(child: Column(children: _reasons.entries.map((e)=> RadioListTile<String>(title: Text(e.value, style: TextStyle(fontSize: 14)), value: e.key, groupValue: _selectedReason, onChanged: (v)=> setState(()=> _selectedReason=v!), activeColor: Color(0xFFD4AF37), dense: true, contentPadding: EdgeInsets.zero)).toList()))),
          if (_selectedReason=='autre')...[SizedBox(height: 8), TextField(controller: _details, maxLines: 3, decoration: InputDecoration(hintText: 'Décrivez le problème...', border: OutlineInputBorder()))],
          SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: ()=> Navigator.pop(context), child: Text('Annuler'))),
            SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _isSubmitting? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: _isSubmitting? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('SIGNALER', style: TextStyle(fontWeight: FontWeight.bold)))),
          ]),
        ]),
      ),
    );
  }
}
