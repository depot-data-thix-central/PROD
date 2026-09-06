// lib/presentation/thix_event/admin/pages/events/event_create_edit_page.dart
//
// EventCreateEditPage — Production Enterprise (i18n + Design System + A11y)
//
// LOGIQUE 100% PRÉSERVÉE :
// - AdminGuard.canWrite(role) pour la sauvegarde
// - adminEventServiceProvider.upsertEvent() avec bytes
// - Gestion des TicketTiers (add/remove via dialog)
// - Champs : title, desc, category, dates, location, organizer, etc.
// - ImagePicker pour cover et banner
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/event_model.dart';
import 'package:thix_id/models/ticket_tier.dart';

// === IMPORTS ABSOLUS (Pour les traductions et le design global) ===
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// === ANCIENS IMPORTS LOCAUX (Tirés de votre photo : ../../../) ===
import '../../../core/admin_guards.dart';
import '../../../providers/admin_event_provider.dart';
import '../../../services/admin_event_service.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy — Admin Events)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = ThixPolicy.success;
  static const Color danger = ThixPolicy.danger;
}

// ============================================================================
// LOGGING
// ============================================================================
class _EventCreateEditLogger {
  static const _tag = 'EventCreateEdit';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
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
// DROPDOWN OPTIONS (Data-driven)
// ============================================================================
class _DropdownOption {
  final String value;
  final String labelKey;
  const _DropdownOption(this.value, this.labelKey);
}

const List<_DropdownOption> _kCategories = [
  _DropdownOption('concert', 'admin_event_cat_concert'),
  _DropdownOption('conference', 'admin_event_cat_conference'),
  _DropdownOption('sport', 'admin_event_cat_sport'),
  _DropdownOption('festival', 'admin_event_cat_festival'),
  _DropdownOption('theatre', 'admin_event_cat_theatre'),
  _DropdownOption('autre', 'admin_event_cat_other'),
];

const List<_DropdownOption> _kStatuses = [
  _DropdownOption('upcoming', 'admin_event_status_upcoming'),
  _DropdownOption('ongoing', 'admin_event_status_ongoing'),
  _DropdownOption('completed', 'admin_event_status_completed'),
  _DropdownOption('cancelled', 'admin_event_status_cancelled'),
];

const List<_DropdownOption> _kVisibility = [
  _DropdownOption('upcoming', 'admin_event_vis_default'),
  _DropdownOption('recommended', 'admin_event_vis_recommended'),
  _DropdownOption('featured', 'admin_event_vis_featured'),
];

// ============================================================================
// PAGE
// ============================================================================
class EventCreateEditPage extends ConsumerStatefulWidget {
  final Event? eventToEdit;
  const EventCreateEditPage({super.key, this.eventToEdit});

  @override
  ConsumerState<EventCreateEditPage> createState() => _EventCreateEditPageState();
}

class _EventCreateEditPageState extends ConsumerState<EventCreateEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl,
      _descCtrl,
      _locationCtrl,
      _addressCtrl,
      _cityCtrl,
      _subCatCtrl,
      _orgCtrl,
      _phoneCtrl,
      _emailCtrl;
  late String _category, _currency, _status;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String _publishSection = 'upcoming';
  Uint8List? _imgBytes, _bannerBytes;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _tiers = [];

