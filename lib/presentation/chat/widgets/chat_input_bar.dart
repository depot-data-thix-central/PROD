// lib/presentation/chat/widgets/chat_input_bar.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/widgets/chat_common.dart';
import 'package:thix_id/presentation/chat/widgets/chat_message_bubble.dart' show ChatWaveformAudioPlayer;

const String _kCustomStickersPrefKey = 'thix_custom_stickers_v1';

/// Contenu envoyé par la barre de saisie vers l'écran principal.
class ChatInputPayload {
  final String text;
  final List<PlatformFile> files;
  final Uint8List? audioBytes;
  final int audioDuration;
  final String audioExt;
  final bool viewOnce;
  const ChatInputPayload({
    required this.text,
    this.files = const [],
    this.audioBytes,
    this.audioDuration = 0,
    this.audioExt = 'm4a',
    this.viewOnce = false,
  });
}

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEditing;
  final bool isAgent;
  final bool isInternalNoteMode;
  final bool isEphemeral;
  final void Function(ChatInputPayload payload) onSubmit;
  final Future<void> Function(Uint8List bytes) onSendSticker;
  final VoidCallback onCancelEdit;
  final VoidCallback onEphemeralTap;
  final VoidCallback onProtectedTap;
  final VoidCallback onToggleInternalNote;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onSendSticker,
    required this.onCancelEdit,
    required this.onEphemeralTap,
    required this.onProtectedTap,
    required this.onToggleInternalNote,
    this.isEditing = false,
    this.isAgent = false,
    this.isInternalNoteMode = false,
    this.isEphemeral = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  bool _isPaused = false;
  String _recordExt = 'm4a';
  Uint8List? _audioBytes;
  String? _localAudioPath;
  bool _sendViewOnce = false;
  List<PlatformFile> _files = [];
  bool _showStickers = false;
  final List<Uint8List> _customStickers = <Uint8List>[];

  static List<String> _uniq(List<String> l) => l.toSet().toList();

  static final List<String> _emojis = _uniq(const [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇',
    '🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚',
    '😋','😛','😜','😝','🤑','🤗','🤭','🤫','🤔','🤐',
    '😐','😑','😶','😏','😒','🙄','😬','😮‍💨','😔','😪',
    '🤤','😴','😷','🤒','🤕','🤢','🤮','🥵','🥶','🥴',
    '😵','😵‍💫','🤯','🤠','🥳','🥸','😎','🤓','🧐','😕',
    '😟','🙁','☹️','😮','😯','😲','😳','🥺','😦','😧',
    '😨','😰','😥','😢','😭','😱','😖','😣','😞','😓',
    '😩','😫','🥱','😤','😡','😠','🤬','🤡','👹','👺',
    '👻','💀','☠️','👽','👾','🤖','💩','😺','😸','😹',
    '😻','😼','😽','🙀','😿','😾','🫠','🫡','🫢','🫣',
    '🫤','🫥','🫨','🥹','🥲','🫶','🤩','😈','👿','🙈',
    '🙉','🙊','💯','✨','🔥','⭐','🌟','💫','💥','💢',
  ]);

  static final List<String> _reactions = _uniq(const [
    '👍','👎','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘',
    '🤙','👈','👉','👆','👇','☝️','👋','🤚','🖐️','✋',
    '🖖','👏','🙌','👐','🤲','🤝','🙏','💪','🦾','✍️',
    '💅','🤳','👊','✊','🤛','🤜','🫂','🫳','🫴','🫵',
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','🩷',
    '🩵','🩶','💔','❤️‍🔥','❤️‍🩹','❣️','💕','💞','💓','💗',
    '💖','💘','💝','💟','♥️','💌','💋',
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇',
    '🙂','😉','🥰','😍','😘','🤩','🥳','😎','🤗','🤪',
    '😮','😯','😲','😳','🤯','😱','😵','🤨','🧐',
    '😔','😟','🙁','😞','😓','😩','😫','🥺','😢','😭',
    '😤','😡','😠','🤬','😈',
    '✅','☑️','✔️','🏆','🥇','🥈','🥉','🎯','💡',
    '❌','🚫','⛔','⚠️','🙅','🤦','❗','❓','‼️','⁉️',
    '⚡','🚀','🏅','🎖️','👑','💎','🎉','🎊','🎈','🎁',
    '🎂','🍰','🍾','🥂','🎆','🎇','🪩','🪅',
    '💭','🧠','😮‍💨','😴','🥱','😌','☀️','🌈',
  ]);

  static final List<String> _objects = _uniq(const [
    '📱','💻','🖥️','⌨️','🖱️','🖨️','💾','💿','📀','📷',
    '📸','📹','📼','🎥','📽️','📡','🛰️','📟','🔌','🔋',
    '🔦','🔍','🔎','🕹️','🎮','💽',
    '📝','📄','📃','📑','📊','📈','📉','📋','📌','📍',
    '📎','🖇️','📐','📏','✏️','✒️','🖊️','🖋️','🗂️','📁',
    '📂','🗄️','🗃️','🗑️','📦','📬','📭','📮','📫','📚',
    '📖','📕','📗','📘','📙','📒','📓','📔','📇','🗒️',
    '📅','📆','🗓️','⏰','⌚','⏳','⌛',
    '💼','🧰','🔧','🔨','⚙️','🪛','🪚','🪓','⛏️','🔩',
    '🧲','🪜','🧱','🛠️','🧯','🪣','🧹','🧺','🧴','🧼',
    '🪥','🪒','🔑','🗝️','🔒','🔓','🔐','🔏','🪢',
    '💰','💵','💴','💶','💷','💳','🪙','🏧','🧾',
    '🏷️','🛒','🛍️','💸','💲','💹','🏪','🏬','🏭','🏦',
    '🏠','🏡','🏢','🚪','🪟','🛋️','🪑','🛏️','🚿','🛁',
    '🚽','🪞','🕯️','🪴','🍽️','🥄','🍴','🔪','☕','🫖','🍳',
    '💊','💉','🩺','🩹','🧬','🔬','🔭','🧪','🧫','🧮',
    '🦷','🩻','🩼','🦽','🦯','⚕️',
    '🚗','🚕','🚙','🚌','🚎','🚓','🚑','🚒','🚚','🚛',
    '🚜','🏍️','🛵','🚲','🛴','🛹','🚆','🚇','🚉','🚂',
    '🚃','🚋','🚝','🚄','🚅','🚈','🚞','🚊','✈️','🛫',
    '🛬','🚁','🛸','🚀','⛵','🚤','🛥️','🚢','🛳️','⚓',
    '🛟','🗺️','🧭','🛣️','🛤️','⛽','🚦','🚧','🅿️',
    '🍎','🍏','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐',
    '🍒','🍑','🥭','🍍','🥥','🥝','🍅','🥑','🥦','🥕',
    '🌽','🥔','🍠','🧅','🧄','🍞','🥐','🥖','🥨','🧀',
    '🥚','🍗','🍖','🍔','🍟','🍕','🌭','🌮','🌯',
    '🥪','🥗','🍝','🍜','🍲','🍛','🍣','🍤','🍚','🍙',
    '🍱','🥟','🧁','🍩','🍪','🍫','🍬','🍭',
    '🍿','🍯','🥜','🍵','🧃','🥤','🧋',
    '🎧','🎤','🎙️','🎸','🎹','🥁','🎺','🎻','🎷','🪕',
    '🎼','🎵','🎶','🎬','🎞️','🎭','🎨','🖌️','🖍️','🧩',
    '🎲','♟️','🎪','🎡','🎢','🎠','🎫','🎟️',
    '🎀','🧨','💐',
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱',
    '🏓','🏸','🏒','🏑','🥍','🏏','🥊','🥋','⛳','🏹',
    '🎣','🤿','🏋️','🤸','⛹️','🤾','🏊','🚴','🏃','🧗','🎽',
    '🌱','🌿','☘️','🍀','🌳','🌲','🌴','🌵','🌾','🌻',
    '🌹','🌷','🌺','🌸','🌼','🪻','🪷','🍁','🍂','🍃',
    '🌍','🌎','🌏','🌙','🌞','🌝','🌚',
    '☁️','⛅','🌤️','🌧️','⛈️','🌩️','🌨️','❄️','🌪️',
    '🌊','💧','💦','🌋','🏔️','🗻','🏝️','🏜️','🏕️','🏞️','🏖️',
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯',
    '🦁','🐮','🐷','🐸','🐵','🐔','🐧',
    '🐦','🐤','🦆','🦅','🦉','🦇','🐺','🐗','🐴','🦄',
    '🐝','🦋','🐌','🐞','🐜','🕷️','🐢','🐍','🦎','🐙',
    '🦑','🦀','🐠','🐟','🐬','🐳','🐋','🦈','🐊','🦓',
    '🦒','🐘','🦏','🦛','🐪','🐫','🦘','🦥','🦦','🦫',
    '🏥','🏨','🏫','⛪','🕌','🕍','⛩️','🛕','🏛️',
    '🗼','🗽','🗿','🏰','🏯','⛺','🏟️',
  ]);

  static final List<String> _flags = _uniq(const [
    '🇦🇱','🇦🇩','🇦🇹','🇧🇾','🇧🇪','🇧🇦','🇧🇬','🇭🇷','🇨🇾','🇨🇿',
    '🇩🇰','🇪🇪','🇫🇮','🇫🇷','🇩🇪','🇬🇷','🇭🇺','🇮🇸','🇮🇪','🇮🇹',
    '🇽🇰','🇱🇻','🇱🇮','🇱🇹','🇱🇺','🇲🇹','🇲🇩','🇲🇨','🇲🇪','🇳🇱',
    '🇲🇰','🇳🇴','🇵🇱','🇵🇹','🇷🇴','🇷🇺','🇸🇲','🇷🇸','🇸🇰','🇸🇮',
    '🇪🇸','🇸🇪','🇨🇭','🇺🇦','🇬🇧','🇻🇦',
    '🇩🇿','🇦🇴','🇧🇯','🇧🇼','🇧🇫','🇧🇮','🇨🇻','🇨🇲','🇨🇫','🇹🇩',
    '🇰🇲','🇨🇬','🇨🇩','🇨🇮','🇩🇯','🇪🇬','🇬🇶','🇪🇷','🇸🇿','🇪🇹',
    '🇬🇦','🇬🇲','🇬🇭','🇬🇳','🇬🇼','🇰🇪','🇱🇸','🇱🇷','🇱🇾','🇲🇬',
    '🇲🇼','🇲🇱','🇲🇷','🇲🇺','🇲🇦','🇲🇿','🇳🇦','🇳🇪','🇳🇬','🇷🇼',
    '🇸🇹','🇸🇳','🇸🇨','🇸🇱','🇸🇴','🇿🇦','🇸🇸','🇸🇩','🇹🇿','🇹🇬',
    '🇹🇳','🇺🇬','🇿🇲','🇿🇼',
    '🇦🇬','🇧🇸','🇧🇧','🇧🇿','🇨🇦','🇨🇷','🇨🇺','🇩🇲','🇩🇴','🇸🇻',
    '🇬🇩','🇬🇹','🇭🇹','🇭🇳','🇯🇲','🇲🇽','🇳🇮','🇵🇦','🇰🇳','🇱🇨',
    '🇻🇨','🇹🇹','🇺🇸',
    '🇦🇷','🇧🇴','🇧🇷','🇨🇱','🇨🇴','🇪🇨','🇬🇾','🇵🇾','🇵🇪','🇸🇷',
    '🇺🇾','🇻🇪',
    '🇦🇫','🇦🇲','🇦🇿','🇧🇭','🇧🇩','🇧🇹','🇧🇳','🇰🇭','🇨🇳','🇬🇪',
    '🇮🇳','🇮🇩','🇮🇷','🇮🇶','🇮🇱','🇯🇵','🇯🇴','🇰🇿','🇰🇼','🇰🇬',
    '🇱🇦','🇱🇧','🇲🇾','🇲🇻','🇲🇳','🇲🇲','🇳🇵','🇰🇵','🇴🇲','🇵🇰',
    '🇵🇸','🇵🇭','🇶🇦','🇸🇦','🇸🇬','🇰🇷','🇱🇰','🇸🇾','🇹🇯','🇹🇭',
    '🇹🇱','🇹🇷','🇹🇲','🇦🇪','🇺🇿','🇻🇳','🇾🇪',
    '🇦🇺','🇫🇯','🇰🇮','🇲🇭','🇫🇲','🇳🇷','🇳🇿','🇵🇼','🇵🇬','🇼🇸',
    '🇸🇧','🇹🇴','🇹🇻','🇻🇺',
    '🇦🇽','🇦🇸','🇦🇼','🇧🇲','🇧🇶','🇨🇽','🇨🇨','🇨🇰','🇨🇼','🇫🇴',
    '🇬🇮','🇬🇱','🇬🇵','🇬🇺','🇭🇰','🇮🇲','🇯🇪','🇰🇾','🇲🇴',
    '🇲🇶','🇲🇸','🇳🇨','🇳🇫','🇵🇫','🇵🇷','🇷🇪','🇸🇽','🇹🇨','🇻🇬',
    '🇻🇮',
  ]);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _loadCustomStickers();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus && _showStickers && mounted) setState(() => _showStickers = false);
  }

  // ==========================================================================
  // ENVOI
  // ==========================================================================
  void _submit() {
    final text = widget.controller.text.trim();
    if (widget.isEditing) {
      widget.onSubmit(ChatInputPayload(text: text));
      return;
    }
    if (text.isEmpty && _files.isEmpty && _audioBytes == null) return;
    final payload = ChatInputPayload(
      text: text,
      files: List<PlatformFile>.from(_files),
      audioBytes: _audioBytes,
      audioDuration: _recordDuration > 0 ? _recordDuration : 1,
      audioExt: _recordExt,
      viewOnce: _sendViewOnce,
    );
    setState(() {
      _files = [];
      _audioBytes = null;
      _localAudioPath = null;
      _sendViewOnce = false;
      _showStickers = false;
    });
    widget.onSubmit(payload);
  }

  // ==========================================================================
  // ENREGISTREMENT AUDIO
  // ==========================================================================
  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    if (_isRecording) return;
    HapticFeedback.mediumImpact();
    final ok = await chatCheckPermission(context, Permission.microphone, chatTr(l10n, 'chat_mic_disclosure', 'Le micro est nécessaire pour les messages vocaux.'));
    if (!ok || !mounted) return;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tmp = kIsWeb ? null : (await getTemporaryDirectory()).path;
      final configs = kIsWeb
          ? <Map<String, dynamic>>[
              {'cfg': const RecordConfig(encoder: AudioEncoder.opus, bitRate: 128000), 'ext': 'webm', 'path': 'audio_$ts.webm'},
              {'cfg': const RecordConfig(encoder: AudioEncoder.wav, bitRate: 128000), 'ext': 'wav', 'path': 'audio_$ts.wav'},
            ]
          : <Map<String, dynamic>>[
              {'cfg': const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), 'ext': 'm4a', 'path': p.join(tmp!, 'audio_$ts.m4a')},
              {'cfg': const RecordConfig(encoder: AudioEncoder.wav, bitRate: 128000), 'ext': 'wav', 'path': p.join(tmp, 'audio_$ts.wav')},
            ];
      Object? lastError;
      bool started = false;
      for (final c in configs) {
        try {
          await _recorder.start(c['cfg'] as RecordConfig, path: c['path'] as String);
          _recordExt = c['ext'] as String;
          _localAudioPath = c['path'] as String;
          started = true;
          break;
        } catch (e) {
          lastError = e;
        }
      }
      if (!started) throw lastError ?? StateError('Recorder unavailable');
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordDuration = 0;
        _audioBytes = null;
        _showStickers = false;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _isPaused) return;
        setState(() => _recordDuration++);
        if (_recordDuration >= kChatMaxAudioSeconds) _stopRecording();
      });
    } catch (e) {
      chatLog('[Input] ❌ start recording: $e');
      if (mounted) chatSnack(context, chatTr(l10n, 'chat_recording_error', 'Erreur d’enregistrement'), ChatSnackKind.error);
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      if (mounted) setState(() => _isPaused = true);
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();
      if (mounted) setState(() => _isPaused = false);
    } catch (_) {}
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _audioBytes = null;
        _localAudioPath = null;
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _recorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        final bytes = await _fetchAudioBytes(path);
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
            _isPaused = false;
          });
        }
      }
    } catch (e) {
      chatLog('[Input] ❌ stop recording: $e');
      if (mounted) chatSnack(context, chatTr(AppLocalizations.of(context), 'chat_recording_error', 'Erreur d’enregistrement'), ChatSnackKind.error);
    }
  }

  Future<Uint8List> _fetchAudioBytes(String path) async {
    if (kIsWeb) {
      final r = await http.get(Uri.parse(path)).timeout(const Duration(seconds: 15));
      return r.bodyBytes;
    }
    return File(path).readAsBytes();
  }

  // ==========================================================================
  // PHOTOS / FICHIERS
  // ==========================================================================
  Future<void> _pickFromCamera() async {
    HapticFeedback.selectionClick();
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1920);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!ChatValidators.isValidFileSize(bytes.length)) {
        if (mounted) chatSnack(context, chatTr(AppLocalizations.of(context), 'chat_file_too_big', 'Fichier trop volumineux'), ChatSnackKind.warning);
        return;
      }
      if (mounted) setState(() => _files.add(PlatformFile(name: x.name, size: bytes.length, bytes: bytes)));
    } catch (e) {
      if (mounted) chatSnack(context, ChatValidators.friendlyError(e), ChatSnackKind.error);
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();
    try {
      final list = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1920);
      if (list.isEmpty) return;
      final added = <PlatformFile>[];
      for (final x in list) {
        final bytes = await x.readAsBytes();
        if (ChatValidators.isValidFileSize(bytes.length)) added.add(PlatformFile(name: x.name, size: bytes.length, bytes: bytes));
      }
      if (mounted && added.isNotEmpty) setState(() => _files.addAll(added));
    } catch (e) {
      if (mounted) chatSnack(context, ChatValidators.friendlyError(e), ChatSnackKind.error);
    }
  }

  Future<void> _pickFile() async {
    HapticFeedback.selectionClick();
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        final valid = result.files.where((f) => ChatValidators.isValidFileSize(f.size) && ChatValidators.isAllowedExtension(f.extension)).toList();
        if (valid.length < result.files.length && mounted) {
          chatSnack(context, '${chatTr(AppLocalizations.of(context), 'chat_file_rejected', 'Fichier refusé (taille ou type) :')} ${result.files.length - valid.length}', ChatSnackKind.warning);
        }
        if (valid.isNotEmpty && mounted) setState(() => _files.addAll(valid));
      }
    } catch (e) {
      if (mounted) chatSnack(context, ChatValidators.friendlyError(e), ChatSnackKind.error);
    }
  }

  void _removeFile(int i) {
    HapticFeedback.lightImpact();
    setState(() => _files.removeAt(i));
  }

  // ==========================================================================
  // STICKERS PERSO
  // ==========================================================================
  Future<void> _loadCustomStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kCustomStickersPrefKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _customStickers.clear();
        for (final b64 in list) {
          try {
            _customStickers.add(base64Decode(b64));
          } catch (_) {}
        }
      });
    } catch (e) {
      chatLog('[Input] ⚠️ loadCustomStickers: $e');
    }
  }

  Future<void> _persistCustomStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kCustomStickersPrefKey, _customStickers.map(base64Encode).toList());
    } catch (e) {
      chatLog('[Input] ⚠️ persistCustomStickers: $e');
    }
  }

  Future<void> _addCustomSticker() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ThixPolicy.card,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(chatTr(l10n, 'chat_camera', 'Caméra')), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(chatTr(l10n, 'chat_gallery', 'Galerie')), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, imageQuality: 90, maxWidth: 512, maxHeight: 512);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > kChatMaxStickerBytes) {
        if (mounted) chatSnack(context, chatTr(l10n, 'chat_sticker_too_big', 'Sticker trop lourd (max 512 Ko)'), ChatSnackKind.warning);
        return;
      }
      if (!mounted) return;
      setState(() => _customStickers.insert(0, bytes));
      await _persistCustomStickers();
      if (mounted) chatSnack(context, chatTr(l10n, 'chat_sticker_created', 'Sticker créé'), ChatSnackKind.success);
    } catch (e) {
      if (mounted) chatSnack(context, ChatValidators.friendlyError(e), ChatSnackKind.error);
    }
  }

  // ==========================================================================
  // MENU « + »
  // ==========================================================================
  void _showAttachSheet() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final items = <_AttachItem>[
      _AttachItem(Icons.insert_drive_file_rounded, chatTr(l10n, 'chat_file', 'Fichier'), const Color(0xFF7E57C2), _pickFile),
      _AttachItem(Icons.photo_camera_rounded, chatTr(l10n, 'chat_camera', 'Caméra'), const Color(0xFFE53935), _pickFromCamera),
      _AttachItem(Icons.photo_library_rounded, chatTr(l10n, 'chat_gallery', 'Galerie'), const Color(0xFF43A047), _pickFromGallery),
      _AttachItem(Icons.timer_outlined, chatTr(l10n, 'chat_ephemeral', 'Éphémère'), const Color(0xFFFB8C00), widget.onEphemeralTap),
      _AttachItem(Icons.lock_outline_rounded, chatTr(l10n, 'chat_protected', 'Protégé'), const Color(0xFF546E7A), widget.onProtectedTap),
      if (widget.isAgent)
        _AttachItem(Icons.note_alt_outlined, chatTr(l10n, 'chat_internal_note', 'Note interne'), const Color(0xFF8D6E63), widget.onToggleInternalNote),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: items
                  .map((it) => InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(ctx);
                          it.onTap();
                        },
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: it.color.withOpacity(0.14), shape: BoxShape.circle),
                            child: Icon(it.icon, color: it.color, size: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(it.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                        ]),
                      ))
                  .toList(),
            ),
          ]),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasViewOnceCandidate = _files.any((f) => ChatValidators.isImageExt(f.extension));
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(top: BorderSide(color: ThixPolicy.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_files.isNotEmpty) ChatFilesPreview(files: _files, onRemove: _removeFile),
          if (hasViewOnceCandidate && !widget.isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sendViewOnce = !_sendViewOnce);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sendViewOnce ? ThixPolicy.inkDeep : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _sendViewOnce ? ThixPolicy.inkDeep : ThixPolicy.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.visibility_off_rounded, size: 14, color: _sendViewOnce ? Colors.white : ThixPolicy.textSecondary),
                      const SizedBox(width: 6),
                      Text(chatTr(l10n, 'chat_view_once', 'View once'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _sendViewOnce ? Colors.white : ThixPolicy.textSecondary)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(chatTr(l10n, 'chat_view_once_hint', 'Le média s’efface après ouverture'), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted))),
              ]),
            ),
          if ((widget.isEphemeral || widget.isInternalNoteMode) && !_isRecording)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(children: [
                if (widget.isEphemeral) _chip(Icons.timer_outlined, chatTr(l10n, 'chat_ephemeral', 'Éphémère'), widget.onEphemeralTap),
                if (widget.isEphemeral && widget.isInternalNoteMode) const SizedBox(width: 6),
                if (widget.isInternalNoteMode) _chip(Icons.note_alt_outlined, chatTr(l10n, 'chat_internal_note', 'Note interne'), widget.onToggleInternalNote),
              ]),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 8), child: _mainRow(l10n)),
          if (_showStickers) _buildStickerPicker(l10n),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: ThixPolicy.inkDeep),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
          ]),
        ),
      );

  Widget _mainRow(AppLocalizations l10n) {
    // 1) Aperçu audio enregistré
    if (_localAudioPath != null && !_isRecording && _audioBytes != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [ThixPolicy.inkDeep, ThixPolicy.inkDeep.withOpacity(0.85)]), borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          const Icon(Icons.mic_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(child: ChatWaveformAudioPlayer(audioUrl: _localAudioPath!, isLocal: true, onDark: true)),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
            onPressed: () => setState(() {
              _audioBytes = null;
              _localAudioPath = null;
            }),
          ),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: ThixPolicy.inkDeep, size: 18),
            ),
          ),
        ]),
      );
    }
    // 2) Enregistrement en cours
    if (_isRecording) return _buildRecordingBar(l10n);

    // 3) Saisie normale
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final hasContent = hasText || _files.isNotEmpty;
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!widget.isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 6),
              child: _RoundIconButton(icon: Icons.add_rounded, onTap: _showAttachSheet),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 6),
              child: _RoundIconButton(icon: Icons.close_rounded, onTap: widget.onCancelEdit),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_showStickers ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded, color: ThixPolicy.textSecondary, size: 24),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (_showStickers) {
                      setState(() => _showStickers = false);
                      widget.focusNode.requestFocus();
                    } else {
                      FocusScope.of(context).unfocus();
                      setState(() => _showStickers = true);
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 6,
                    minLines: 1,
                    maxLength: kChatMaxMessageLength,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 15.5, color: ThixPolicy.textMain),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: widget.isEditing
                          ? chatTr(l10n, 'chat_editing_hint', 'Modifier le message…')
                          : chatTr(l10n, 'chat_write_message', 'Écrire un message… (@ pour mentionner)'),
                      hintStyle: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (!hasText && !widget.isEditing)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.photo_camera_outlined, color: ThixPolicy.textSecondary, size: 24),
                    onPressed: _pickFromCamera,
                  )
                else
                  const SizedBox(width: 10),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          ChatFluidSendButton(
            hasContent: hasContent,
            isEditing: widget.isEditing,
            onTap: () {
              HapticFeedback.lightImpact();
              if (hasContent || widget.isEditing) {
                _submit();
              } else {
                _startRecording();
              }
            },
          ),
        ]);
      },
    );
  }

  Widget _buildRecordingBar(AppLocalizations l10n) {
    final mm = (_recordDuration ~/ 60).toString().padLeft(2, '0');
    final ss = (_recordDuration % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ThixPolicy.danger.withOpacity(0.14), ThixPolicy.danger.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Icon(_isPaused ? Icons.pause_circle_outline_rounded : Icons.mic_rounded, color: ThixPolicy.danger, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _isPaused ? '${chatTr(l10n, 'chat_recording_paused', 'Pause')}  $mm:$ss' : '${chatTr(l10n, 'chat_recording', 'Enregistrement')}  $mm:$ss',
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
          ),
        ),
        IconButton(
          icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: ThixPolicy.danger),
          onPressed: _isPaused ? _resumeRecording : _pauseRecording,
          tooltip: chatTr(l10n, 'chat_pause', 'Pause'),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.textSecondary),
          onPressed: _cancelRecording,
          tooltip: chatTr(l10n, 'common_cancel', 'Annuler'),
        ),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  // ==========================================================================
  // STICKERS / EMOJIS
  // ==========================================================================
  Widget _buildStickerPicker(AppLocalizations l10n) {
    return SizedBox(
      height: 260,
      child: DefaultTabController(
        length: 5,
        child: Column(children: [
          TabBar(
            labelColor: ThixPolicy.inkDeep,
            unselectedLabelColor: ThixPolicy.textMuted,
            indicatorColor: ThixPolicy.inkDeep,
            isScrollable: true,
            tabs: [
              Tab(text: chatTr(l10n, 'chat_emojis', 'Emojis')),
              Tab(text: chatTr(l10n, 'chat_reactions', 'Réactions')),
              Tab(text: chatTr(l10n, 'chat_objects', 'Objets')),
              Tab(text: chatTr(l10n, 'chat_flags', 'Drapeaux')),
              Tab(text: chatTr(l10n, 'chat_my_stickers', 'Mes stickers')),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _buildEmojiGrid(_emojis),
              _buildEmojiGrid(_reactions),
              _buildEmojiGrid(_objects),
              _buildEmojiGrid(_flags),
              _buildCustomStickerGrid(l10n),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => Semantics(
        button: true,
        label: 'Emoji ${items[index]}',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            final c = widget.controller;
            c.text += items[index];
            c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
          },
          child: Center(child: Text(items[index], style: const TextStyle(fontSize: 24))),
        ),
      ),
    );
  }

  Widget _buildCustomStickerGrid(AppLocalizations l10n) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: _customStickers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: _addCustomSticker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: ThixPolicy.inkDeep), borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: ThixPolicy.inkDeep),
                const SizedBox(height: 4),
                Text(chatTr(l10n, 'chat_sticker_create', 'Créer'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.inkDeep)),
              ]),
            ),
          );
        }
        final bytes = _customStickers[index - 1];
        return InkWell(
          onTap: () {
            setState(() => _showStickers = false);
            widget.onSendSticker(bytes);
          },
          onLongPress: () {
            setState(() => _customStickers.removeAt(index - 1));
            _persistCustomStickers();
          },
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, fit: BoxFit.cover)),
        );
      },
    );
  }
}

