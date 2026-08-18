import '../models/grossesse_model.dart';

class GrossesseAdviceService {
  static BabyWeekInfo getBabyInfo(int sa) {
    if (sa <= 4) {
      return const BabyWeekInfo(
        fruit: 'Graine',
        size: '2 mm',
        weight: '<1 g',
        desc: 'Nidation',
      );
    }
    if (sa <= 8) {
      return const BabyWeekInfo(
        fruit: 'Framboise',
        size: '1.6 cm',
        weight: '1 g',
        desc: 'Coeur bat',
      );
    }
    if (sa <= 12) {
      return const BabyWeekInfo(
        fruit: 'Citron',
        size: '6 cm',
        weight: '14 g',
        desc: 'Organes formes',
      );
    }
    if (sa <= 16) {
      return const BabyWeekInfo(
        fruit: 'Avocat',
        size: '12 cm',
        weight: '100 g',
        desc: 'Mouvements',
      );
    }
    if (sa <= 20) {
      return const BabyWeekInfo(
        fruit: 'Banane',
        size: '25 cm',
        weight: '300 g',
        desc: 'Coups perceptibles',
      );
    }
    if (sa <= 24) {
      return const BabyWeekInfo(
        fruit: 'Mais',
        size: '30 cm',
        weight: '600 g',
        desc: 'Viabilite',
      );
    }
    if (sa <= 28) {
      return const BabyWeekInfo(
        fruit: 'Aubergine',
        size: '37 cm',
        weight: '1 kg',
        desc: 'Yeux ouverts',
      );
    }
    if (sa <= 32) {
      return const BabyWeekInfo(
        fruit: 'Courge',
        size: '42 cm',
        weight: '1.7 kg',
        desc: 'Os se solidifient',
      );
    }
    if (sa <= 36) {
      return const BabyWeekInfo(
        fruit: 'Melon',
        size: '47 cm',
        weight: '2.6 kg',
        desc: 'Poumons matures',
      );
    }
    return const BabyWeekInfo(
      fruit: 'Pasteque',
      size: '50 cm',
      weight: '3.3 kg',
      desc: 'Pret a naitre',
    );
  }

  static WeekAdvice getWeekAdvice(int sa) {
    final info = getBabyInfo(sa);
    return WeekAdvice(
      title: 'Semaine $sa - Bebe ${info.fruit}',
      babyDevelopment: [
        'Taille: ${info.size} - Poids: ${info.weight}',
        info.desc,
        sa >= 28
            ? 'Compter les coups 2x/jour'
            : 'Developpement cerebral intense',
        sa >= 37
            ? 'Bebe engage - surveiller contractions'
            : 'Croissance continue',
      ],
      nutrition: [
        'Acide folique + fer',
        'Proteines + legumes verts',
        'Hydratation 2L/jour',
      ],
      avoid: [
        'Alcool, tabac',
        'Fromages au lait cru, charcuterie crue',
        'Efforts intenses si risque',
      ],
    );
  }
}
