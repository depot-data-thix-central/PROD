// lib/presentation/thix_market/l10n/market_strings.dart
import 'package:flutter/widgets.dart';

/// Système de traduction léger pour THIX MARKET.
/// Le texte s'adapte automatiquement à la langue de l'appareil
/// (Localizations.localeOf(context)). Pour ajouter une langue,
/// ajoutez une entrée dans [_strings].
class MarketStrings {
  final String languageCode;
  const MarketStrings(this.languageCode);

  static const Map<String, Map<String, String>> _strings = {
    'fr': {
      'appTagline': 'Achetez. Vendez. Évoluez.',
      'securePayment': 'Paiement sécurisé',
      'verifiedSellers': 'Vendeurs vérifiés',
      'reliableDelivery': 'Livraison fiable',
      'support247': 'Support 24/7',
      'searchHint': 'Rechercher un produit, une marque...',
      'search': 'Rechercher',
      'homeSupermarkets': 'Supermarchés à domicile',
      'seeAll': 'Tout voir',
      'noSupermarket': 'Aucun supermarché',
      'exclusiveOffers': 'OFFRES EXCLUSIVES',
      'upTo50': "Jusqu'à -50%",
      'onPremiumSelection': 'sur une sélection premium',
      'discover': 'Découvrir',
      'sellWithThix': 'VENDEZ AVEC THIX',
      'growBusiness': 'Développez votre\nbusiness aujourd\'hui',
      'start': 'Commencer',
      'compare': 'Comparer',
      'priceAlert': 'Alerte Prix',
      'b2bQuote': 'Devis B2B',
      'wishlist': 'Wishlist',
      'comingSoonSuffix': 'Bientôt disponible !',
      'flashSaleBannerText':
          "⚡ VENTE FLASH EN COURS • JUSQU'À -50% SUR UNE SÉLECTION DE PRODUITS • PROFITEZ-EN VITE ⚡",
      'flashOffers': 'Offres flash',
      'live': 'En direct',
      'featuredProducts': 'Produits en vedette',
      'featuredBadge': 'Vedette',
      'allProducts': 'Tous les produits',
      'error': 'Erreur',
      'greeting': 'Bonjour',
      'client': 'Client',
      'defaultHeroTitle': 'Votre marketplace\npremium et sécurisée',
      'defaultHeroSubtitle':
          'Des milliers de produits, des vendeurs vérifiés, une expérience unique.',
      'viewOffer': "Voir l'offre",
      'exploreMarket': 'Explorer le marché',
      'home': 'Accueil',
      'orders': 'Commandes',
      'alerts': 'Alertes',
      'outOfStock': 'ÉPUISÉ',
      'unavailable': 'Non dispo',
      'inStock': 'dispo',
      'flashBadge': 'FLASH',
      'shopFallback': 'Boutique THIX',
      'cityFallback': 'RDC',
      'placementTitle': "Placement de l'annonce",
      'placementStandardTitle': 'Annonce Standard',
      'placementStandardDesc': 'Affichage classique dans le flux de la marketplace',
      'placementHeroTitle': 'Bannière Vedette (Hero)',
      'placementHeroDesc':
          "Mise en avant en haut de l'accueil et dans la bande vedette",
      'placementFlashTitle': 'Vente Flash',
      'placementFlashDesc': 'Mise en avant avec un compte à rebours',
      'flashEndLabel': 'Fin de la vente flash',
      'flashEndUnset': 'Aucune date définie',
      'setDate': 'Définir',
      'photosTitle': 'Photos du produit',
      'addPhoto': 'Ajouter',
      'titleLabel': "Titre de l'annonce",
      'descriptionLabel': 'Description détaillée',
      'priceLabel': 'Prix',
      'discountPriceLabel': 'Prix promo',
      'currencyLabel': 'Devise',
      'stockLabel': 'Stock disponible',
      'brandLabel': 'Marque (Opt.)',
      'categoryLabel': 'Catégorie',
      'conditionLabel': 'État',
      'cityLabel': 'Ville de publication',
      'customCityLabel': 'Précisez la ville',
      'shippingTypeLabel': 'Type de livraison',
      'shippingCostLabel': 'Frais de livraison',
      'warrantyLabel': 'Garantie (mois)',
      'freeShipping': 'Livraison gratuite',
      'isServiceTitle': 'Ceci est un service',
      'isServiceDesc': "Sélectionnez ceci s'il s'agit d'une réservation.",
      'publish': "Publier l'annonce",
      'update': 'Mettre à jour',
      'required': 'Requis',
      'requiredField': 'Champ requis',
      'atLeastOneImage': 'Ajoutez au moins une image',
      'cityRequired': 'Précisez la ville de publication',
      'flashDateRequired': 'Veuillez définir une date de fin pour la vente flash.',
      'cat_fashion': 'Mode & Accessoires',
      'cat_electronics': 'Électronique',
      'cat_home': 'Maison & Jardin',
      'cat_services': 'Services',
      'cat_vehicles': 'Véhicules',
      'cat_realestate': 'Immobilier',
      'cat_food': 'Alimentation',
      'cat_beauty': 'Beauté & Bien-être',
      'cat_sports': 'Sports & Loisirs',
      'cond_new': 'Neuf',
      'cond_like_new': 'Comme neuf',
      'cond_good': 'Bon état',
      'cond_fair': 'État correct',
      'ship_delivery': 'Livraison',
      'ship_pickup': 'Retrait en magasin',
      'ship_both': 'Les deux',
    },
    'en': {
      'appTagline': 'Buy. Sell. Grow.',
      'securePayment': 'Secure payment',
      'verifiedSellers': 'Verified sellers',
      'reliableDelivery': 'Reliable delivery',
      'support247': '24/7 support',
      'searchHint': 'Search a product, a brand...',
      'search': 'Search',
      'homeSupermarkets': 'Supermarkets at home',
      'seeAll': 'See all',
      'noSupermarket': 'No supermarket',
      'exclusiveOffers': 'EXCLUSIVE OFFERS',
      'upTo50': 'Up to -50%',
      'onPremiumSelection': 'on a premium selection',
      'discover': 'Discover',
      'sellWithThix': 'SELL WITH THIX',
      'growBusiness': 'Grow your\nbusiness today',
      'start': 'Get started',
      'compare': 'Compare',
      'priceAlert': 'Price alert',
      'b2bQuote': 'B2B quote',
      'wishlist': 'Wishlist',
      'comingSoonSuffix': 'Coming soon!',
      'flashSaleBannerText':
          '⚡ FLASH SALE LIVE NOW • UP TO -50% ON SELECTED PRODUCTS • GRAB IT FAST ⚡',
      'flashOffers': 'Flash deals',
      'live': 'Live',
      'featuredProducts': 'Featured products',
      'featuredBadge': 'Featured',
      'allProducts': 'All products',
      'error': 'Error',
      'greeting': 'Hello',
      'client': 'Guest',
      'defaultHeroTitle': 'Your premium\n& secure marketplace',
      'defaultHeroSubtitle':
          'Thousands of products, verified sellers, a unique experience.',
      'viewOffer': 'View offer',
      'exploreMarket': 'Explore market',
      'home': 'Home',
      'orders': 'Orders',
      'alerts': 'Alerts',
      'outOfStock': 'SOLD OUT',
      'unavailable': 'Unavailable',
      'inStock': 'in stock',
      'flashBadge': 'FLASH',
      'shopFallback': 'THIX Shop',
      'cityFallback': 'DRC',
      'placementTitle': 'Listing placement',
      'placementStandardTitle': 'Standard listing',
      'placementStandardDesc': 'Classic display in the marketplace feed',
      'placementHeroTitle': 'Hero Banner',
      'placementHeroDesc':
          'Featured at the top of the home screen and in the featured strip',
      'placementFlashTitle': 'Flash sale',
      'placementFlashDesc': 'Featured with a countdown timer',
      'flashEndLabel': 'Flash sale end',
      'flashEndUnset': 'No date set',
      'setDate': 'Set',
      'photosTitle': 'Product photos',
      'addPhoto': 'Add',
      'titleLabel': 'Listing title',
      'descriptionLabel': 'Detailed description',
      'priceLabel': 'Price',
      'discountPriceLabel': 'Sale price',
      'currencyLabel': 'Currency',
      'stockLabel': 'Available stock',
      'brandLabel': 'Brand (Opt.)',
      'categoryLabel': 'Category',
      'conditionLabel': 'Condition',
      'cityLabel': 'Publishing city',
      'customCityLabel': 'Specify city',
      'shippingTypeLabel': 'Shipping type',
      'shippingCostLabel': 'Shipping cost',
      'warrantyLabel': 'Warranty (months)',
      'freeShipping': 'Free shipping',
      'isServiceTitle': 'This is a service',
      'isServiceDesc': 'Select this if it is a booking.',
      'publish': 'Publish listing',
      'update': 'Update',
      'required': 'Required',
      'requiredField': 'Required field',
      'atLeastOneImage': 'Add at least one image',
      'cityRequired': 'Specify the publishing city',
      'flashDateRequired': 'Please set an end date for the flash sale.',
      'cat_fashion': 'Fashion & Accessories',
      'cat_electronics': 'Electronics',
      'cat_home': 'Home & Garden',
      'cat_services': 'Services',
      'cat_vehicles': 'Vehicles',
      'cat_realestate': 'Real Estate',
      'cat_food': 'Food',
      'cat_beauty': 'Beauty & Wellness',
      'cat_sports': 'Sports & Leisure',
      'cond_new': 'New',
      'cond_like_new': 'Like new',
      'cond_good': 'Good',
      'cond_fair': 'Fair',
      'ship_delivery': 'Delivery',
      'ship_pickup': 'Store pickup',
      'ship_both': 'Both',
    },
  };

