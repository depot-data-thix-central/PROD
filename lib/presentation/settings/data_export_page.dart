import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  final _sb = Supabase.instance.client;
  bool _isLoading = true;
  String _markdownData = "";
  Map<String, dynamic> _rawData = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _sb.rpc('export_my_data');
      _rawData = Map<String, dynamic>.from(data as Map);
      _markdownData = _generateMarkdown(_rawData);
    } catch (e) {
      _markdownData = "### Erreur\nImpossible de récupérer vos données.\n\n`$e`";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Convertit le JSON brut en Markdown lisible
  String _generateMarkdown(Map<String, dynamic> data) {
    final sb = StringBuffer();
    sb.writeln('# 📄 Export des données personnelles - THIX ID\n');
    sb.writeln('**Généré le :** ${DateTime.now().toLocal()}\n');
    sb.writeln('---\n');

    data.forEach((key, value) {
      sb.writeln('### ${key.toUpperCase().replaceAll('_', ' ')}');
      if (value is Map) {
        value.forEach((k, v) {
          sb.writeln('* **$k** : $v');
        });
      } else if (value is List) {
        if (value.isEmpty) {
          sb.writeln('* *Aucune donnée*');
        } else {
          for (var item in value) {
            sb.writeln('* $item');
          }
        }
      } else {
        sb.writeln('> $value');
      }
      sb.writeln('\n');
    });

    return sb.toString();
  }

  /// Génère et partage le document PDF
  Future<void> _exportToPdf() async {
    final l10n = AppLocalizations.of(context);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('THIX ID - Données Personnelles', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(DateTime.now().toString().split(' ')[0], style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ]
              ),
            ),
            pw.SizedBox(height: 20),
            ..._rawData.entries.map((entry) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key.toUpperCase().replaceAll('_', ' '), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.SizedBox(height: 8),
                  if (entry.value is Map)
                    ...((entry.value as Map).entries.map((e) => pw.Bullet(text: '${e.key} : ${e.value}', style: const pw.TextStyle(fontSize: 12))))
                  else if (entry.value is List)
                    ...((entry.value as List).map((e) => pw.Bullet(text: e.toString(), style: const pw.TextStyle(fontSize: 12))))
                  else
                    pw.Text(entry.value.toString(), style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 20),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                ]
              );
            }),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'THIX_Export_Donnees.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('settings_data_export')),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: ThixPolicy.primary),
              tooltip: "Exporter en PDF",
              onPressed: _exportToPdf,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Markdown(
              data: _markdownData,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: ThixPolicy.h1Style.copyWith(color: ThixPolicy.primary),
                h3: ThixPolicy.h2Style.copyWith(fontSize: 18),
                p: ThixPolicy.bodyStyle,
                blockquoteDecoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: ThixPolicy.primary, width: 4)),
                ),
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _exportToPdf,
              backgroundColor: ThixPolicy.primary,
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: const Text("Générer PDF", style: TextStyle(color: Colors.white)),
            ),
    );
  }
}
