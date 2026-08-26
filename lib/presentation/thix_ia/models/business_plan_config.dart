/// Configuration fondateur pour BP personnalisé + seed Execution
class BusinessPlanConfig {
  const BusinessPlanConfig({
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
  });

  final String? productName;
  final String? slogan;
  final String? stage; // idee | mvp | launched | growth
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

  Map<String, dynamic> toJson() => {
        if (productName != null && productName!.isNotEmpty)
          'product_name': productName,
        if (slogan != null && slogan!.isNotEmpty) 'slogan': slogan,
        if (stage != null && stage!.isNotEmpty) 'stage': stage,
        if (revenueSources != null && revenueSources!.isNotEmpty)
          'revenue_sources': revenueSources,
        if (persona != null && persona!.isNotEmpty) 'persona': persona,
        if (initialCapital != null) 'initial_capital': initialCapital,
        if (fundingTarget != null) 'funding_target': fundingTarget,
        if (fundAllocation != null && fundAllocation!.isNotEmpty)
          'fund_allocation': fundAllocation,
        if (year1Goal != null && year1Goal!.isNotEmpty) 'year1_goal': year1Goal,
        if (usp != null && usp!.isNotEmpty) 'usp': usp,
        if (acquisitionChannel != null && acquisitionChannel!.isNotEmpty)
          'acquisition_channel': acquisitionChannel,
        if (founderName != null && founderName!.isNotEmpty)
          'founder_name': founderName,
        if (missingRoles != null && missingRoles!.isNotEmpty)
          'missing_roles': missingRoles,
      };

  /// Texte injecté dans le prompt IA
  String toPromptBlock() {
    final b = StringBuffer();
    b.writeln('=== DONNÉES PROPRIÉTAIRES DU FONDATEUR (OBLIGATOIRES) ===');
    if (productName != null) b.writeln('Nom produit/entreprise : $productName');
    if (slogan != null) b.writeln('Mission / Slogan : $slogan');
    if (stage != null) b.writeln('Stade : $stage');
    if (revenueSources != null) b.writeln('Sources de revenus : $revenueSources');
    if (persona != null) b.writeln('Cible principale (persona) : $persona');
    if (initialCapital != null) {
      b.writeln('Capital initial : \\[ {initialCapital!.toStringAsFixed(0)}');
    }
    if (fundingTarget != null) {
      b.writeln('Montant recherché : \ \]{fundingTarget!.toStringAsFixed(0)}');
    }
    if (fundAllocation != null) b.writeln('Allocation des fonds : $fundAllocation');
    if (year1Goal != null) b.writeln('Objectif 1 an : $year1Goal');
    if (usp != null) b.writeln('Avantage concurrentiel (USP) : $usp');
    if (acquisitionChannel != null) {
      b.writeln('Canal d\'acquisition principal : $acquisitionChannel');
    }
    if (founderName != null) b.writeln('Fondateur / CEO : $founderName');
    if (missingRoles != null) b.writeln('Rôles manquants : $missingRoles');
    b.writeln('=== FIN DONNÉES FONDATEUR ===');
    return b.toString();
  }

  /// Seed pour le module Exécution (trésorerie, roadmap, équipe)
  Map<String, dynamic> toExecutionSeed() => {
        'product_name': productName,
        'stage': stage,
        'initial_capital': initialCapital,
        'funding_target': fundingTarget,
        'year1_goal': year1Goal,
        'founder_name': founderName,
        'missing_roles': missingRoles,
        'acquisition_channel': acquisitionChannel,
        'usp': usp,
      };
}
