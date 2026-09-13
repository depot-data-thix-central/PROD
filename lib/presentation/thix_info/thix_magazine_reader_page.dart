// lib/presentation/thix_info/thix_magazine_reader_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/news_article.dart';
import '../../providers/news_provider.dart';

// ============================================================================
// BLOCS DE CONTENU
// ============================================================================

enum _BlockType {
  paragraph,
  heading,
  quote,
  image,
  video,
}

class _Block {
  final _BlockType type;
  final String text;
  final String? caption;
  final String? duration;

  const _Block(
    this.type,
    this.text, {
    this.caption,
    this.duration,
  });

  factory _Block.paragraph(String text) {
    return _Block(_BlockType.paragraph, text);
  }

  factory _Block.heading(String text) {
    return _Block(_BlockType.heading, text);
  }

  factory _Block.quote(String text) {
    return _Block(_BlockType.quote, text);
  }

  factory _Block.image(
    String url, {
    String? caption,
  }) {
    return _Block(
      _BlockType.image,
      url,
      caption: caption,
    );
  }

  factory _Block.video(
    String url, {
    String? caption,
    String? duration,
  }) {
    return _Block(
      _BlockType.video,
      url,
      caption: caption,
      duration: duration,
    );
  }
}

// ============================================================================
// PARSEUR DU CONTENU MAGAZINE
//
// Syntaxe supportée:
//
// ## Titre de section
//
// > Citation importante
//
// ![Légende](https://image-url)
//
// @[Titre vidéo | 02:34](https://video-url)
// ============================================================================

List<_Block> _parseContent(String content) {
  final blocks = <_Block>[];
  final buffer = StringBuffer();

  void flushParagraph() {
    final value = buffer.toString().trim();

    if (value.isNotEmpty) {
      blocks.add(_Block.paragraph(value));
    }

    buffer.clear();
  }

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();

    // Ligne vide
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }

    // ------------------------------------------------------------------------
    // HEADING
    // ------------------------------------------------------------------------
    if (line.startsWith('## ')) {
      flushParagraph();

      final title = line.substring(3).trim();

      if (title.isNotEmpty) {
        blocks.add(_Block.heading(title));
      }

      continue;
    }

    // ------------------------------------------------------------------------
    // QUOTE
    // ------------------------------------------------------------------------
    if (line.startsWith('> ')) {
      flushParagraph();

      final quote = line.substring(2).trim();

      if (quote.isNotEmpty) {
        blocks.add(_Block.quote(quote));
      }

      continue;
    }

    // ------------------------------------------------------------------------
    // IMAGE
    // ![caption](url)
    // ------------------------------------------------------------------------
    if (line.startsWith('![')) {
      flushParagraph();

      final match = RegExp(
        r'!\[(.*?)\]\((.*?)\)',
      ).firstMatch(line);

      if (match != null) {
        final caption = match.group(1)?.trim();
        final url = match.group(2)?.trim();

        if (url != null && url.isNotEmpty) {
          blocks.add(
            _Block.image(
              url,
              caption: caption?.isEmpty == true ? null : caption,
            ),
          );
        }
      }

      continue;
    }

    // ------------------------------------------------------------------------
    // VIDEO
    // @[caption | duration](url)
    // ------------------------------------------------------------------------
    if (line.startsWith('@[')) {
      flushParagraph();

      final match = RegExp(
        r'@\[(.*?)\]\((.*?)\)',
      ).firstMatch(line);

      if (match != null) {
        final metadata = match.group(1)?.trim() ?? '';
        final url = match.group(2)?.trim() ?? '';

        if (url.isNotEmpty) {
          String? caption;
          String? duration;

          if (metadata.contains('|')) {
            final parts = metadata.split('|');

            caption = parts.first.trim();

            if (parts.length > 1) {
              final value = parts.sublist(1).join('|').trim();

              if (value.isNotEmpty) {
                duration = value;
              }
            }
          } else if (metadata.isNotEmpty) {
            caption = metadata;
          }

          blocks.add(
            _Block.video(
              url,
              caption: caption,
              duration: duration,
            ),
          );
        }
      }

      continue;
    }

    // ------------------------------------------------------------------------
    // PARAGRAPHE NORMAL
    // ------------------------------------------------------------------------
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }

    buffer.write(line);
  }

  flushParagraph();

  return blocks;
}

