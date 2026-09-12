// lib/presentation/thix_info/thix_magazine_reader_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/news_article.dart';
import '../../providers/news_provider.dart';

// ============================================================================
// BLOCS DE CONTENU PARSE
// ============================================================================
enum _BlockType { paragraph, heading, quote, image, video }

class _Block {
  final _BlockType type;
  final String text;
  final String? caption;
  final String? duration;
  const _Block(this.type, this.text, {this.caption, this.duration});
  factory _Block.paragraph(String t) => _Block(_BlockType.paragraph, t);
  factory _Block.heading(String t) => _Block(_BlockType.heading, t);
  factory _Block.quote(String t) => _Block(_BlockType.quote, t);
  factory _Block.image(String url, {String? caption}) =>
      _Block(_BlockType.image, url, caption: caption);
  factory _Block.video(String url, {String? caption, String? duration}) =>
      _Block(_BlockType.video, url, caption: caption, duration: duration);
}

List<_Block> _parseContent(String content) {
  final blocks = <_Block>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.toString().trim().isNotEmpty) {
      blocks.add(_Block.paragraph(buf.toString().trim()));
    }
    buf.clear();
  }

  for (final raw in content.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty) {
      flush();
      continue;
    }
    if (l.startsWith('## ')) {
      flush();
      blocks.add(_Block.heading(l.substring(3)));
    } else if (l.startsWith('> ')) {
      flush();
      blocks.add(_Block.quote(l.substring(2)));
    } else if (l.startsWith('![')) {
      flush();
      final m = RegExp(r'!\[(.*)\]\((.*)\)').firstMatch(l);
      if (m != null) blocks.add(_Block.image(m.group(2)!, caption: m.group(1)));
    } else if (l.startsWith('@[')) {
      flush();
      final m = RegExp(r'@\[(.*?)\s*\|?\s*(.*?)\]\((.*)\)').firstMatch(l);
      if (m != null) {
        blocks.add(_Block.video(m.group(3)!,
            caption: m.group(1), duration: m.group(2)?.isEmpty ?? true ? null : m.group(2)));
      }
    } else {
      buf.writeln(l);
    }
  }
  flush();
  return blocks;
}

// ============================================================================
// LECTEUR MAGAZINE PREMIUM
// ============================================================================
class ThixMagazineReaderPage extends ConsumerStatefulWidget {
  final String articleId;
  const ThixMagazineReaderPage({super.key, required this.articleId});

  @override
  ConsumerState<ThixMagazineReaderPage> createState() =>
      _ThixMagazineReaderPageState();
}

