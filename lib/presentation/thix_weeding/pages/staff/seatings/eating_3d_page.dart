// lib/presentation/thix_weeding/pages/staff/seating/seating_3d_page.dart
// ============================================================================
// THIX WEDDING — PLAN DE TABLE 3D / SALLE (PRODUCTION)
// Salle interactive avec perspective, lumière ambiante, drag & drop tables
// Assigner invités aux tables, zones VIP / famille
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/thix_weeding_models.dart';
import '../providers/thix_weeding_providers.dart';

class _R {
  static const Color gold = Color(0xFFD4AF37);
  static const Color rose = Color(0xFFE31C4E);
  static const Color blue = Color(0xFF0B3B8F);
  static const Color green = Color(0xFF059669);
  static const Color surface = Color(0xFF12101A);
  static const Color panel = Color(0xFF1C1826);
  static const Color text = Colors.white;
  static const Color text2 = Color(0xFFA89BB0);
}

class Seating3dPage extends ConsumerStatefulWidget {
  final String weddingId;
  const Seating3dPage({super.key, required this.weddingId});

  @override
  ConsumerState<Seating3dPage> createState() => _Seating3dPageState();
}

class _Seating3dPageState extends ConsumerState<Seating3dPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _lightCtrl;
  double _ambient = 0.78;
  bool _showStage = true;
  bool _showDance = true;
  bool _saving = false;
  String? _selectedTableId;
  List<SeatingTableModel> _tables = [];
  List<GuestModel> _guests = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _lightCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _lightCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final tables = await ref.read(seatingServiceProvider).getTables(widget.weddingId);
      final guests = await ref.read(guestServiceProvider).getByWedding(widget.weddingId);
      final layout = await ref.read(seatingServiceProvider).getLayout(widget.weddingId);
      if (!mounted) return;
      setState(() {
        _tables = List.of(tables);
        _guests = guests;
        _ambient = layout.ambientLight;
        _showStage = layout.showStage;
        _showDance = layout.showDanceFloor;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chargement plan: $e'), backgroundColor: _R.rose),
      );
    }
  }

  Future<void> _addTable() async {
    final n = _tables.length + 1;
    final data = {
      'wedding_id': widget.weddingId,
      'label': 'Table $n',
      'shape': 'round',
      'capacity': 8,
      'x': 0.3 + (n % 5) * 0.12,
      'y': 0.35 + (n % 3) * 0.15,
      'rotation': 0,
      'color_hex': '#D4AF37',
      'order_index': n,
    };
    try {
      final t = await ref.read(seatingServiceProvider).createTable(data);
      setState(() {
        _tables.add(t);
        _selectedTableId = t.id;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création table: $e'), backgroundColor: _R.rose),
      );
    }
  }

  Future<void> _saveLayout() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(seatingServiceProvider);
      for (final t in _tables) {
        await svc.updateTable(t.id, {
          'x': t.x,
          'y': t.y,
          'rotation': t.rotation,
          'label': t.label,
          'capacity': t.capacity,
          'shape': t.shape.name,
          'color_hex': t.colorHex,
          'zone': t.zone,
        });
      }
      await svc.saveLayout(widget.weddingId, {
        'ambient_light': _ambient,
        'show_dance_floor': _showDance,
        'show_stage': _showStage,
        'room_color_hex': '#1A1520',
      });
      ref.invalidate(seatingTablesProvider(widget.weddingId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan de salle enregistré ✓'),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSelected() async {
    final id = _selectedTableId;
    if (id == null) return;
    await ref.read(seatingServiceProvider).deleteTable(id);
    setState(() {
      _tables.removeWhere((t) => t.id == id);
      _selectedTableId = null;
    });
  }

  void _moveTable(String id, double dx, double dy, Size room) {
    setState(() {
      _tables = _tables.map((t) {
        if (t.id != id) return t;
        final nx = (t.x + dx / room.width).clamp(0.08, 0.92);
        final ny = (t.y + dy / room.height).clamp(0.12, 0.88);
        return t.copyWith(x: nx, y: ny);
      }).toList();
    });
  }

  Future<void> _assignGuest(GuestModel g, SeatingTableModel table) async {
    // table_number = index order or parse from label
    final num = int.tryParse(table.label.replaceAll(RegExp(r'[^0-9]'), '')) ??
        (_tables.indexWhere((t) => t.id == table.id) + 1);
    await ref.read(seatingServiceProvider).assignGuestToTable(
          guestId: g.id,
          tableNumber: num,
          seatId: table.id,
        );
    final guests = await ref.read(guestServiceProvider).getByWedding(widget.weddingId);
    setState(() => _guests = guests);
    ref.invalidate(guestsProvider(widget.weddingId));
    HapticFeedback.mediumImpact();
  }

  List<GuestModel> _guestsAt(SeatingTableModel table) {
    final num = int.tryParse(table.label.replaceAll(RegExp(r'[^0-9]'), ''));
    return _guests.where((g) {
      if (g.seatId == table.id) return true;
      if (num != null && g.tableNumber == num) return true;
      return false;
    }).toList();
  }

  List<GuestModel> get _unassigned =>
      _guests.where((g) => g.tableNumber == null && (g.seatId == null || g.seatId!.isEmpty)).toList();

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: _R.surface,
        body: Center(child: CircularProgressIndicator(color: _R.gold)),
      );
    }

    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        backgroundColor: _R.panel,
        title: Text('Plan de salle 3D', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Ajouter une table',
            onPressed: _addTable,
            icon: const Icon(Icons.add_circle_outline, color: _R.gold),
          ),
          IconButton(
            tooltip: 'Enregistrer',
            onPressed: _saving ? null : _saveLayout,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _R.gold))
                : const Icon(Icons.save_alt, color: _R.gold),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Controls lumière
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: _R.panel,
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: _R.gold, size: 18),
                const SizedBox(width: 8),
                Text('Lumière', style: GoogleFonts.inter(fontSize: 12, color: _R.text2, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _ambient,
                    min: 0.25,
                    max: 1.0,
                    activeColor: _R.gold,
                    onChanged: (v) => setState(() => _ambient = v),
                  ),
                ),
                FilterChip(
                  label: const Text('Scène', style: TextStyle(fontSize: 11)),
                  selected: _showStage,
                  onSelected: (v) => setState(() => _showStage = v),
                  selectedColor: _R.gold.withOpacity(0.3),
                  labelStyle: TextStyle(color: _showStage ? _R.gold : _R.text2),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Piste', style: TextStyle(fontSize: 11)),
                  selected: _showDance,
                  onSelected: (v) => setState(() => _showDance = v),
                  selectedColor: _R.gold.withOpacity(0.3),
                  labelStyle: TextStyle(color: _showDance ? _R.gold : _R.text2),
                ),
              ],
            ),
          ),
          // Salle 3D
          Expanded(
            flex: 3,
            child: AnimatedBuilder(
              animation: _lightCtrl,
              builder: (_, __) {
                final pulse = 0.92 + 0.08 * math.sin(_lightCtrl.value * math.pi * 2);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTableId = null),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _R.gold.withOpacity(0.12 * _ambient),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Sol + perspective
                            CustomPaint(
                              size: size,
                              painter: _RoomPainter(
                                ambient: _ambient * pulse,
                                showStage: _showStage,
                                showDance: _showDance,
                              ),
                            ),
                            // Tables
                            ..._tables.map((t) {
                              final px = t.x * size.width;
                              final py = t.y * size.height;
                              final selected = t.id == _selectedTableId;
                              final seated = _guestsAt(t);
                              return Positioned(
                                left: px - 36,
                                top: py - 36,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedTableId = t.id);
                                  },
                                  onPanUpdate: (d) => _moveTable(t.id, d.delta.dx, d.delta.dy, size),
                                  child: _TableWidget(
                                    table: t,
                                    selected: selected,
                                    seatedCount: seated.fold<int>(0, (s, g) => s + g.guestsCount),
                                    ambient: _ambient,
                                  ),
                                ),
                              );
                            }),
                            // Hint
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Text(
                                'Glissez les tables • Touchez pour assigner',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Panneau bas : détails table + invités non assignés
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: _R.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  if (_selectedTableId != null) ...[
                    _SelectedTablePanel(
                      table: _tables.firstWhere((t) => t.id == _selectedTableId),
                      guests: _guestsAt(_tables.firstWhere((t) => t.id == _selectedTableId)),
                      unassigned: _unassigned,
                      onAssign: (g) => _assignGuest(g, _tables.firstWhere((t) => t.id == _selectedTableId)),
                      onDelete: _deleteSelected,
                      onChangeLabel: (label) {
                        setState(() {
                          _tables = _tables.map((t) {
                            if (t.id != _selectedTableId) return t;
                            return t.copyWith(label: label);
                          }).toList();
                        });
                      },
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Invités non placés (${_unassigned.length})',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _R.text),
                          ),
                          const Spacer(),
                          Text(
                            '${_tables.length} tables',
                            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _unassigned.isEmpty
                          ? Center(
                              child: Text(
                                'Tous les invités sont placés ✨',
                                style: GoogleFonts.inter(color: _R.text2),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _unassigned.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final g = _unassigned[i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _R.gold.withOpacity(0.2),
                                        child: Text(
                                          g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: _R.gold, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(g.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _R.text, fontSize: 13)),
                                            Text(
                                              '${g.groupName ?? '—'} · ${g.guestsCount} pers.',
                                              style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (g.isVip)
                                        const Icon(Icons.star, size: 14, color: _R.gold),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Touchez une table',
                                        style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableWidget extends StatelessWidget {
  final SeatingTableModel table;
  final bool selected;
  final int seatedCount;
  final double ambient;

  const _TableWidget({
    required this.table,
    required this.selected,
    required this.seatedCount,
    required this.ambient,
  });

  @override
  Widget build(BuildContext context) {
    final full = seatedCount >= table.capacity;
    final color = Color(int.parse(table.colorHex.replaceFirst('#', 'FF'), radix: 16));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: table.shape == TableShape.rect || table.shape == TableShape.square
            ? BoxShape.rectangle
            : BoxShape.circle,
        borderRadius: table.shape == TableShape.rect || table.shape == TableShape.square
            ? BorderRadius.circular(12)
            : null,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.55 + 0.25 * ambient),
            color.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: selected ? Colors.white : color.withOpacity(0.9),
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35 * ambient),
            blurRadius: selected ? 18 : 10,
            spreadRadius: selected ? 2 : 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            table.label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$seatedCount/${table.capacity}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: full ? _R.rose : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedTablePanel extends StatelessWidget {
  final SeatingTableModel table;
  final List<GuestModel> guests;
  final List<GuestModel> unassigned;
  final ValueChanged<GuestModel> onAssign;
  final VoidCallback onDelete;
  final ValueChanged<String> onChangeLabel;

  const _SelectedTablePanel({
    required this.table,
    required this.guests,
    required this.unassigned,
    required this.onAssign,
    required this.onDelete,
    required this.onChangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text),
                  ),
                ),
                Text(
                  '${guests.fold<int>(0, (s, g) => s + g.guestsCount)}/${table.capacity}',
                  style: GoogleFonts.inter(color: _R.gold, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: _R.rose, size: 20),
                ),
              ],
            ),
            if (guests.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: guests
                      .map((g) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(g.name, style: const TextStyle(fontSize: 11)),
                              backgroundColor: _R.gold.withOpacity(0.15),
                              labelStyle: const TextStyle(color: _R.gold),
                              visualDensity: VisualDensity.compact,
                            ),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 6),
            Text('Assigner un invité', style: GoogleFonts.inter(fontSize: 12, color: _R.text2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Expanded(
              child: unassigned.isEmpty
                  ? Text('Aucun invité libre', style: GoogleFonts.inter(color: _R.text2, fontSize: 12))
                  : ListView.builder(
                      itemCount: unassigned.length,
                      itemBuilder: (_, i) {
                        final g = unassigned[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: _R.blue.withOpacity(0.3),
                            child: Text(g.name.isNotEmpty ? g.name[0] : '?', style: const TextStyle(fontSize: 12, color: Colors.white)),
                          ),
                          title: Text(g.name, style: GoogleFonts.inter(color: _R.text, fontSize: 13, fontWeight: FontWeight.w600)),
                          trailing: TextButton(
                            onPressed: () => onAssign(g),
                            child: const Text('Placer', style: TextStyle(color: _R.gold)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  final double ambient;
  final bool showStage;
  final bool showDance;

  _RoomPainter({required this.ambient, required this.showStage, required this.showDance});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFF1A1520), const Color(0xFF2A2035), ambient)!,
          const Color(0xFF0E0C14),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Perspective floor grid
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.04 + 0.03 * ambient)
      ..strokeWidth = 1;
    const rows = 8;
    const cols = 10;
    for (var i = 0; i <= rows; i++) {
      final y = size.height * (0.15 + 0.75 * i / rows);
      canvas.drawLine(Offset(size.width * 0.05, y), Offset(size.width * 0.95, y), grid);
    }
    for (var j = 0; j <= cols; j++) {
      final x = size.width * (0.05 + 0.9 * j / cols);
      canvas.drawLine(Offset(x, size.height * 0.15), Offset(x, size.height * 0.9), grid);
    }

    // Stage
    if (showStage) {
      final stageRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.06, size.width * 0.5, size.height * 0.1),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        stageRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _R.gold.withOpacity(0.35 * ambient),
              _R.gold.withOpacity(0.1),
            ],
          ).createShader(stageRect.outerRect),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'SCÈNE',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.09));
    }

    // Dance floor
    if (showDance) {
      final dance = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.72),
          width: size.width * 0.28,
          height: size.height * 0.18,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        dance,
        Paint()
          ..color = const Color(0xFF6B46C1).withOpacity(0.18 * ambient)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        dance,
        Paint()
          ..color = const Color(0xFF6B46C1).withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Ambient light vignette
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.1,
          colors: [
            Colors.white.withOpacity(0.06 * ambient),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.ambient != ambient || old.showStage != showStage || old.showDance != showDance;
}