class _AttachItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _AttachItem(this.icon, this.label, this.color, this.onTap);
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
        child: Icon(icon, color: ThixPolicy.inkDeep, size: 24),
      ),
    );
  }
}

// ============================================================================
// BOUTON ENVOI FLUIDE (neutre, sans jaune)
// ============================================================================
class ChatFluidSendButton extends StatefulWidget {
  final bool hasContent;
  final bool isEditing;
  final VoidCallback onTap;
  const ChatFluidSendButton({super.key, required this.hasContent, required this.onTap, this.isEditing = false});
  @override
  State<ChatFluidSendButton> createState() => _ChatFluidSendButtonState();
}

class _ChatFluidSendButtonState extends State<ChatFluidSendButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final IconData icon = widget.isEditing ? Icons.check_rounded : (widget.hasContent ? Icons.send_rounded : Icons.mic_rounded);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ThixPolicy.inkDeep,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(widget.hasContent ? 0.22 : 0.10), blurRadius: widget.hasContent ? 8 : 4, offset: const Offset(0, 2))],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
              child: Icon(icon, key: ValueKey(icon.codePoint), color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// APERÇU FICHIERS
// ============================================================================
class ChatFilesPreview extends StatelessWidget {
  final List<PlatformFile> files;
  final void Function(int) onRemove;
  const ChatFilesPreview({super.key, required this.files, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 74,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (ctx, i) {
          final f = files[i];
          final ext = f.extension?.toLowerCase() ?? '';
          final isImg = ChatValidators.isImageExt(ext);
          final safeName = ChatValidators.sanitize(f.name, maxLength: 50);
          return Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 58,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThixPolicy.border)),
              clipBehavior: Clip.hardEdge,
              child: isImg && f.bytes != null
                  ? Image.memory(f.bytes!, fit: BoxFit.cover, cacheWidth: 160)
                  : Center(child: Icon(ChatValidators.iconForExtension(ext), color: ThixPolicy.inkDeep, size: 24)),
            ),
            Positioned(
              top: -4,
              right: 4,
              child: Semantics(
                button: true,
                label: '${chatTr(l10n, 'common_remove', 'Retirer')} $safeName',
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 12, color: Colors.white)),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
