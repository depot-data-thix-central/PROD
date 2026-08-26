import 'package:flutter/material.dart';
import '../models/business_plan_config.dart';
import '../repositories/bp_config_repository.dart';

/// BottomSheet multi-étapes — tout lit/écrit Supabase (table thix_bp_config)
Future<BusinessPlanConfig?> showBusinessPlanPreflightSheet(
  BuildContext context, {
  required String projectCode,
}) {
  return showModalBottomSheet<BusinessPlanConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PreflightForm(projectCode: projectCode),
  );
}

class _PreflightForm extends StatefulWidget {
  const _PreflightForm({required this.projectCode});
  final String projectCode;

  @override
  State<_PreflightForm> createState() => _PreflightFormState();
}

class _PreflightFormState extends State<_PreflightForm> {
  int _step = 0;
  final _pageCtrl = PageController();
  final _repo = BpConfigRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _productName = TextEditingController();
  final _slogan = TextEditingController();
  String _stage = 'idee';
  final _revenue = TextEditingController();
  final _persona = TextEditingController();
  final _capital = TextEditingController();
  final _funding = TextEditingController();
  final _allocation = TextEditingController();
  final _year1 = TextEditingController();
  final _usp = TextEditingController();
  final _channel = TextEditingController();
  final _founder = TextEditingController();
  final _roles = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = await _repo.getByProject(widget.projectCode);
      if (!mounted) return;
      if (existing != null) {
        _productName.text = existing.productName ?? '';
        _slogan.text = existing.slogan ?? '';
        _stage = existing.stage ?? 'idee';
        _revenue.text = existing.revenueSources ?? '';
        _persona.text = existing.persona ?? '';
        _capital.text = existing.initialCapital != null
            ? existing.initialCapital!.toStringAsFixed(0)
            : '';
        _funding.text = existing.fundingTarget != null
            ? existing.fundingTarget!.toStringAsFixed(0)
            : '';
        _allocation.text = existing.fundAllocation ?? '';
        _year1.text = existing.year1Goal ?? '';
        _usp.text = existing.usp ?? '';
        _channel.text = existing.acquisitionChannel ?? '';
        _founder.text = existing.founderName ?? '';
        _roles.text = existing.missingRoles ?? '';
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erreur chargement Supabase : $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _productName.dispose();
    _slogan.dispose();
    _revenue.dispose();
    _persona.dispose();
    _capital.dispose();
    _funding.dispose();
    _allocation.dispose();
    _year1.dispose();
    _usp.dispose();
    _channel.dispose();
    _founder.dispose();
    _roles.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final config = BusinessPlanConfig(
        projectCode: widget.projectCode,
        productName: _productName.text.trim().isEmpty
            ? null
            : _productName.text.trim(),
        slogan: _slogan.text.trim().isEmpty ? null : _slogan.text.trim(),
        stage: _stage,
        revenueSources:
            _revenue.text.trim().isEmpty ? null : _revenue.text.trim(),
        persona: _persona.text.trim().isEmpty ? null : _persona.text.trim(),
        initialCapital: double.tryParse(_capital.text.trim()),
        fundingTarget: double.tryParse(_funding.text.trim()),
        fundAllocation:
            _allocation.text.trim().isEmpty ? null : _allocation.text.trim(),
        year1Goal: _year1.text.trim().isEmpty ? null : _year1.text.trim(),
        usp: _usp.text.trim().isEmpty ? null : _usp.text.trim(),
        acquisitionChannel:
            _channel.text.trim().isEmpty ? null : _channel.text.trim(),
        founderName:
            _founder.text.trim().isEmpty ? null : _founder.text.trim(),
        missingRoles:
            _roles.text.trim().isEmpty ? null : _roles.text.trim(),
      );

      // ★ Sauvegarde Supabase uniquement
      final saved = await _repo.upsert(config);

      // Seed Execution (capital → thix_execution_finances)
      await _repo.seedExecution(widget.projectCode);

      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Erreur sauvegarde Supabase : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    if (_loading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Configuration du Business Plan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Étape ${_step + 1} / 5 — données enregistrées dans Supabase',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_step + 1) / 5,
              backgroundColor: Colors.grey.shade200,
              minHeight: 3,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepIdentity(),
                  _stepModel(),
                  _stepFinance(),
                  _stepStrategy(),
                  _stepTeam(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _back,
                    child: const Text('Retour'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step == 4 ? 'Enregistrer & Générer' : 'Suivant'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _stepIdentity() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          _productName,
          'Nom officiel du produit / entreprise',
          hint: 'ex: THIX Money',
        ),
        _field(
          _slogan,
          'Slogan ou Mission (one-liner)',
          hint: 'La finance accessible à tous en Zambie',
        ),
        const Text('Stade d\'avancement', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final s in [
              ('idee', 'Idée'),
              ('mvp', 'MVP / Prototype'),
              ('launched', 'Produit lancé'),
              ('growth', 'Croissance'),
            ])
              ChoiceChip(
                label: Text(s.$2),
                selected: _stage == s.$1,
                onSelected: (_) => setState(() => _stage = s.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepModel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          _revenue,
          'Sources de revenus principales',
          hint: 'Frais/tx, abonnement B2B, commissions…',
        ),
        _field(
          _persona,
          'Cible principale (Persona)',
          hint: 'Étudiants, commerçants informels…',
        ),
      ],
    );
  }

  Widget _stepFinance() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(_capital, 'Capital initial (\$)', hint: 'ex: 5000'),
        _field(
          _funding,
          'Montant recherché investisseurs (\$)',
          hint: 'ex: 50000',
        ),
        _field(
          _allocation,
          'Allocation des fonds',
          hint: '40% Tech, 40% Marketing, 20% Légal',
        ),
        _field(
          _year1,
          'Objectif financier / traction à 1 an',
          hint: '10k users ou 50k\$ CA',
        ),
      ],
    );
  }

  Widget _stepStrategy() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          _usp,
          'Avantage concurrentiel (USP)',
          hint: 'Frais -50%, multi-langues locales…',
        ),
        _field(
          _channel,
          'Canal d\'acquisition principal',
          hint: 'Universités, ambassadeurs, pubs sociales…',
        ),
      ],
    );
  }

  Widget _stepTeam() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(_founder, 'Nom du Fondateur / CEO'),
        _field(
          _roles,
          'Rôles clés manquants',
          hint: 'Recherche CTO, expert conformité bancaire…',
        ),
        const SizedBox(height: 8),
        Text(
          'Enregistré dans Supabase (thix_bp_config). '
          'Le capital initial alimente thix_execution_finances.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
