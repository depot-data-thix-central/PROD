class BusinessPlanConfig {
  const BusinessPlanConfig({
    this.id,
    required this.projectCode,
    this.productName,
    this.slogan,
    this.stage,
    this.revenueSources,
    this.persona,
    this.initialCapital,
    this.fundingTarget,
    this.fundAllocation,
    this.year1Goal,
    this.usp,
    this.acquisitionChannel,
    this.founderName,
    this.missingRoles,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String projectCode;
  final String? productName;
  final String? slogan;
  final String? stage;
  final String? revenueSources;
  final String? persona;
  final double? initialCapital;
  final double? fundingTarget;
  final String? fundAllocation;
  final String? year1Goal;
  final String? usp;
  final String? acquisitionChannel;
  final String? founderName;
  final String? missingRoles;
  final String? ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BusinessPlanConfig.fromJson(Map<String, dynamic> j) {
    return BusinessPlanConfig(
      id: j['id']?.toString(),
      projectCode: j['project_code'] as String? ?? '',
      productName: j['product_name'] as String?,
      slogan: j['slogan'] as String?,
      stage: j['stage'] as String?,
      revenueSources: j['revenue_sources'] as String?,
      persona: j['persona'] as String?,
      initialCapital: (j['initial_capital'] as num?)?.toDouble(),
      fundingTarget: (j['funding_target'] as num?)?.toDouble(),
      fundAllocation: j['fund_allocation'] as String?,
      year1Goal: j['year1_goal'] as String?,
      usp: j['usp'] as String?,
      acquisitionChannel: j['acquisition_channel'] as String?,
      founderName: j['founder_name'] as String?,
      missingRoles: j['missing_roles'] as String?,
      ownerId: j['owner_id']?.toString(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'project_code': projectCode,
        if (productName != null) 'product_name': productName,
        if (slogan != null) 'slogan': slogan,
        if (stage != null) 'stage': stage,
        if (revenueSources != null) 'revenue_sources': revenueSources,
        if (persona != null) 'persona': persona,
        if (initialCapital != null) 'initial_capital': initialCapital,
        if (fundingTarget != null) 'funding_target': fundingTarget,
        if (fundAllocation != null) 'fund_allocation': fundAllocation,
        if (year1Goal != null) 'year1_goal': year1Goal,
        if (usp != null) 'usp': usp,
        if (acquisitionChannel != null)
          'acquisition_channel': acquisitionChannel,
        if (founderName != null) 'founder_name': founderName,
        if (missingRoles != null) 'missing_roles': missingRoles,
        if (ownerId != null) 'owner_id': ownerId,
        'updated_at': DateTime.now().toIso8601String(),
      };

  String toPromptBlock() {
    final b = StringBuffer();
    b.writeln('=== DONNÉES PROPRIÉTAIRES FONDATEUR (Supabase) ===');
    if (productName != null && productName!.isNotEmpty) {
      b.writeln('Nom produit/entreprise : $productName');
    }
    if (slogan != null && slogan!.isNotEmpty) {
      b.writeln('Mission / Slogan : $slogan');
    }
    if (stage != null && stage!.isNotEmpty) b.writeln('Stade : $stage');
    if (revenueSources != null && revenueSources!.isNotEmpty) {
      b.writeln('Sources de revenus : $revenueSources');
    }
    if (persona != null && persona!.isNotEmpty) {
      b.writeln('Cible principale : $persona');
    }
    if (initialCapital != null && initialCapital! > 0) {
      b.writeln('Capital initial : \\[ {initialCapital!.toStringAsFixed(0)}');
    }
    if (fundingTarget != null && fundingTarget! > 0) {
      b.writeln('Montant recherché : \ \]{fundingTarget!.toStringAsFixed(0)}');
    }
    if (fundAllocation != null && fundAllocation!.isNotEmpty) {
      b.writeln('Allocation des fonds : $fundAllocation');
    }
    if (year1Goal != null && year1Goal!.isNotEmpty) {
      b.writeln('Objectif 1 an : $year1Goal');
    }
    if (usp != null && usp!.isNotEmpty) {
      b.writeln('Avantage concurrentiel (USP) : $usp');
    }
    if (acquisitionChannel != null && acquisitionChannel!.isNotEmpty) {
      b.writeln('Canal d\'acquisition : $acquisitionChannel');
    }
    if (founderName != null && founderName!.isNotEmpty) {
      b.writeln('Fondateur / CEO : $founderName');
    }
    if (missingRoles != null && missingRoles!.isNotEmpty) {
      b.writeln('Rôles manquants : $missingRoles');
    }
    b.writeln('=== FIN DONNÉES FONDATEUR ===');
    return b.toString();
  }
}
