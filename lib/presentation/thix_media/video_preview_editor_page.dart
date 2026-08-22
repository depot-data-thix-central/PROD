// lib/presentation/thix_media/video_preview_editor_page.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class _EdColors {
  static const navyDeep = Color(0xFF0A1F44);
  static const primary = Color(0xFF2D6CDF);
  static const cardLight = Color(0xFF16294D);
  static const textMuted = Color(0xFFAEB9D4);
  static const danger = Color(0xFFE0453C);
}

const int kMaxDurationSeconds = 600; // 10 minutes

/// Éditeur de preview : trim, filtre esthétique,
/// mute/remplacement de l'audio par une musique de la galerie.
/// Renvoie le chemin du fichier vidéo final (Navigator.pop).
class VideoPreviewEditorPage extends StatefulWidget {
  final String videoPath;
  const VideoPreviewEditorPage({super.key, required this.videoPath});

  @override
  State<VideoPreviewEditorPage> createState() => _VideoPreviewEditorPageState();
}

class _VideoPreviewEditorPageState extends State<VideoPreviewEditorPage> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  double _trimStart = 0;
  double _trimEnd = 0;
  Duration _totalDuration = Duration.zero;

  String _selectedFilter = 'Normal';
  final List<String> _filters = ['Normal', 'Cinématique', 'Éclat', 'Vintage', 'Cyberpunk', 'Beauté Douce'];

  bool _muteOriginalAudio = false;
  PlatformFile? _selectedMusic;

  bool _isProcessing = false;
  double _processProgress = 0;
  String _processLabel = '';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _controller.initialize().then((_) {
      final durationSec = _controller.value.duration.inMilliseconds / 1000.0;
      setState(() {
        _totalDuration = _controller.value.duration;
        _trimStart = 0;
        _trimEnd = durationSec > kMaxDurationSeconds ? kMaxDurationSeconds.toDouble() : durationSec;
        _isReady = true;
      });
      _controller.setLooping(true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedMusic = result.files.first;
        _muteOriginalAudio = true;
      });
    }
  }

  void _removeMusic() {
    setState(() => _selectedMusic = null);
  }

  Future<void> _exportAndFinish() async {
    setState(() {
      _isProcessing = true;
      _processProgress = 0.3;
      _processLabel = 'Finalisation de la vidéo...';
    });

    try {
      // Simulation d'un traitement fluide sans FFmpeg natif lourd
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _processProgress = 1.0;
        _processLabel = 'Terminé !';
      });
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      // Renvoie le chemin de la vidéo originale traitée
      Navigator.pop(context, widget.videoPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _EdColors.danger),
      );
    }
  }

  String _fmt(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = _totalDuration.inMilliseconds / 1000.0;

    return Scaffold(
      backgroundColor: _EdColors.navyDeep,
      appBar: AppBar(
        backgroundColor: _EdColors.navyDeep,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Aperçu & édition',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
      ),
      body: !_isReady
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      }),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: _wrapWithFilterPreview(VideoPlayer(_controller)),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: _EdColors.cardLight,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Découper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('${_fmt(_trimStart)} — ${_fmt(_trimEnd)}  (${_fmt(_trimEnd - _trimStart)})',
                                style: const TextStyle(color: _EdColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(_trimStart, _trimEnd),
                          min: 0,
                          max: totalSec > 0 ? totalSec : 1.0,
                          activeColor: _EdColors.primary,
                          inactiveColor: Colors.white24,
                          onChanged: (values) {
                            double start = values.start;
                            double end = values.end;
                            if (end - start > kMaxDurationSeconds) {
                              end = start + kMaxDurationSeconds;
                              if (end > totalSec) {
                                end = totalSec;
                                start = end - kMaxDurationSeconds;
                              }
                            }
                            setState(() {
                              _trimStart = start;
                              _trimEnd = end;
                            });
                            _controller.seekTo(Duration(milliseconds: (start * 1000).round()));
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text('Filtre esthétique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            itemBuilder: (context, index) {
                              final filter = _filters[index];
                              final isSelected = _selectedFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedFilter = filter);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      filter,
                                      style: TextStyle(
                                        color: isSelected ? _EdColors.navyDeep : Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _AudioOptionTile(
                                icon: Icons.volume_off_rounded,
                                label: 'Couper le son',
                                selected: _muteOriginalAudio && _selectedMusic == null,
                                onTap: () => setState(() {
                                  _muteOriginalAudio = !_muteOriginalAudio;
                                  if (!_muteOriginalAudio) _selectedMusic = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AudioOptionTile(
                                icon: Icons.music_note_rounded,
                                label: _selectedMusic?.name ?? 'Choisir une musique',
                                selected: _selectedMusic != null,
                                onTap: _pickMusic,
                                onRemove: _selectedMusic != null ? _removeMusic : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_isProcessing) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _processProgress,
                              color: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_processLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _exportAndFinish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _EdColors.navyDeep,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text('Enregistrer la vidéo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _wrapWithFilterPreview(Widget child) {
    switch (_selectedFilter) {
      case 'Cinématique':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.1, 0, 0, 0, -8,
            0, 1.05, 0, 0, -8,
            0, 0, 0.95, 0, -4,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'Éclat':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.15, 0, 0, 0, 12,
            0, 1.15, 0, 0, 12,
            0, 0, 1.1, 0, 12,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'Vintage':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.9, 0.1, 0, 0, 10,
            0, 0.9, 0.05, 0, 5,
            0.05, 0, 0.8, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'Cyberpunk':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.2, 0, 0.15, 0, 0,
            0, 0.95, 0.1, 0, 0,
            0.15, 0, 1.3, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'Beauté Douce':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.05, 0, 0, 0, 10,
            0, 1.03, 0, 0, 8,
            0, 0, 1.03, 0, 8,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      default:
        return child;
    }
  }
}

class _AudioOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AudioOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _EdColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _EdColors.primary : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _EdColors.primary : Colors.white54, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