class _ThixMagazineReaderPageState
    extends ConsumerState<ThixMagazineReaderPage> {
  final ScrollController _scrollCtrl = ScrollController();
  double _progress = 0;
  double _fontScale = 1.0;
  bool _dark = false;
  NewsArticle? _article;
  List<NewsArticle> _related = [];
  bool _loading = true;

  Map<String, dynamic> get _extras => _article?.magazineExtras ?? const {};
  // Le modèle PROD n'a pas magazineExtras ? fallback : parser depuis toJson
  // (voir note en bas si le modèle PROD doit être étendu)

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    setState(() => _progress = (_scrollCtrl.offset / max).clamp(0.0, 1.0));
  }

  Future<void> _load() async {
    final prov = ref.read(newsProvider);
    final article = await prov.fetchArticleById(widget.articleId);
    final magazine = await prov.fetchArticlesByCategory('Magazine');
    if (!mounted) return;
    setState(() {
      _article = article;
      _related = magazine.where((a) => a.id != widget.articleId).take(3).toList();
      _loading = false;
    });
    prov.incrementViews(widget.articleId);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── PALETTE ───
  Color get _bg => _dark ? const Color(0xFF101828) : const Color(0xFFFDFBF7);
  Color get _surface => _dark ? const Color(0xFF1A2436) : Colors.white;
  Color get _text => _dark ? const Color(0xFFE8E6E1) : const Color(0xFF1A2436);
  Color get _muted => _dark ? const Color(0xFF9AA5B1) : const Color(0xFF6B7280);
  Color get _gold => const Color(0xFFD4AF37);
  Color get _navy => _dark ? const Color(0xFF1F2A3D) : const Color(0xFF101828);

  TextStyle _serif(double size, {FontWeight w = FontWeight.w400, double? lh}) =>
      TextStyle(
          fontFamily: 'serif',
          fontSize: size * _fontScale,
          fontWeight: w,
          color: _text,
          height: lh);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: _bg,
          body: const Center(child: CircularProgressIndicator()));
    }
    final a = _article;
    if (a == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: Text('Article introuvable')),
      );
    }

    final blocks = _parseContent(a.content);
    final tags = ((_extras['tags'] as List?) ?? []).cast<String>();
    final quote = (_extras['pull_quote'] ?? '') as String;
    final keyPoints = ((_extras['key_points'] as List?) ?? []).cast<String>();
    final readingMin = (a.content.split(RegExp(r'\s+')).length / 200).ceil();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _appBar(a),
          // ── BARRE DE PROGRESSION ──
          Container(
            height: 3,
            color: _dark ? Colors.white12 : Colors.black12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(color: _gold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              children: [
                _hero(a, tags, readingMin),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text('${(_progress * 100).toInt()}% lu',
                      style: TextStyle(fontSize: 10, color: _muted)),
                ),
                const SizedBox(height: 16),
                // ── CORPS + SIDEBAR ──
                LayoutBuilder(builder: (ctx, c) {
                  final wide = c.maxWidth > 800;
                  final main = _bodyBlocks(blocks, a);
                  final side = _sidebar(quote, keyPoints, a);
                  if (!wide) {
                    return Column(children: [main, const SizedBox(height: 24), side]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: main),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: side),
                    ],
                  );
                }),
                const SizedBox(height: 32),
                _bottomNav(a),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ APP BAR ═══════════════
  Widget _appBar(NewsArticle a) {
    return Container(
      color: _navy,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop()),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: 'THIX ',
                  style: TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              TextSpan(
                  text: 'M A G A Z I N E',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11, letterSpacing: 3)),
            ]),
          ),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.bookmark_border, color: Colors.white),
              onPressed: () => ref.read(newsProvider).saveArticle(a.id)),
          IconButton(
              icon: const Text('Aa',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () => setState(() {
                    _fontScale = _fontScale >= 1.3 ? 0.9 : _fontScale + 0.1;
                  })),
          IconButton(
              icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white),
              onPressed: () => setState(() => _dark = !_dark)),
          IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${a.title} — THIX Magazine'));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Titre copié pour partage')));
              }),
        ],
      ),
    );
  }

  // ═══════════════ HERO ═══════════════
  Widget _hero(NewsArticle a, List<String> tags, int readingMin) {
    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (a.imageUrl != null)
            Image.network(a.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _navy))
          else
            Container(color: _navy),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    _navy.withOpacity(0.92),
                    _navy.withOpacity(0.55),
                    Colors.transparent
                  ]),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 28,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: _gold,
                  child: const Text('MAGAZINE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF101828))),
                ),
                const SizedBox(height: 10),
                if (tags.isNotEmpty)
                  Text(tags.join('  •  ').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: Colors.white70)),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(a.title,
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 30 * _fontScale,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15)),
                  ),
                ),
                if ((a.summary ?? '').isNotEmpty)
                  Text(a.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: Colors.white.withOpacity(0.87), height: 1.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, size: 18, color: Colors.white)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_extras['author_role'] ?? 'Rédaction THIX',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text(
                            '${_fmtDate(a.publishedAt)}  •  $readingMin min de lecture',
                            style: const TextStyle(
                                fontSize: 10.5, color: Colors.white70)),
                      ],
                    ),
                    const Spacer(),
                    if (a.videoUrl != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Regarder la vidéo',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                Text(_extras['video_duration'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ CORPS ═══════════════
  Widget _bodyBlocks(List<_Block> blocks, NewsArticle a) {
    bool firstParagraph = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks) ...[
          if (b.type == _BlockType.paragraph)
            _paragraph(b.text, dropCap: firstParagraph &&
                (firstParagraph = false) == false),
          if (b.type == _BlockType.heading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(b.text,
                  style: _serif(22, w: FontWeight.w700)),
            ),
          if (b.type == _BlockType.quote)
            _quoteBox(b.text),
          if (b.type == _BlockType.image)
            _inlineImage(b),
          if (b.type == _BlockType.video)
            _inlineVideo(b),
        ],
      ],
    );
  }

  Widget _paragraph(String text, {bool dropCap = false}) {
    if (dropCap && text.length > 2) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text[0],
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 52 * _fontScale,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    height: 0.85)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text.substring(1),
                    style: _serif(15.5, lh: 1.7))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text, style: _serif(15.5, lh: 1.7)),
    );
  }

  Widget _quoteBox(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      color: _dark ? const Color(0xFF2A2415) : const Color(0xFFFAF3E3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“',
              style: TextStyle(
                  fontFamily: 'serif', fontSize: 40, color: _gold, height: 0.6)),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18 * _fontScale,
                  fontWeight: FontWeight.w700,
                  color: _navy == _text ? _text : (_dark ? _text : _navy),
                  height: 1.4)),
          const SizedBox(height: 10),
          Container(width: 28, height: 2, color: _gold),
        ],
      ),
    );
  }

  Widget _inlineImage(_Block b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(b.text, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(height: 180, color: Colors.black12)),
          ),
          if ((b.caption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 12, color: _gold),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(b.caption!,
                          style: TextStyle(fontSize: 11, color: _muted))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inlineVideo(_Block b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(
              height: 200,
              color: _navy,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                      color: Colors.white24, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                      child: Text(b.caption ?? '',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))),
                  if ((b.duration ?? '').isNotEmpty)
                    Text(b.duration!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ SIDEBAR ═══════════════
  Widget _sidebar(String quote, List<String> keyPoints, NewsArticle a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quote.isNotEmpty) _quoteBox(quote),
        if (keyPoints.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wb_incandescent_rounded,
                        size: 16, color: _gold),
                    const SizedBox(width: 6),
                    const Text('À RETENIR',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
for (final k in keyPoints)
  Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 15, color: _gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.87),
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  ),
const SizedBox(height: 16),

        ],
        // ── CARTE AUTEUR ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ÉCRIT PAR',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: _gold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rédaction THIX',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _text)),
                        Text(_extras['author_role'] ?? 'Auteur chez THIX Magazine',
                            style: TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── À LIRE ENSUITE ──
        if (_related.isNotEmpty) ...[
          Text('À LIRE ENSUITE',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: _muted)),
          const SizedBox(height: 10),
          for (final r in _related)
            GestureDetector(
              onTap: () => context.push('/thix-info/magazine/${r.id}'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _dark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 52,
                        height: 40,
                        child: r.imageUrl != null
                            ? Image.network(r.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _text)),
                          Text(
                              '${(r.content.split(RegExp(r'\s+')).length / 200).ceil()} min • Magazine',
                              style:
                                  TextStyle(fontSize: 10, color: _muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: _muted),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ═══════════════ NAVIGATION BAS ═══════════════
  Widget _bottomNav(NewsArticle a) {
    final all = [_article!, ..._related];
    final idx = all.indexWhere((e) => e.id == a.id);
    final prev = idx > 0 ? all[idx - 1] : null;
    final next = idx < all.length - 1 ? all[idx + 1] : null;
    return Container(
      color: _navy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: prev == null
                ? const SizedBox()
                : TextButton.icon(
                    onPressed: () =>
                        context.push('/thix-info/magazine/${prev.id}'),
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 18),
                    label: const Text('Article précédent',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < all.length && i < 4; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == idx ? _gold : Colors.white24,
                  ),
                ),
            ],
          ),
          Expanded(
            child: next == null
                ? const SizedBox()
                : TextButton.icon(
                    onPressed: () =>
                        context.push('/thix-info/magazine/${next.id}'),
                    icon: const Text('Article suivant',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    label: const Icon(Icons.chevron_right,
                        color: Colors.white, size: 18),
                  ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${mois[d.month - 1]} ${d.year}';
  }
}