  @override
  void initState() {
    super.initState();
    final e = widget.eventToEdit;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _cityCtrl = TextEditingController(text: e?.city ?? 'LUBUMBASH, RDC');
    _subCatCtrl = TextEditingController(text: e?.subCategory ?? '');
    _orgCtrl = TextEditingController(text: e?.organizerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.contactPhone ?? '');
    _emailCtrl = TextEditingController(text: e?.contactEmail ?? '');
    _category = e?.category ?? 'concert';
    _currency = e?.priceCurrency ?? 'FC';
    _status = e?.status ?? 'upcoming';
    _startDate = e?.startDate ?? DateTime.now().add(const Duration(days: 7));
    _endDate = e?.endDate;
    _publishSection = e?.isFeatured == true
        ? 'featured'
        : e?.isRecommended == true
            ? 'recommended'
            : 'upcoming';
    if (e != null && e.ticketTiers.isNotEmpty) {
      _tiers = e.ticketTiers
          .map((t) => {'name': t.name, 'price': t.price, 'capacity': t.capacity})
          .toList();
    } else {
      _tiers = [
        {
          'name': 'Standard',
          'price': e?.price ?? 0.0,
          'capacity': e?.capacity ?? 100
        }
      ];
    }
    _EventCreateEditLogger.info('Init', {'editMode': e != null});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _subCatCtrl.dispose();
    _orgCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // ACTIONS
  // ────────────────────────────────────────────────────────────
  Future<void> _pick(bool isBanner) async {
    try {
      final x =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (x != null) {
        final b = await x.readAsBytes();
        if (!mounted) return;
        setState(() => isBanner ? _bannerBytes = b : _imgBytes = b);
      }
    } catch (e) {
      _EventCreateEditLogger.error('Image pick failed', {'error': '$e'});
    }
  }

  Future<DateTime?> _pickDateTime(DateTime init) async {
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: EventTheme.primary,
            surface: EventTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null || !mounted) return d;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: EventTheme.primary),
        ),
        child: child!,
      ),
    );
    if (t == null) return d;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  void _addTierDialog() {
    final l10n = AppLocalizations.of(context);
    final n = TextEditingController();
    final p = TextEditingController();
    final ca = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EventTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          side: const BorderSide(color: EventTheme.border),
        ),
        title: Text(
          l10n.t('admin_event_dialog_add_tier'),
          style: ThixPolicy.titleStyle.copyWith(
            color: EventTheme.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              style: TextStyle(color: EventTheme.textMain),
              decoration: _decoDialog(l10n.t('admin_event_dialog_name')),
            ),
            SizedBox(height: ThixPolicy.s8),
            TextField(
              controller: p,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EventTheme.textMain),
              decoration: _decoDialog(
                l10n.tn('admin_event_dialog_price', {'currency': _currency}),
              ),
            ),
            SizedBox(height: ThixPolicy.s8),
            TextField(
              controller: ca,
              keyboardType: TextInputType.number,
              style: TextStyle(color: EventTheme.textMain),
              decoration: _decoDialog(l10n.t('admin_event_dialog_capacity')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.t('admin_event_dialog_cancel'),
              style: TextStyle(color: EventTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (n.text.isEmpty) return;
              HapticFeedback.selectionClick();
              setState(() => _tiers.add({
                    'name': n.text.trim(),
                    'price': double.tryParse(p.text) ?? 0.0,
                    'capacity': int.tryParse(ca.text) ?? 0
                  }));
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('admin_event_dialog_add')),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final role = await AdminGuard.getCurrentRole();
    if (!AdminGuard.canWrite(role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('admin_event_err_readonly')),
          backgroundColor: EventTheme.danger,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('admin_event_err_min_tier')),
          backgroundColor: EventTheme.danger,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final svc = ref.read(adminEventServiceProvider);
      final isFeatured = _publishSection == 'featured';
      final isRecommended = _publishSection == 'recommended';
      final totalCap = _tiers.fold<int>(0, (s, t) => s + (t['capacity'] as int));
      final minPrice =
          _tiers.map((t) => t['price'] as double).reduce((a, b) => a < b ? a : b);

      final event = Event(
        id: widget.eventToEdit?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        subCategory: _subCatCtrl.text.trim().isEmpty
            ? null
            : _subCatCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        price: minPrice,
        priceCurrency: _currency,
        isFree: minPrice == 0 && _tiers.length == 1,
        capacity: totalCap,
        remainingTickets: widget.eventToEdit == null
            ? totalCap
            : widget.eventToEdit?.remainingTickets,
        isFeatured: isFeatured,
        isRecommended: isRecommended,
        status: _status,
        organizerName: _orgCtrl.text.trim().isEmpty
            ? null
            : _orgCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        viewsCount: widget.eventToEdit?.viewsCount ?? 0,
        likesCount: widget.eventToEdit?.likesCount ?? 0,
        sharesCount: widget.eventToEdit?.sharesCount ?? 0,
        createdAt: widget.eventToEdit?.createdAt ?? DateTime.now(),
        imageUrl: widget.eventToEdit?.imageUrl,
        bannerUrl: widget.eventToEdit?.bannerUrl,
        ticketTiers:
            _tiers.map<TicketTier>((t) => TicketTier.fromJson(t)).toList(),
      );

      await svc.upsertEvent(event, imageBytes: _imgBytes, bannerBytes: _bannerBytes);
      await ref.read(adminEventProvider.notifier).loadEvents(refresh: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('admin_event_success')),
          backgroundColor: EventTheme.success,
        ),
      );
      context.pop();
      _EventCreateEditLogger.info('Event saved', {'id': event.id});
    } catch (e) {
      _EventCreateEditLogger.error('Save failed', {'error': '$e'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: EventTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDt(DateTime dt, String locale) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm', locale).format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(dt);
    }
  }

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion =
        mediaQuery.accessibleNavigation || mediaQuery.disableAnimations;
    final isEdit = widget.eventToEdit != null;

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0 : 20,
              sigmaY: reduceMotion ? 0 : 20,
            ),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                isEdit
                    ? l10n.t('admin_event_edit')
                    : l10n.t('admin_event_create'),
                style: ThixPolicy.labelStyle.copyWith(
                  color: EventTheme.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: ThixPolicy.s16,
          right: ThixPolicy.s16,
          bottom: ThixPolicy.s16 + MediaQuery.of(context).padding.bottom,
          top: ThixPolicy.s8,
        ),
        child: Semantics(
          button: true,
          enabled: !_saving,
          label: isEdit
              ? l10n.t('admin_event_btn_save')
              : l10n.t('admin_event_btn_create'),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.r2Xl)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      isEdit
                          ? l10n.t('admin_event_btn_save')
                          : l10n.t('admin_event_btn_create'),
                      style: ThixPolicy.labelStyle.copyWith(
                          fontWeight: FontWeight.w900, fontSize: 12),
                    ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(ThixPolicy.s16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.t('admin_event_cover'),
                    child: _imgPicker(
                      l10n.t('admin_event_cover'),
                      _imgBytes,
                      widget.eventToEdit?.imageUrl,
                      () => _pick(false),
                    ),
                  ),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.t('admin_event_banner'),
                    child: _imgPicker(
                      l10n.t('admin_event_banner'),
                      _bannerBytes,
                      widget.eventToEdit?.bannerUrl,
                      () => _pick(true),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _field(_titleCtrl, l10n.t('admin_event_title'),
                validator: (v) =>
                    v!.isEmpty ? l10n.t('admin_event_err_title_req') : null),
            SizedBox(height: ThixPolicy.s12),
            _field(_descCtrl, l10n.t('admin_event_desc'),
                maxLines: 4,
                validator: (v) =>
                    v!.length < 10 ? l10n.t('admin_event_err_desc_min') : null),
            SizedBox(height: ThixPolicy.s12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: EventTheme.surface,
                    style: TextStyle(color: EventTheme.textMain),
                    decoration: _deco(l10n.t('admin_event_category')),
                    items: _kCategories
                        .map((c) => DropdownMenuItem(
                            value: c.value, child: Text(l10n.t(c.labelKey))))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                    child: _field(_subCatCtrl, l10n.t('admin_event_subcategory'))),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('admin_event_datetime'),
              style: ThixPolicy.labelStyle.copyWith(
                  color: EventTheme.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
            SizedBox(height: ThixPolicy.s8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final dt = await _pickDateTime(_startDate);
                      if (dt != null) setState(() => _startDate = dt);
                    },
                    child: InputDecorator(
                      decoration: _deco(l10n.t('admin_event_start')),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmtDt(_startDate, locale),
                              style: TextStyle(
                                  color: EventTheme.textMain,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: EventTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final dt = await _pickDateTime(_endDate ?? _startDate);
                      if (dt != null) setState(() => _endDate = dt);
                    },
                    child: InputDecorator(
                      decoration: _deco(l10n.t('admin_event_end')),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _endDate == null
                                ? l10n.t('admin_event_add_end')
                                : _fmtDt(_endDate!, locale),
                            style: TextStyle(
                                color: EventTheme.textMain, fontSize: 11),
                          ),
                          const Icon(Icons.access_time_rounded,
                              size: 14, color: EventTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _field(_cityCtrl, l10n.t('admin_event_city'),
                        validator: (v) => v!.isEmpty
                            ? l10n.t('admin_event_err_city_req')
                            : null)),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                    child: _field(_locationCtrl, l10n.t('admin_event_location'),
                        validator: (v) => v!.isEmpty
                            ? l10n.t('admin_event_err_loc_req')
                            : null)),
              ],
            ),
            SizedBox(height: ThixPolicy.s12),
            _field(_addressCtrl, l10n.t('admin_event_address')),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _field(_orgCtrl, l10n.t('admin_event_organizer'))),
                SizedBox(width: ThixPolicy.s12),
                Expanded(
                    child: _field(_phoneCtrl, l10n.t('admin_event_phone'),
                        keyboard: TextInputType.phone)),
              ],
            ),
            SizedBox(height: ThixPolicy.s12),
            _field(_emailCtrl, l10n.t('admin_event_email'),
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('admin_event_tiers_title'),
                  style: ThixPolicy.labelStyle.copyWith(
                      color: EventTheme.textMain,
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
                DropdownButton<String>(
                  value: _currency,
                  dropdownColor: EventTheme.surface,
                  underline: const SizedBox(),
                  style: TextStyle(
                      color: EventTheme.textMain, fontWeight: FontWeight.w800),
                  items: const ['FC', 'USD', 'EUR']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
              ],
            ),
            SizedBox(height: ThixPolicy.s8),
            Container(
              decoration: BoxDecoration(
                color: EventTheme.surface,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: EventTheme.border),
              ),
              child: Column(
                children: [
                  ..._tiers.asMap().entries.map((e) {
                    final t = e.value;
                    return Semantics(
                      label:
                          '${t['name']}, ${t['price']} $_currency, ${t['capacity']}',
                      child: ListTile(
                        title: Text(
                          t['name'],
                          style: TextStyle(
                              color: EventTheme.textMain,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        subtitle: Text(
                          '${t['price']} $_currency • ${t['capacity']} ${l10n.t('admin_event_dialog_capacity').toLowerCase()}',
                          style: TextStyle(
                              color: EventTheme.textMuted, fontSize: 11),
                        ),
                        trailing: Semantics(
                          button: true,
                          label: l10n.t('common_delete'),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: EventTheme.danger, size: 18),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _tiers.removeAt(e.key));
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                  const Divider(color: EventTheme.border, height: 1),
                  Semantics(
                    button: true,
                    label: l10n.t('admin_event_add_tier_btn'),
                    child: InkWell(
                      onTap: _addTierDialog,
                      borderRadius:
                          const BorderRadius.vertical(bottom: Radius.circular(14)),
                      child: Padding(
                        padding: EdgeInsets.all(ThixPolicy.s12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: ThixPolicy.s8),
                            Text(
                              l10n.t('admin_event_add_tier_btn'),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: EventTheme.surface,
              style: TextStyle(color: EventTheme.textMain),
              decoration: _deco(l10n.t('admin_event_status')),
              items: _kStatuses
                  .map((c) => DropdownMenuItem(
                      value: c.value, child: Text(l10n.t(c.labelKey))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            SizedBox(height: ThixPolicy.s12),
            DropdownButtonFormField<String>(
              value: _publishSection,
              dropdownColor: EventTheme.surface,
              style: TextStyle(color: EventTheme.textMain),
              decoration: _deco(l10n.t('admin_event_visibility')),
              items: _kVisibility
                  .map((c) => DropdownMenuItem(
                      value: c.value, child: Text(l10n.t(c.labelKey))))
                  .toList(),
              onChanged: (v) => setState(() => _publishSection = v!),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SUB-WIDGETS
  // ────────────────────────────────────────────────────────────
  Widget _imgPicker(
      String label, Uint8List? bytes, String? url, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: EventTheme.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: EventTheme.border),
        ),
        child: bytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                child: Image.memory(bytes, fit: BoxFit.cover),
              )
            : url != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    child: Image.network(url, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(height: ThixPolicy.s6),
                      Text(
                        label,
                        style: TextStyle(
                            color: EventTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      style: TextStyle(color: EventTheme.textMain, fontSize: 12),
      decoration: _deco(label),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: EventTheme.textMuted, fontSize: 11),
        filled: true,
        fillColor: EventTheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          borderSide: const BorderSide(color: Colors.white24, width: 1.2),
        ),
        errorStyle: TextStyle(color: EventTheme.danger, fontSize: 10),
      );

  InputDecoration _decoDialog(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: EventTheme.textMuted, fontSize: 11),
        filled: true,
        fillColor: EventTheme.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: EventTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      );
}