// ============================================================================
// LECTEUR MAGAZINE PREMIUM
// ============================================================================

class ThixMagazineReaderPage extends ConsumerStatefulWidget {
  final String articleId;

  const ThixMagazineReaderPage({
    super.key,
    required this.articleId,
  });

  @override
  ConsumerState<ThixMagazineReaderPage> createState() =>
      _ThixMagazineReaderPageState();
}

class _ThixMagazineReaderPageState
    extends ConsumerState<ThixMagazineReaderPage> {
  final ScrollController _scrollController = ScrollController();

  double _progress = 0.0;
  double _fontScale = 1.0;

  bool _dark = false;
  bool _loading = true;

  NewsArticle? _article;
  List<NewsArticle> _related = [];

  // ==========================================================================
  // MAGAZINE EXTRAS
  // ==========================================================================

  Map<String, dynamic> get _extras {
    return _article?.magazineExtras ?? const {};
  }

  List<String> get _tags {
    final raw = _extras['tags'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  List<String> get _keyPoints {
    final raw = _extras['key_points'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  String get _pullQuote {
    final value = _extras['pull_quote'];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  String get _authorRole {
    final value = _extras['author_role'];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Rédaction THIX Magazine';
    }

    return value.toString().trim();
  }

  String get _imageCaption {
    final value = _extras['image_caption'];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  String get _videoDuration {
    final value = _extras['video_duration'];

    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  // ==========================================================================
  // SCROLL PROGRESS
  // ==========================================================================

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;

    if (maxScroll <= 0) {
      return;
    }

    final value = (_scrollController.offset / maxScroll).clamp(
      0.0,
      1.0,
    );

    if ((value - _progress).abs() < 0.005) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _progress = value;
    });
  }

  // ==========================================================================
  // LOAD ARTICLE
  // ==========================================================================

  Future<void> _load() async {
    try {
      final provider = ref.read(newsProvider);

      final article = await provider.fetchArticleById(
        widget.articleId,
      );

      final magazineArticles =
          await provider.fetchArticlesByCategory('Magazine');

      if (!mounted) {
        return;
      }

      setState(() {
        _article = article;

        _related = magazineArticles
            .where((a) => a.id != widget.articleId)
            .take(3)
            .toList();

        _loading = false;
      });

      provider.incrementViews(widget.articleId);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // PALETTE
  // ==========================================================================

  Color get _bg {
    return _dark
        ? const Color(0xFF0D1420)
        : const Color(0xFFFDFBF7);
  }

  Color get _surface {
    return _dark
        ? const Color(0xFF151F2E)
        : Colors.white;
  }

  Color get _text {
    return _dark
        ? const Color(0xFFE9E7E1)
        : const Color(0xFF182131);
  }

  Color get _muted {
    return _dark
        ? const Color(0xFF9CA6B4)
        : const Color(0xFF6B7280);
  }

  Color get _gold {
    return const Color(0xFFD4AF37);
  }

  Color get _navy {
    return _dark
        ? const Color(0xFF182334)
        : const Color(0xFF101828);
  }

  // ==========================================================================
  // SERIF
  // ==========================================================================

  TextStyle _serif(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.65,
  }) {
    return TextStyle(
      fontFamily: 'serif',
      fontSize: size * _fontScale,
      fontWeight: weight,
      color: _text,
      height: height,
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(
            color: _gold,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final article = _article;

    if (article == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('THIX Magazine'),
        ),
        body: Center(
          child: Text(
            'Article introuvable',
            style: TextStyle(
              color: _text,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final blocks = _parseContent(article.content);

    final readingMinutes = _readingMinutes(
      article.content,
    );

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _appBar(article),

          // ================================================================
          // PROGRESS BAR
          // ================================================================

          Container(
            height: 3,
            color: _dark
                ? Colors.white10
                : Colors.black12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress,
                child: Container(
                  color: _gold,
                ),
              ),
            ),
          ),

          // ================================================================
          // CONTENT
          // ================================================================

          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                _hero(
                  article,
                  _tags,
                  readingMinutes,
                ),

                // ==========================================================
                // PROGRESS TEXT
                // ==========================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    10,
                    22,
                    0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${(_progress * 100).round()}% lu',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$readingMinutes min de lecture',
                        style: TextStyle(
                          fontSize: 10,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ==========================================================
                // ARTICLE BODY
                // ==========================================================

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;

                    final mainContent = _bodyBlocks(
                      blocks,
                      article,
                    );

                    final sidebar = _sidebar(
                      _pullQuote,
                      _keyPoints,
                      article,
                    );

                    if (!isWide) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            mainContent,
                            const SizedBox(height: 32),
                            sidebar,
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: mainContent,
                          ),
                          const SizedBox(width: 42),
                          Expanded(
                            flex: 4,
                            child: sidebar,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                _bottomNav(article),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================

  Widget _appBar(NewsArticle article) {
    return Container(
      color: _navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              onPressed: () {
                context.pop();
              },
            ),

            // ================================================================
            // LOGO
            // ================================================================

            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'THIX ',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const TextSpan(
                    text: 'M A G A Z I N E',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ================================================================
            // BOOKMARK
            // ================================================================

            IconButton(
              tooltip: 'Enregistrer',
              icon: const Icon(
                Icons.bookmark_border_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                ref.read(newsProvider).saveArticle(
                      article.id,
                    );

                _showMessage(
                  'Article enregistré',
                );
              },
            ),

            // ================================================================
            // FONT SIZE
            // ================================================================

            IconButton(
              tooltip: 'Taille du texte',
              onPressed: _increaseFontSize,
              icon: const Text(
                'Aa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ================================================================
            // DARK MODE
            // ================================================================

            IconButton(
              tooltip: 'Mode sombre',
              icon: Icon(
                _dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _dark = !_dark;
                });
              },
            ),

            // ================================================================
            // SHARE
            // ================================================================

            IconButton(
              tooltip: 'Partager',
              icon: const Icon(
                Icons.share_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        '${article.title} — THIX Magazine',
                  ),
                );

                _showMessage(
                  'Titre copié pour partage',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FONT SIZE
  // ==========================================================================

  void _increaseFontSize() {
    setState(() {
      if (_fontScale >= 1.3) {
        _fontScale = 0.9;
      } else {
        _fontScale += 0.1;
      }
    });
  }

  // ==========================================================================
  // HERO
  // ==========================================================================

  Widget _hero(
    NewsArticle article,
    List<String> tags,
    int readingMinutes,
  ) {
    final hasImage =
        article.imageUrl != null &&
        article.imageUrl!.trim().isNotEmpty;

    return SizedBox(
      height: 455,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ==================================================================
          // PHOTO
          // ==================================================================

          if (hasImage)
            Image.network(
              article.imageUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  color: _navy,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white30,
                      size: 42,
                    ),
                  ),
                );
              },
              loadingBuilder: (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }

                return Container(
                  color: _navy,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _gold,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: _navy,
            ),

          // ==================================================================
          // GRADIENT PRINCIPAL
          //
          // Important :
          // le haut reste visible.
          // Le sombre arrive progressivement vers le bas.
          // ==================================================================

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [
                    0.0,
                    0.25,
                    0.55,
                    0.78,
                    1.0,
                  ],
                  colors: [
                    Colors.black.withOpacity(0.25),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                    _navy.withOpacity(0.60),
                    _navy.withOpacity(0.98),
                  ],
                ),
              ),
            ),
          ),

          // ==================================================================
          // PETIT VOILE LATÉRAL
          // ==================================================================

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _navy.withOpacity(0.18),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ==================================================================
          // CONTENU HERO
          // ==================================================================

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                26,
                24,
                22,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==========================================================
                  // LABEL
                  // ==========================================================

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'MAGAZINE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),

                  // ==========================================================
                  // TAGS
                  // ==========================================================

                  if (tags.isNotEmpty)
                    Text(
                      tags
                          .take(6)
                          .join('  •  ')
                          .toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.8,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),

                  const Spacer(),

                  // ==========================================================
                  // TITRE
                  // ==========================================================

                  Text(
                    article.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 30 * _fontScale,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.08,
                      letterSpacing: -0.35,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 11),

                  // ==========================================================
                  // RÉSUMÉ
                  // ==========================================================

                  if ((article.summary ?? '')
                      .trim()
                      .isNotEmpty)
                    Text(
                      article.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ==========================================================
                  // META
                  // ==========================================================

                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.17),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 9),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authorRole,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDate(article.publishedAt)}'
                              '  •  '
                              '$readingMinutes min de lecture',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ======================================================
                      // VIDEO BUTTON
                      // ======================================================

                      if (article.videoUrl != null &&
                          article.videoUrl!
                              .trim()
                              .isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _showMessage(
                              'Lecture vidéo disponible',
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _gold,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(
                                    0.28,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF101828),
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BODY BLOCKS
  // ==========================================================================

  Widget _bodyBlocks(
    List<_Block> blocks,
    NewsArticle article,
  ) {
    bool firstParagraph = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          switch (block.type) {
            _BlockType.paragraph => _paragraph(
                block.text,
                dropCap: _consumeFirstParagraph(
                  firstParagraph,
                  () {
                    firstParagraph = false;
                  },
                ),
              ),
            _BlockType.heading => _heading(block.text),
            _BlockType.quote => _quoteBox(block.text),
            _BlockType.image => _inlineImage(block),
            _BlockType.video => _inlineVideo(block),
          },
        ],
      ],
    );
  }

  // ==========================================================================
  // FIRST PARAGRAPH / DROP CAP
  // ==========================================================================

  bool _consumeFirstParagraph(
    bool isFirst,
    VoidCallback consume,
  ) {
    if (isFirst) {
      consume();
      return true;
    }

    return false;
  }

  // ==========================================================================
  // PARAGRAPH
  // ==========================================================================

  Widget _paragraph(
    String text, {
    bool dropCap = false,
  }) {
    if (dropCap && text.length > 2) {
      return Padding(
        padding: const EdgeInsets.only(
          bottom: 18,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              text.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 54 * _fontScale,
                fontWeight: FontWeight.w700,
                color: _gold,
                height: 0.82,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.substring(1),
                style: _serif(
                  16,
                  height: 1.72,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Text(
        text,
        style: _serif(
          16,
          height: 1.72,
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADING
  // ==========================================================================

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 3,
            color: _gold,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: _serif(
              23,
              weight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // QUOTE
  // ==========================================================================

  Widget _quoteBox(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20,
      ),
      decoration: BoxDecoration(
        color: _dark
            ? const Color(0xFF272317)
            : const Color(0xFFFAF3E3),
        border: Border(
          left: BorderSide(
            color: _gold,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            '“',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 42,
              color: _gold,
              height: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18 * _fontScale,
              fontWeight: FontWeight.w700,
              color: _text,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 30,
            height: 2,
            color: _gold,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INLINE IMAGE
  // ==========================================================================

  Widget _inlineImage(_Block block) {
    final caption =
        (block.caption ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                block.text,
                fit: BoxFit.cover,
                filterQuality:
                    FilterQuality.high,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color: _surface,
                    child: Icon(
                      Icons
                          .image_not_supported_outlined,
                      color: _muted,
                    ),
                  );
                },
              ),
            ),
          ),

          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
                left: 2,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons
                        .photo_camera_outlined,
                    size: 13,
                    color: _gold,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      caption,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: _muted,
                        fontStyle:
                            FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INLINE VIDEO
  // ==========================================================================

  Widget _inlineVideo(_Block block) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: Container(
          height: 220,
          color: _navy,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _navy,
                      _dark
                          ? const Color(0xFF26354A)
                          : const Color(0xFF243248),
                    ],
                  ),
                ),
              ),

              // Play
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withOpacity(
                          0.30,
                        ),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color:
                        Color(0xFF101828),
                    size: 34,
                  ),
                ),
              ),

              // Metadata
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        block.caption ??
                            'Vidéo',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                          color:
                              Colors.white,
                        ),
                      ),
                    ),
                    if ((block.duration ??
                            '')
                        .trim()
                        .isNotEmpty)
                      Text(
                        block.duration!,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          color:
                              Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SIDEBAR
  // ==========================================================================

  Widget _sidebar(
    String quote,
    List<String> keyPoints,
    NewsArticle article,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ====================================================================
        // PULL QUOTE
        // ====================================================================

        if (quote.isNotEmpty)
          _quoteBox(quote),

        // ====================================================================
        // À RETENIR
        // ====================================================================

        if (keyPoints.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              18,
            ),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons
                          .lightbulb_outline_rounded,
                      size: 17,
                      color: _gold,
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'À RETENIR',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                for (final point
                    in keyPoints) ...[
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Icon(
                        Icons
                            .check_circle_rounded,
                        size: 15,
                        color: _gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style:
                              const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color:
                                Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ),

        const SizedBox(height: 18),

        // ====================================================================
        // AUTHOR CARD
        // ====================================================================

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            17,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: _dark
                  ? Colors.white12
                  : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ÉCRIT PAR',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1.6,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 11),

              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color: _navy,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Rédaction THIX',
                          style:
                              TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const SizedBox(
                            height: 3),
                        Text(
                          _authorRole,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            fontSize: 10.5,
                            color: _muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ====================================================================
        // À LIRE ENSUITE
        // ====================================================================

        if (_related.isNotEmpty) ...[
          const SizedBox(height: 24),

          Text(
            'À LIRE ENSUITE',
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: 1.6,
              color: _muted,
            ),
          ),

          const SizedBox(height: 10),

          for (final related
              in _related)
            _relatedArticle(
              related,
            ),
        ],
      ],
    );
  }

  // ==========================================================================
  // RELATED ARTICLE
  // ==========================================================================

  Widget _relatedArticle(
    NewsArticle article,
  ) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/thix-info/magazine/${article.id}',
        );
      },
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 9,
        ),
        padding: const EdgeInsets.all(
          8,
        ),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius:
              BorderRadius.circular(10),
          border: Border.all(
            color: _dark
                ? Colors.white12
                : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(7),
              child: SizedBox(
                width: 58,
                height: 46,
                child: article.imageUrl !=
                            null &&
                        article.imageUrl!
                            .trim()
                            .isNotEmpty
                    ? Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return Container(
                            color: _navy,
                          );
                        },
                      )
                    : Container(
                        color: _navy,
                      ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          FontWeight.w700,
                      height: 1.3,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_readingMinutes(article.content)} min • Magazine',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: _muted,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BOTTOM NAVIGATION
  // ==========================================================================

  Widget _bottomNav(
    NewsArticle article,
  ) {
    final all = [
      article,
      ..._related,
    ];

    final index = all.indexWhere(
      (item) => item.id == article.id,
    );

    final previous =
        index > 0 ? all[index - 1] : null;

    final next =
        index < all.length - 1
            ? all[index + 1]
            : null;

    return Container(
      color: _navy,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      child: Row(
        children: [
          // ==================================================================
          // PREVIOUS
          // ==================================================================

          Expanded(
            child: previous == null
                ? const SizedBox()
                : TextButton.icon(
                    onPressed: () {
                      context.push(
                        '/thix-info/magazine/${previous.id}',
                      );
                    },
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Article précédent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),

          // ==================================================================
          // DOTS
          // ==================================================================

          Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              for (
                int i = 0;
                i < all.length && i < 4;
                i++
              )
                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 200,
                  ),
                  width:
                      i == index ? 18 : 6,
                  height: 6,
                  margin:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 3,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(10),
                    color: i == index
                        ? _gold
                        : Colors.white24,
                  ),
                ),
            ],
          ),

          // ==================================================================
          // NEXT
          // ==================================================================

          Expanded(
            child: next == null
                ? const SizedBox()
                : TextButton.icon(
                    onPressed: () {
                      context.push(
                        '/thix-info/magazine/${next.id}',
                      );
                    },
                    icon: const SizedBox
                        .shrink(),
                    label: Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .end,
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Text(
                          'Article suivant',
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(
                            width: 2),
                        const Icon(
                          Icons
                              .chevron_right_rounded,
                          color:
                              Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // READING TIME
  // ==========================================================================

  int _readingMinutes(
    String content,
  ) {
    final clean = content.trim();

    if (clean.isEmpty) {
      return 1;
    }

    final words = clean
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    return (words / 200).ceil().clamp(
          1,
          999,
        );
  }

  // ==========================================================================
  // DATE
  // ==========================================================================

  String _formatDate(
    DateTime date,
  ) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // ==========================================================================
  // SNACKBAR
  // ==========================================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 2),
        ),
      );
  }
}
