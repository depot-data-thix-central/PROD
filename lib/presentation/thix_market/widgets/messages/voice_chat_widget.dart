// lib/presentation/thix_market/widgets/chat/voice_chat_widget.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceChatWidget extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final Function(File)? onAudioRecorded;

  const VoiceChatWidget({
    super.key,
    required this.conversationId,
    required this.receiverId,
    this.onAudioRecorded,
  });

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _audioPlayer;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  AudioPlayer? _player;

  // Couleurs de l'application
  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _audioPlayer = AudioPlayer();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _playbackPosition = position;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone refusée')),
        );
        return;
      }
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du démarrage de l\'enregistrement')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
      });

      if (path != null && mounted) {
        final file = File(path);
        if (file.existsSync()) {
          widget.onAudioRecorded?.call(file);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message vocal enregistré'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording(File audioFile) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    try {
      await _audioPlayer.play(DeviceFileSource(audioFile.path));
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de lecture audio')),
      );
    }
  }

  Future<void> _resumeRecording() async {
    // La reprise n'est pas gérée par Record, on recommence
    // On pourrait implémenter une pause/reprise mais c'est complexe
    // On va simplement stopper et recommencer
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée de fermeture
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text(
            'Message vocal temporaire',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre message sera supprimé après écoute',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 24),

          if (_isRecording)
            _buildRecordingUI()
          else if (_recordingPath != null)
            _buildPlaybackUI()
          else
            _buildRecordingButtonUI(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: danger.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, size: 30, color: danger),
        ),
        const SizedBox(height: 12),
        Text(
          _formatDuration(_recordingDuration),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 12),
        _buildWaveAnimation(),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _stopRecording,
          icon: const Icon(Icons.stop),
          label: const Text('Arrêter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackUI() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: gold.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => _playRecording(File(_recordingPath!)),
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 30,
            ),
            color: gold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_formatDuration(_playbackPosition)} / ${_formatDuration(_recordingDuration)}',
          style: const TextStyle(fontSize: 16, color: navy),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _recordingDuration.inSeconds > 0
              ? _playbackPosition.inSeconds / _recordingDuration.inSeconds
              : 0,
          backgroundColor: Colors.grey[200],
          color: gold,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _recordingPath = null;
                    _recordingDuration = Duration.zero;
                    _playbackPosition = Duration.zero;
                  });
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  foregroundColor: textMuted,
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_recordingPath != null) {
                    widget.onAudioRecorded?.call(File(_recordingPath!));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Envoyer'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordingButtonUI() {
    return Column(
      children: [
        GestureDetector(
          onLongPress: _startRecording,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: gold, width: 2),
            ),
            child: const Icon(Icons.mic, size: 40, color: gold),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Maintenez enfoncé pour enregistrer',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Relâchez pour arrêter',
          style: TextStyle(fontSize: 10, color: textMuted),
        ),
      ],
    );
  }

  Widget _buildWaveAnimation() {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final height = 15 + (index * 5) + (_recordingDuration.inSeconds % 5);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 4,
            height: height.toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
