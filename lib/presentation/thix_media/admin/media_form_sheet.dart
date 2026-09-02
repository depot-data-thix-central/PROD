/// Media Form Sheet (Production Enterprise)
/// ✅ ThixPolicy + i18n 8 langues + Semantics + logs structurés
/// ✅ CachedNetworkImage + sanitization + maxLength + mounted checks
/// ✅ HapticFeedback + throttling + confirmation fermeture
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';

import 'media_upload_notifier.dart';
import 'upload_progress.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 100;
const int _kMaxSubtitleLength = 120;
const int _kMinTitleLength = 3;
const int _kMinYear = 1900;
const int _kMaxYear = 2035;
const Duration _kSubmitThrottle = Duration(seconds: 2);

// ============================================================================
// LOGGING
// ============================================================================

class _FormLogger {
  static const _tag = 'MediaForm';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================

class _FormSanitizer {
  static String sanitize(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }
}

// ============================================================================
// FORM SHEET
// ============================================================================

class MediaFormSheet extends ConsumerStatefulWidget {
  final MediaContent? existing;
  final VoidCallback onSaved;

  const MediaFormSheet({super.key, this.existing, required this.onSaved});

  @override
  ConsumerState<MediaFormSheet> createState() => _MediaFormSheetState();
}

class _MediaFormSheetState extends ConsumerState<MediaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title, _subtitle, _year;
  String _type = 'Films';
  bool _isPublished = true, _isNew = true, _isTrending = false, _isFeedOnly = false;
  int _rank = 1;
  PlatformFile? _coverFile, _videoFile;
  DateTime? _lastSubmit;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _year = TextEditingController(text: e?.year ?? DateTime.now().year.toString());
    _type = e?.type ?? 'Films';
    _isPublished = e?.isPublished ?? true;
    _isNew = e?.isNewRelease ?? true;
    _isTrending = e?.rankPosition != null;
    _rank = e?.rankPosition ?? 1;
    _isFeedOnly = false; // TODO: e?.isFeedOnly ?? false;

    _title.addListener(_markDirty);
    _subtitle.addListener(_markDirty);
    _year.addListener(_markDirty);