  String _t(String key) {
    final lang = _strings.containsKey(languageCode) ? languageCode : 'fr';
    return _strings[lang]?[key] ?? _strings['fr']![key] ?? key;
  }

  String get appTagline => _t('appTagline');
  String get securePayment => _t('securePayment');
  String get verifiedSellers => _t('verifiedSellers');
  String get reliableDelivery => _t('reliableDelivery');
  String get support247 => _t('support247');
  String get searchHint => _t('searchHint');
  String get search => _t('search');
  String get homeSupermarkets => _t('homeSupermarkets');
  String get seeAll => _t('seeAll');
  String get noSupermarket => _t('noSupermarket');
  String get exclusiveOffers => _t('exclusiveOffers');
  String get upTo50 => _t('upTo50');
  String get onPremiumSelection => _t('onPremiumSelection');
  String get discover => _t('discover');
  String get sellWithThix => _t('sellWithThix');
  String get growBusiness => _t('growBusiness');
  String get start => _t('start');
  String get compare => _t('compare');
  String get priceAlert => _t('priceAlert');
  String get b2bQuote => _t('b2bQuote');
  String get wishlist => _t('wishlist');
  String comingSoon(String feature) => '$feature : ${_t('comingSoonSuffix')}';
  String get flashSaleBannerText => _t('flashSaleBannerText');
  String get flashOffers => _t('flashOffers');
  String get live => _t('live');
  String get featuredProducts => _t('featuredProducts');
  String get featuredBadge => _t('featuredBadge');
  String get allProducts => _t('allProducts');
  String get error => _t('error');
  String get greeting => _t('greeting');
  String get client => _t('client');
  String get defaultHeroTitle => _t('defaultHeroTitle');
  String get defaultHeroSubtitle => _t('defaultHeroSubtitle');
  String get viewOffer => _t('viewOffer');
  String get exploreMarket => _t('exploreMarket');
  String get home => _t('home');
  String get orders => _t('orders');
  String get alerts => _t('alerts');
  String get outOfStock => _t('outOfStock');
  String get unavailable => _t('unavailable');
  String get inStock => _t('inStock');
  String get flashBadge => _t('flashBadge');
  String get shopFallback => _t('shopFallback');
  String get cityFallback => _t('cityFallback');
  String get placementTitle => _t('placementTitle');
  String get placementStandardTitle => _t('placementStandardTitle');
  String get placementStandardDesc => _t('placementStandardDesc');
  String get placementHeroTitle => _t('placementHeroTitle');
  String get placementHeroDesc => _t('placementHeroDesc');
  String get placementFlashTitle => _t('placementFlashTitle');
  String get placementFlashDesc => _t('placementFlashDesc');
  String get flashEndLabel => _t('flashEndLabel');
  String get flashEndUnset => _t('flashEndUnset');
  String get setDate => _t('setDate');
  String get photosTitle => _t('photosTitle');
  String get addPhoto => _t('addPhoto');
  String get titleLabel => _t('titleLabel');
  String get descriptionLabel => _t('descriptionLabel');
  String get priceLabel => _t('priceLabel');
  String get discountPriceLabel => _t('discountPriceLabel');
  String get currencyLabel => _t('currencyLabel');
  String get stockLabel => _t('stockLabel');
  String get brandLabel => _t('brandLabel');
  String get categoryLabel => _t('categoryLabel');
  String get conditionLabel => _t('conditionLabel');
  String get cityLabel => _t('cityLabel');
  String get customCityLabel => _t('customCityLabel');
  String get shippingTypeLabel => _t('shippingTypeLabel');
  String get shippingCostLabel => _t('shippingCostLabel');
  String get warrantyLabel => _t('warrantyLabel');
  String get freeShipping => _t('freeShipping');
  String get isServiceTitle => _t('isServiceTitle');
  String get isServiceDesc => _t('isServiceDesc');
  String get publish => _t('publish');
  String get update => _t('update');
  String get required => _t('required');
  String get requiredField => _t('requiredField');
  String get atLeastOneImage => _t('atLeastOneImage');
  String get cityRequired => _t('cityRequired');
  String get flashDateRequired => _t('flashDateRequired');

  String categoryName(String id) => _t('cat_$id');
  String conditionName(String id) => _t('cond_$id');
  String shippingTypeName(String id) => _t('ship_$id');
}

extension MarketL10n on BuildContext {
  MarketStrings get mkt => MarketStrings(Localizations.localeOf(this).languageCode);
}
