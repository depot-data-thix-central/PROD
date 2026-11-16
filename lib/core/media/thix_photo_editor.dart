// lib/core/media/thix_photo_editor.dart
// Éditeur photo : filtres, dessin, texte, emojis. Le résultat est "cuit" dans l'image.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

enum EditorTool { none, filter, draw, text, emoji }

class EditedPhoto {
  const EditedPhoto({required this.bytes, required this.ext});
  final Uint8List bytes;
  final String ext;
}

// ============================================================================
// FILTRES
// ============================================================================
class _PhotoFilter {
  const _PhotoFilter(this.name, this.matrix);
  final String name;
  final List<double> matrix;
}

List<double> _saturation(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

final List<_PhotoFilter> _kFilters = [
  const _PhotoFilter('Original', [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  _PhotoFilter('Vif', _saturation(1.45)),
  const _PhotoFilter('Chaud', [
    1.1, 0, 0, 0, 10,
    0, 1.0, 0, 0, 0,
    0, 0, 0.9, 0, -10,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('Froid', [
    0.9, 0, 0, 0, -10,
    0, 1.0, 0, 0, 0,
    0, 0, 1.1, 0, 10,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('N&B', [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('Sépia', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('Fondu', [
    0.85, 0, 0, 0, 25,
    0, 0.85, 0, 0, 25,
    0, 0, 0.85, 0, 25,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('Contraste', [
    1.3, 0, 0, 0, -38,
    0, 1.3, 0, 0, -38,
    0, 0, 1.3, 0, -38,
    0, 0, 0, 1, 0,
  ]),
  const _PhotoFilter('Vintage', [
    0.9, 0.1, 0, 0, 12,
    0.1, 0.8, 0.1, 0, 6,
    0, 0.1, 0.7, 0, 0,
    0, 0, 0, 1, 0,
  ]),
];

// ============================================================================
// MODÈLES
// ============================================================================
class _Stroke {
  _Stroke({required this.color, required this.width, required this.points});
  final Color color;
  final double width; // fraction de la largeur
  final List<Offset> points; // normalisés 0..1
}

class _Overlay {
  _Overlay({
    required this.id,
    required this.text,
    required this.isEmoji,
    required this.color,
    required this.bg,
    required this.pos,
  });
  final String id;
  String text;
  final bool isEmoji;
  Color color;
  bool bg;
  Offset pos; // centre normalisé 0..1
  double scale = 1;
  double rotation = 0;
}

class _TextResult {
  const _TextResult(this.text, this.color, this.bg);
  final String text;
  final Color color;
  final bool bg;
}

const List<Color> _kPalette = [
  Colors.white,
  Colors.black,
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFFFACC15),
  Color(0xFF22C55E),
  Color(0xFF00A4FF),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

const List<String> _kEmojis = [
  '😀', '😂', '🤣', '😍', '🥰', '😎', '🤩', '😘',
  '😅', '😉', '🥳', '😇', '🤔', '😢', '😭', '😡',
  '😱', '🙏', '👍', '👎', '👏', '🙌', '💪', '🤝',
  '👋', '✌️', '🤞', '👌', '❤️', '🧡', '💛', '💚',
  '💙', '💜', '🖤', '💔', '🔥', '✨', '⭐', '🌟',
  '🎉', '🎊', '🎂', '🎁', '🏆', '🥇', '💯', '✅',
  '❌', '⚡', '🌈', '☀️', '🌙', '🌍', '🌸', '🌴',
  '🍕', '🍔', '🍟', '🍺', '☕', '⚽', '🏀', '🎵',
  '🎶', '🎧', '📸', '🚀', '✈️', '🚗', '🏠', '💼',
  '📱', '💻', '💡', '📌', '🇨🇩', '👑', '💎', '🕊️',
];

Color _contrast(Color c) => c.computeLuminance() > 0.55 ? Colors.black : Colors.white;

// ============================================================================
// PAGE ÉDITEUR
// ============================================================================
class ThixPhotoEditorPage extends StatefulWidget {
  const ThixPhotoEditorPage({
    super.key,
    required this.bytes,
    this.initialTool = EditorTool.none,
  });

  final Uint8List bytes;
  final EditorTool initialTool;

  @override
  State<ThixPhotoEditorPage> createState() => _ThixPhotoEditorPageState();
}

class _ThixPhotoEditorPageState extends State<ThixPhotoEditorPage> {
  final GlobalKey _boundaryKey = GlobalKey();

  double? _imgW;
  double? _imgH;
  Size _boxSize = Size.zero;

  int _filterIndex = 0;
  EditorTool _tool = EditorTool.none; // none | filter | draw

  final List<_Stroke> _strokes = [];
  _Stroke? _current;
  Color _brushColor = Colors.white;
  double _brushWidth = 6;

  final List<_Overlay> _overlays = [];
  int _seq = 0;
  String? _draggingId;
  Offset? _dragGlobal;
  double _baseScale = 1;
  double _baseRot = 0;

  bool _exporting = false;

  bool get _dirty => _filterIndex != 0 || _strokes.isNotEmpty || _overlays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    try {
      final img = await decodeImageFromList(widget.bytes);
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      img.dispose();
      if (!mounted) return;
      setState(() {
        _imgW = w;
        _imgH = h;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialTool) {
          case EditorTool.filter:
            setState(() => _tool = EditorTool.filter);
            break;
          case EditorTool.draw:
            setState(() => _tool = EditorTool.draw);
            break;
          case EditorTool.text:
            _addText();
            break;
          case EditorTool.emoji:
            _addEmoji();
            break;
          case EditorTool.none:
            break;
        }
      });
    } catch (e) {
      debugPrint('[PhotoEditor] size: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  // ───────────────────────── DESSIN ─────────────────────────
  Offset _norm(Offset p) => Offset(
        (p.dx / _boxSize.width).clamp(0.0, 1.0).toDouble(),
        (p.dy / _boxSize.height).clamp(0.0, 1.0).toDouble(),
      );

  void _drawStart(Offset p) {
    final s = _Stroke(color: _brushColor, width: _brushWidth / 360, points: [_norm(p)]);
    setState(() {
      _current = s;
      _strokes.add(s);
    });
  }

  void _drawUpdate(Offset p) {
    _current?.points.add(_norm(p));
    setState(() {});
  }

  void _drawEnd() => _current = null;

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  // ───────────────────────── TEXTE / EMOJI ─────────────────────────
  Future<_TextResult?> _askText({_Overlay? edit}) {
    return showModalBottomSheet<_TextResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xE6000000),
      builder: (_) => _TextSheet(
        initial: edit?.text ?? '',
        color: edit?.color ?? Colors.white,
        bg: edit?.bg ?? false,
      ),
    );
  }

  Offset _nextPos() => Offset(0.5, 0.4 + 0.08 * (_overlays.length % 4));

  Future<void> _addText() async {
    final res = await _askText();
    if (res == null || !mounted) return;
    setState(() {
      _tool = EditorTool.none;
      _overlays.add(_Overlay(
        id: 'o${_seq++}',
        text: res.text,
        isEmoji: false,
        color: res.color,
        bg: res.bg,
        pos: _nextPos(),
      ));
    });
  }

  Future<void> _editText(_Overlay o) async {
    final res = await _askText(edit: o);
    if (!mounted) return;
    setState(() {
      if (res == null) return;
      o.text = res.text;
      o.color = res.color;
      o.bg = res.bg;
    });
  }

  Future<void> _addEmoji() async {
    final e = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 300,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: _kEmojis.length,
            itemBuilder: (_, i) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.pop(ctx, _kEmojis[i]),
              child: Center(child: Text(_kEmojis[i], style: const TextStyle(fontSize: 26))),
            ),
          ),
        ),
      ),
    );
    if (e == null || !mounted) return;
    setState(() {
      _tool = EditorTool.none;
      _overlays.add(_Overlay(
        id: 'o${_seq++}',
        text: e,
        isEmoji: true,
        color: Colors.white,
        bg: false,
        pos: _nextPos(),
      ));
    });
  }

  bool _overTrash() {
    final g = _dragGlobal;
    if (g == null) return false;
    return g.dy > MediaQuery.of(context).size.height - 190;
  }

  Widget _textBubble(_Overlay o, double fs) {
    final txtColor = o.bg ? _contrast(o.color) : o.color;
    final t = Text(
      o.text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: txtColor,
        fontSize: fs,
        fontWeight: FontWeight.w800,
        height: 1.2,
        shadows: o.bg ? null : const [Shadow(color: Colors.black54, blurRadius: 6)],
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _boxSize.width * 0.8),
      child: o.bg
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: o.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: t,
            )
          : t,
    );
  }

  Widget _overlayWidget(_Overlay o) {
    final bw = _boxSize.width;
    final bh = _boxSize.height;
    final fs = (o.isEmoji ? 64.0 : 30.0) * bw / 360;

    return Positioned(
      left: o.pos.dx * bw,
      top: o.pos.dy * bh,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: o.rotation,
          child: Transform.scale(
            scale: o.scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: o.isEmoji ? null : () => _editText(o),
              onScaleStart: (d) {
                _baseScale = o.scale;
                _baseRot = o.rotation;
                setState(() {
                  _draggingId = o.id;
                  _dragGlobal = d.focalPoint;
                  _overlays.remove(o);
                  _overlays.add(o); // au premier plan
                });
              },
              onScaleUpdate: (d) {
                setState(() {
                  o.pos = o.pos + Offset(d.focalPointDelta.dx / bw, d.focalPointDelta.dy / bh);
                  o.scale = (_baseScale * d.scale).clamp(0.4, 6.0).toDouble();
                  o.rotation = _baseRot + d.rotation;
                  _dragGlobal = d.focalPoint;
                });
              },
              onScaleEnd: (_) {
                final remove = _overTrash();
                setState(() {
                  if (remove) _overlays.remove(o);
                  _draggingId = null;
                  _dragGlobal = null;
                });
              },
              child: o.isEmoji
                  ? Text(o.text, style: TextStyle(fontSize: fs))
                  : _textBubble(o, fs),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── EXPORT ─────────────────────────
  Future<void> _done() async {
    if (_exporting) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _exporting = true;
      _draggingId = null;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final longSide = math.max(_imgW!, _imgH!);
      final target = math.min(longSide, 2048.0);
      final boxLong = math.max(_boxSize.width, _boxSize.height);
      final pr = (target / boxLong).clamp(0.5, 6.0).toDouble();

      final image = await boundary.toImage(pixelRatio: pr);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('export null');

      var out = data.buffer.asUint8List();
      var ext = 'png';

      if (!kIsWeb) {
        try {
          out = await FlutterImageCompress.compressWithList(
            out,
            minWidth: 1280,
            minHeight: 1280,
            quality: 88,
            format: CompressFormat.jpeg,
          );
          ext = 'jpg';
        } catch (e) {
          debugPrint('[PhotoEditor] jpeg: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context, EditedPhoto(bytes: out, ext: ext));
    } catch (e) {
      debugPrint('[PhotoEditor] export: $e');
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export impossible, réessayez.')),
      );
    }
  }

  Future<void> _confirmClose() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: _imgW == null
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _canvas(),
                  ),
                  SizedBox(height: 92, child: _subPanel()),
                  _toolbar(),
                ],
              ),
              if (_draggingId != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 110,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: EdgeInsets.all(_overTrash() ? 18 : 12),
                      decoration: BoxDecoration(
                        color: _overTrash() ? Colors.redAccent : Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              if (_exporting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: _confirmClose,
          ),
          const Spacer(),
          if (_tool == EditorTool.draw && _strokes.isNotEmpty)
            IconButton(
              tooltip: 'Annuler le dernier trait',
              icon: const Icon(Icons.undo_rounded, color: Colors.white),
              onPressed: _undo,
            ),
          TextButton(
            onPressed: _done,
            child: const Text(
              'Terminé',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(builder: (context, c) {
      final iw = _imgW!;
      final ih = _imgH!;
      final scale = math.min(c.maxWidth / iw, c.maxHeight / ih);
      final w = iw * scale;
      final h = ih * scale;
      _boxSize = Size(w, h);

      return Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix(_kFilters[_filterIndex].matrix),
                    child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _StrokePainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                  if (_tool == EditorTool.draw)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _drawStart(d.localPosition),
                        onPanUpdate: (d) => _drawUpdate(d.localPosition),
                        onPanEnd: (_) => _drawEnd(),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: _tool == EditorTool.draw,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _overlays.map(_overlayWidget).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _subPanel() {
    if (_tool == EditorTool.filter) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _kFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = _kFilters[i];
          final sel = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? const Color(0xFF00A4FF) : Colors.white24,
                      width: sel ? 2.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(f.matrix),
                      child: Image.memory(widget.bytes, fit: BoxFit.cover, cacheWidth: 140),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  f.name,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (_tool == EditorTool.draw) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kPalette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _kPalette[i];
                  final sel = c == _brushColor;
                  return GestureDetector(
                    onTap: () => setState(() => _brushColor = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? const Color(0xFF00A4FF) : Colors.white54,
                          width: sel ? 3 : 1.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Slider(
              min: 2,
              max: 28,
              value: _brushWidth,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => _brushWidth = v),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _toolbar() {
    Widget btn(IconData icon, String label, bool active, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? const Color(0xFF00A4FF) : Colors.white, size: 26),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFF00A4FF) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          btn(Icons.auto_fix_high_rounded, 'Filtres', _tool == EditorTool.filter, () {
            setState(() => _tool = _tool == EditorTool.filter ? EditorTool.none : EditorTool.filter);
          }),
          btn(Icons.brush_rounded, 'Dessin', _tool == EditorTool.draw, () {
            setState(() => _tool = _tool == EditorTool.draw ? EditorTool.none : EditorTool.draw);
          }),
          btn(Icons.title_rounded, 'Texte', false, _addText),
          btn(Icons.emoji_emotions_outlined, 'Emoji', false, _addEmoji),
        ],
      ),
    );
  }
}

// ============================================================================
// PEINTRE DES TRAITS
// ============================================================================
class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final w = s.width * size.width;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        final p = s.points.first;
        canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height),
          w / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      final path = Path()
        ..moveTo(s.points.first.dx * size.width, s.points.first.dy * size.height);
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx * size.width, s.points[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

// ============================================================================
// FEUILLE DE SAISIE DU TEXTE
// ============================================================================
class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.initial, required this.color, required this.bg});
  final String initial;
  final Color color;
  final bool bg;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  late Color _color = widget.color;
  late bool _bg = widget.bg;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    Navigator.pop(context, t.isEmpty ? null : _TextResult(t, _color, _bg));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _c,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: 120,
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: _bg ? _contrast(_color) : _color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Écrivez ici…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  filled: _bg,
                  fillColor: _bg ? _color : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Fond',
                    icon: Icon(
                      Icons.format_color_fill_rounded,
                      color: _bg ? const Color(0xFF00A4FF) : Colors.white,
                    ),
                    onPressed: () => setState(() => _bg = !_bg),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _kPalette.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final c = _kPalette[i];
                          final sel = c == _color;
                          return GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel ? const Color(0xFF00A4FF) : Colors.white54,
                                  width: sel ? 3 : 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('OK')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