    _FormLogger.info('Form initialized', {'isEdit': e != null});
  }

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void dispose() {
    _title.removeListener(_markDirty);
    _subtitle.removeListener(_markDirty);
    _year.removeListener(_markDirty);
    _title.dispose();
    _subtitle.dispose();
    _year.dispose();
    _FormLogger.info('Form disposed');
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        title: Text(
          l10n.t('form_discard_title'),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('form_discard_message'),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.t('form_discard'),
              style: const TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickCover() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.t('upload_cover_too_large_browser')),
                backgroundColor: ThixPolicy.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        setState(() {
          _coverFile = file;
          _isDirty = true;
        });
        _FormLogger.info('Cover picked', {
          'size': '${(file.size / 1024 / 1024).toStringAsFixed(1)}MB',
        });
      }
    } catch (e) {
      _FormLogger.error('Pick cover failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('upload_memory_error')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.t('upload_video_too_large_browser')),
                backgroundColor: ThixPolicy.danger,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
        setState(() {
          _videoFile = file;
          _isDirty = true;
        });
        _FormLogger.info('Video picked', {
          'size': '${(file.size / 1024 / 1024).toStringAsFixed(1)}MB',
        });
      }
    } catch (e) {
      _FormLogger.error('Pick video failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('upload_memory_error')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    // Throttle
    final now = DateTime.now();
    if (_lastSubmit != null && now.difference(_lastSubmit!) < _kSubmitThrottle) {
      _FormLogger.warn('Submit throttled');
      return;
    }
    _lastSubmit = now;

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    final l10n = AppLocalizations.of(context);

    final sanitizedTitle = _FormSanitizer.sanitize(_title.text, maxLength: _kMaxTitleLength);
    final sanitizedSubtitle = _FormSanitizer.sanitize(_subtitle.text, maxLength: _kMaxSubtitleLength);
    final sanitizedYear = _FormSanitizer.sanitize(_year.text, maxLength: 4);

    final baseItem = MediaContent(
      id: widget.existing?.id ?? '',
      title: sanitizedTitle,
      subtitle: sanitizedSubtitle,
      type: _type,
      year: sanitizedYear,
      coverUrl: widget.existing?.coverUrl ?? '',
      videoUrl: widget.existing?.videoUrl ?? '',
      viewCount: widget.existing?.viewCount ?? 0,
      rankPosition: _isTrending ? _rank : null,
      isTrending: _isTrending,
      isNewRelease: _isNew,
      isRecommended: !_isFeedOnly,
      isPublished: _isPublished,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    HapticFeedback.mediumImpact();

    try {
      await ref.read(mediaFormUploadProvider.notifier).save(
            base: baseItem,
            coverFile: _coverFile,
            videoFile: _videoFile,
            isNew: widget.existing == null,
            onSaved: widget.onSaved,
          );

      final uploadState = ref.read(mediaFormUploadProvider);
      if (uploadState.errorKey == null && mounted) {
        HapticFeedback.heavyImpact();
        _isDirty = false;
        Navigator.pop(context);
      }
    } catch (e) {
      _FormLogger.error('Save failed', {'error': '$e'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('upload_error_generic', args: {'error': e.toString()})),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final upload = ref.watch(mediaFormUploadProvider);

    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ThixPolicy.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existing == null
                          ? l10n.t('form_new_video')
                          : l10n.t('form_edit'),
                      style: ThixPolicy.h2Style.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_isTrending)
                      Semantics(
                        label: l10n.t('form_rank'),
                        child: DropdownButton<int>(
                          value: _rank,
                          items: List.generate(
                            10,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(l10n.t('form_top_n', args: {'n': '${i + 1}'})),
                            ),
                          ),
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _rank = v ?? 1);
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (upload.saving) ...[
                  UploadProgress(progress: upload.progress, statusKey: upload.statusKey, statusArgs: upload.statusArgs),
                  const SizedBox(height: 14),
                ],
                if (upload.errorKey != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.t(upload.errorKey!, args: upload.errorArgs),
                      style: TextStyle(
                        color: ThixPolicy.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                _buildFilePickers(l10n, upload.saving),
                const SizedBox(height: 16),
                _buildFormFields(l10n),
                const SizedBox(height: 8),
                _buildSwitches(l10n),
                const SizedBox(height: 18),
                _buildSubmitButton(l10n, upload.saving),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickers(AppLocalizations l10n, bool saving) {
    return RepaintBoundary(
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('form_pick_cover'),
              child: InkWell(
                onTap: saving ? null : _pickCover,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _coverFile != null ? ThixPolicy.success : ThixPolicy.border,
                      width: _coverFile != null ? 2 : 1,
                    ),
                  ),
                  child: _coverFile != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: ThixPolicy.success),
                            const SizedBox(height: 4),
                            Text(
                              '${(_coverFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: ThixPolicy.textMain,
                              ),
                            ),
                          ],
                        )
                      : widget.existing != null && widget.existing!.coverUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: widget.existing!.coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 110,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.broken_image_rounded,
                                  color: ThixPolicy.textMuted,
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_rounded, color: ThixPolicy.primary),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.t('form_cover_optional'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ThixPolicy.textMain,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.t('form_pick_video'),
              child: InkWell(
                onTap: saving ? null : _pickVideo,
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _videoFile != null ? ThixPolicy.success : ThixPolicy.border,
                      width: _videoFile != null ? 2 : 1,
                    ),
                  ),
                  child: _videoFile != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: ThixPolicy.success),
                              const SizedBox(height: 4),
                              Text(
                                '${(_videoFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ThixPolicy.textMain,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library_rounded, color: ThixPolicy.primary),
                            const SizedBox(height: 4),
                            Text(
                              l10n.t('form_video_optional'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ThixPolicy.textMain,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(AppLocalizations l10n) {
    return Column(
      children: [
        Semantics(
          label: l10n.t('form_title'),
          child: TextFormField(
            controller: _title,
            maxLength: _kMaxTitleLength,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.t('form_title_required');
              if (v.trim().length < _kMinTitleLength) return l10n.t('form_title_min');
              return null;
            },
            decoration: _dec(l10n.t('form_title')),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: l10n.t('form_subtitle'),
          child: TextFormField(
            controller: _subtitle,
            maxLength: _kMaxSubtitleLength,
            decoration: _dec(l10n.t('form_subtitle')),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: l10n.t('form_type'),
                child: DropdownButtonFormField<String>(
                  value: _type,
                  items: ['Films', 'Séries', 'Vidéos', 'Musique', 'En direct', 'Playlists']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _type = v!);
                  },
                  decoration: _dec(l10n.t('form_type')),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: l10n.t('form_year'),
                child: TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final y = int.tryParse(v ?? '');
                    if (y == null || y < _kMinYear || y > _kMaxYear) {
                      return l10n.t('form_year_invalid');
                    }
                    return null;
                  },
                  decoration: _dec(l10n.t('form_year')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitches(AppLocalizations l10n) {
    return Column(
      children: [
        Semantics(
          label: l10n.t('form_switch_published'),
          child: SwitchListTile(
            value: _isPublished,
            title: Text(
              l10n.t('form_switch_published'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: ThixPolicy.textMain,
              ),
            ),
            activeColor: ThixPolicy.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _isPublished = v);
            },
          ),
        ),
        Semantics(
          label: l10n.t('form_switch_feed_only'),
          child: SwitchListTile(
            value: _isFeedOnly,
            title: Text(
              l10n.t('form_switch_feed_only'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: ThixPolicy.textMain,
              ),
            ),
            subtitle: Text(
              l10n.t('form_switch_feed_only_hint'),
              style: TextStyle(fontSize: 11, color: ThixPolicy.textMuted),
            ),
            activeColor: ThixPolicy.success,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() {
                _isFeedOnly = v;
                if (v) {
                  _isNew = false;
                  _isTrending = false;
                }
              });
            },
          ),
        ),
        Semantics(
          label: l10n.t('form_switch_new'),
          enabled: !_isFeedOnly,
          child: SwitchListTile(
            value: _isNew,
            title: Text(
              l10n.t('form_switch_new'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _isFeedOnly ? ThixPolicy.textMuted : ThixPolicy.textMain,
              ),
            ),
            activeColor: ThixPolicy.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: _isFeedOnly
                ? null
                : (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _isNew = v);
                  },
          ),
        ),
        Semantics(
          label: l10n.t('form_switch_trending'),
          enabled: !_isFeedOnly,
          child: SwitchListTile(
            value: _isTrending,
            title: Text(
              l10n.t('form_switch_trending'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: _isFeedOnly ? ThixPolicy.textMuted : ThixPolicy.textMain,
              ),
            ),
            activeColor: ThixPolicy.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: _isFeedOnly
                ? null
                : (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _isTrending = v);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n, bool saving) {
    return Semantics(
      button: true,
      label: widget.existing == null ? l10n.t('form_create') : l10n.t('form_save'),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ThixPolicy.border,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                    value: ref.watch(mediaFormUploadProvider).progress > 0
                        ? ref.watch(mediaFormUploadProvider).progress
                        : null,
                  ),
                )
              : Text(
                  widget.existing == null ? l10n.t('form_create') : l10n.t('form_save'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: ThixPolicy.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThixPolicy.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThixPolicy.primary, width: 1.5),
        ),
      );
}
