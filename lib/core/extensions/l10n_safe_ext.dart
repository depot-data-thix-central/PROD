import 'package:flutter/material.dart';
import 'package:thix_id/l10n/app_localizations.dart';

/// Extension sécurisée pour l10n : ne crash JAMAIS si une clé manque.
/// Retourne la clé elle-même en fallback (ex: "reservationBrandSuffix").
extension L10nSafe on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Traduction sécurisée avec fallback sur le nom de la clé
  String t(String key, [List<Object>? args]) {
    try {
      // Tente d'accéder à la clé dynamiquement
      final result = _resolve(l10n, key, args);
      return result ?? key;
    } catch (_) {
      return key;
    }
  }

  static String? _resolve(AppLocalizations l10n, String key, List<Object>? args) {
    // Mapping manuel des clés vers les getters/methods
    // Ce switch couvre toutes les clés utilisées dans le projet
    switch (key) {
      // Common
      case 'commonBack': return l10n.commonBack;
      case 'commonSeeAll': return l10n.commonSeeAll;
      case 'commonError': return l10n.commonError;
      case 'commonRetry': return l10n.commonRetry;
      case 'commonShare': return l10n.commonShare;
      case 'commonOptional': return l10n.commonOptional;
      case 'commonCancel': return l10n.commonCancel;
      case 'defaultUserName': return l10n.defaultUserName;
      case 'notificationsTooltip': return l10n.notificationsTooltip;

      // Reservation Home
      case 'reservationBrandSuffix': return l10n.reservationBrandSuffix;
      case 'reservationBrandTagline': return l10n.reservationBrandTagline;
      case 'reservationNotifications': return l10n.reservationNotifications;
      case 'reservationProfile': return l10n.reservationProfile;
      case 'reservationMyBookings': return l10n.reservationMyBookings;
      case 'reservationUpcoming': return l10n.reservationUpcoming;
      case 'reservationOngoing': return l10n.reservationOngoing;
      case 'reservationCompleted': return l10n.reservationCompleted;
      case 'reservationCancelled': return l10n.reservationCancelled;
      case 'reservationSpecialOffers': return l10n.reservationSpecialOffers;
      case 'reservationOfferHotels': return l10n.reservationOfferHotels;
      case 'reservationOfferHotelsSub': return l10n.reservationOfferHotelsSub;
      case 'reservationOfferFlights': return l10n.reservationOfferFlights;
      case 'reservationOfferFlightsSub': return l10n.reservationOfferFlightsSub;
      case 'reservationOfferBus': return l10n.reservationOfferBus;
      case 'reservationOfferBusSub': return l10n.reservationOfferBusSub;
      case 'reservationOfferDelivery': return l10n.reservationOfferDelivery;
      case 'reservationOfferDeliverySub': return l10n.reservationOfferDeliverySub;
      case 'reservationReferralTitle': return l10n.reservationReferralTitle;
      case 'reservationReferralPrefix': return l10n.reservationReferralPrefix;
      case 'reservationReferralSuffix': return l10n.reservationReferralSuffix;
      case 'reservationNavHome': return l10n.reservationNavHome;
      case 'reservationNavExplore': return l10n.reservationNavExplore;
      case 'reservationNavBookings': return l10n.reservationNavBookings;
      case 'reservationNavProfile': return l10n.reservationNavProfile;
      case 'reservationNavQuickBook': return l10n.reservationNavQuickBook;
      case 'reservationQuickBookTitle': return l10n.reservationQuickBookTitle;
      case 'reservationQuickBookSubtitle': return l10n.reservationQuickBookSubtitle;
      case 'reservationMoreRestaurant': return l10n.reservationMoreRestaurant;
      case 'reservationMoreAds': return l10n.reservationMoreAds;
      case 'reservationMoreEvents': return l10n.reservationMoreEvents;
      case 'reservationMoreDelivery': return l10n.reservationMoreDelivery;
      case 'reservationCatBus': return l10n.reservationCatBus;
      case 'reservationCatFlights': return l10n.reservationCatFlights;
      case 'reservationCatHotels': return l10n.reservationCatHotels;
      case 'reservationCatTaxi': return l10n.reservationCatTaxi;
      case 'reservationCatDelivery': return l10n.reservationCatDelivery;
      case 'reservationCatMore': return l10n.reservationCatMore;

      // Bus Home
      case 'busHomeTitle': return l10n.busHomeTitle;
      case 'busPopularRoutes': return l10n.busPopularRoutes;
      case 'busNoPopularRoutes': return l10n.busNoPopularRoutes;
      case 'busComfortTitle': return l10n.busComfortTitle;
      case 'busSearchLabel': return l10n.busSearchLabel;
      case 'busSearchQuickBooking': return l10n.busSearchQuickBooking;
      case 'busSearchDeparture': return l10n.busSearchDeparture;
      case 'busSearchArrival': return l10n.busSearchArrival;
      case 'busSearchChoose': return l10n.busSearchChoose;
      case 'busSearchDate': return l10n.busSearchDate;
      case 'busSearchPassengers': return l10n.busSearchPassengers;
      case 'busSearchButton': return l10n.busSearchButton;
      case 'busSearchSwap': return l10n.busSearchSwap;
      case 'agencyTooltipActive': return l10n.agencyTooltipActive;
      case 'agencyTooltipInactive': return l10n.agencyTooltipInactive;

      // Search Results
      case 'busSearchSortBy': return l10n.busSearchSortBy;
      case 'busSearchSortDeparture': return l10n.busSearchSortDeparture;
      case 'busSearchSortPrice': return l10n.busSearchSortPrice;
      case 'busSearchSortDuration': return l10n.busSearchSortDuration;
      case 'busSearchFilters': return l10n.busSearchFilters;
      case 'busSearchNoResults': return l10n.busSearchNoResults;
      case 'busSearchNoResultsWithFilters': return l10n.busSearchNoResultsWithFilters;
      case 'busSearchNoResultsHint': return l10n.busSearchNoResultsHint;
      case 'busSearchNoResultsFiltersHint': return l10n.busSearchNoResultsFiltersHint;
      case 'busSearchClearFilters': return l10n.busSearchClearFilters;
      case 'busSearchNewSearch': return l10n.busSearchNewSearch;

      // Trip Detail
      case 'tripNotFound': return l10n.tripNotFound;
      case 'tripUnknownAgency': return l10n.tripUnknownAgency;
      case 'tripVerifiedAgency': return l10n.tripVerifiedAgency;
      case 'tripAmenities': return l10n.tripAmenities;
      case 'tripPrice': return l10n.tripPrice;
      case 'tripFull': return l10n.tripFull;
      case 'tripShareComingSoon': return l10n.tripShareComingSoon;
      case 'amenityWifi': return l10n.amenityWifi;
      case 'amenityAc': return l10n.amenityAc;
      case 'amenityUsb': return l10n.amenityUsb;
      case 'amenityToilet': return l10n.amenityToilet;
      case 'amenityTv': return l10n.amenityTv;

      // Seat Selection
      case 'seatSelectionTitle': return l10n.seatSelectionTitle;
      case 'seatSelectionError': return l10n.seatSelectionError;
      case 'seatLegendAvailable': return l10n.seatLegendAvailable;
      case 'seatLegendBooked': return l10n.seatLegendBooked;
      case 'seatLegendSelected': return l10n.seatLegendSelected;
      case 'seatLegendVip': return l10n.seatLegendVip;
      case 'seatSelectionDriver': return l10n.seatSelectionDriver;
      case 'seatSelectionAisle': return l10n.seatSelectionAisle;
      case 'seatSelectionChooseSeat': return l10n.seatSelectionChooseSeat;
      case 'seatSelectionContinue': return l10n.seatSelectionContinue;
      case 'seatSelectionConfirming': return l10n.seatSelectionConfirming;
      case 'seatSelectionTotal': return l10n.seatSelectionTotal;
      case 'seatSelectionVipSupplement': return l10n.seatSelectionVipSupplement;
      case 'seatMapEmpty': return l10n.seatMapEmpty;

      // Ticket
      case 'ticketNotFound': return l10n.ticketNotFound;
      case 'ticketBookingId': return l10n.ticketBookingId;
      case 'ticketTotalPaid': return l10n.ticketTotalPaid;
      case 'ticketCopyCode': return l10n.ticketCopyCode;
      case 'ticketShare': return l10n.ticketShare;
      case 'ticketAddCalendar': return l10n.ticketAddCalendar;
      case 'ticketCodeCopied': return l10n.ticketCodeCopied;
      case 'ticketCalendarComingSoon': return l10n.ticketCalendarComingSoon;
      case 'ticketDisclaimer': return l10n.ticketDisclaimer;

      // Payment
      case 'paymentTitle': return l10n.paymentTitle;
      case 'paymentTermsRequired': return l10n.paymentTermsRequired;
      case 'paymentPhoneRequired': return l10n.paymentPhoneRequired;
      case 'paymentPhoneInvalid': return l10n.paymentPhoneInvalid;
      case 'paymentEmailRequired': return l10n.paymentEmailRequired;
      case 'paymentEmailInvalid': return l10n.paymentEmailInvalid;
      case 'paymentNameRequired': return l10n.paymentNameRequired;
      case 'paymentNameInvalid': return l10n.paymentNameInvalid;
      case 'paymentErrorNetwork': return l10n.paymentErrorNetwork;
      case 'paymentErrorInsufficient': return l10n.paymentErrorInsufficient;
      case 'paymentErrorCancelled': return l10n.paymentErrorCancelled;
      case 'paymentErrorExpired': return l10n.paymentErrorExpired;
      case 'paymentErrorGeneric': return l10n.paymentErrorGeneric;
      case 'paymentRoute': return l10n.paymentRoute;
      case 'paymentSeat': return l10n.paymentSeat;
      case 'paymentSeats': return l10n.paymentSeats;
      case 'paymentSubtotal': return l10n.paymentSubtotal;
      case 'paymentVipSupplement': return l10n.paymentVipSupplement;
      case 'paymentServiceFee': return l10n.paymentServiceFee;
      case 'paymentTotal': return l10n.paymentTotal;
      case 'paymentMethodTitle': return l10n.paymentMethodTitle;
      case 'paymentInfoTitle': return l10n.paymentInfoTitle;
      case 'paymentFieldName': return l10n.paymentFieldName;
      case 'paymentFieldNameHint': return l10n.paymentFieldNameHint;
      case 'paymentFieldPhone': return l10n.paymentFieldPhone;
      case 'paymentFieldPhoneHint': return l10n.paymentFieldPhoneHint;
      case 'paymentFieldEmail': return l10n.paymentFieldEmail;
      case 'paymentFieldEmailHint': return l10n.paymentFieldEmailHint;
      case 'paymentWalletReady': return l10n.paymentWalletReady;
      case 'paymentSelectProvider': return l10n.paymentSelectProvider;
      case 'paymentTermsPrefix': return l10n.paymentTermsPrefix;
      case 'paymentTermsLink': return l10n.paymentTermsLink;
      case 'paymentTermsSuffix': return l10n.paymentTermsSuffix;
      case 'paymentProcessing': return l10n.paymentProcessing;
      case 'paymentPayButton': return l10n.paymentPayButton;

      // Agency Onboarding
      case 'agencyOnboardingTitle': return l10n.agencyOnboardingTitle;
      case 'agencyOnboardingAuthRequired': return l10n.agencyOnboardingAuthRequired;
      case 'agencyOnboardingHeroTitle': return l10n.agencyOnboardingHeroTitle;
      case 'agencyOnboardingHeroSubtitle': return l10n.agencyOnboardingHeroSubtitle;
      case 'agencyOnboardingBenefitsTitle': return l10n.agencyOnboardingBenefitsTitle;
      case 'agencyOnboardingBenefit1Title': return l10n.agencyOnboardingBenefit1Title;
      case 'agencyOnboardingBenefit1Desc': return l10n.agencyOnboardingBenefit1Desc;
      case 'agencyOnboardingBenefit2Title': return l10n.agencyOnboardingBenefit2Title;
      case 'agencyOnboardingBenefit2Desc': return l10n.agencyOnboardingBenefit2Desc;
      case 'agencyOnboardingBenefit3Title': return l10n.agencyOnboardingBenefit3Title;
      case 'agencyOnboardingBenefit3Desc': return l10n.agencyOnboardingBenefit3Desc;
      case 'agencyOnboardingMyAgencies': return l10n.agencyOnboardingMyAgencies;
      case 'agencyOnboardingOpenDashboard': return l10n.agencyOnboardingOpenDashboard;
      case 'agencyOnboardingEmptyTitle': return l10n.agencyOnboardingEmptyTitle;
      case 'agencyOnboardingEmptyMessage': return l10n.agencyOnboardingEmptyMessage;
      case 'agencyOnboardingCreateTitle': return l10n.agencyOnboardingCreateTitle;
      case 'agencyOnboardingFieldName': return l10n.agencyOnboardingFieldName;
      case 'agencyOnboardingFieldNameHint': return l10n.agencyOnboardingFieldNameHint;
      case 'agencyOnboardingFieldCountry': return l10n.agencyOnboardingFieldCountry;
      case 'agencyOnboardingFieldPhone': return l10n.agencyOnboardingFieldPhone;
      case 'agencyOnboardingFieldPhoneHint': return l10n.agencyOnboardingFieldPhoneHint;
      case 'agencyOnboardingFieldDescription': return l10n.agencyOnboardingFieldDescription;
      case 'agencyOnboardingFieldDescriptionHint': return l10n.agencyOnboardingFieldDescriptionHint;
      case 'agencyOnboardingCreating': return l10n.agencyOnboardingCreating;
      case 'agencyOnboardingCreateButton': return l10n.agencyOnboardingCreateButton;
      case 'agencyOnboardingTestMode': return l10n.agencyOnboardingTestMode;
      case 'agencyOnboardingNameRequired': return l10n.agencyOnboardingNameRequired;
      case 'agencyOnboardingNameTooShort': return l10n.agencyOnboardingNameTooShort;
      case 'agencyOnboardingPhoneInvalid': return l10n.agencyOnboardingPhoneInvalid;
      case 'agencyOnboardingCreateFailed': return l10n.agencyOnboardingCreateFailed;
      case 'agencyStatusActive': return l10n.agencyStatusActive;
      case 'agencyStatusPending': return l10n.agencyStatusPending;
      case 'agencyStatusRejected': return l10n.agencyStatusRejected;
      case 'agencyStatusSuspended': return l10n.agencyStatusSuspended;
      case 'agencyEntryBecomePartner': return l10n.agencyEntryBecomePartner;
      case 'agencyOnboardingManageAgency': return l10n.agencyOnboardingManageAgency;

      // Agency Dashboard
      case 'agencyDashboardTitle': return l10n.agencyDashboardTitle;
      case 'agencyDashboardExport': return l10n.agencyDashboardExport;
      case 'agencyDashboardExportComingSoon': return l10n.agencyDashboardExportComingSoon;
      case 'agencyDashboardScanTicket': return l10n.agencyDashboardScanTicket;
      case 'agencyDashboardCurrencyLabel': return l10n.agencyDashboardCurrencyLabel;
      case 'agencyDashboardKpiBookings': return l10n.agencyDashboardKpiBookings;
      case 'agencyDashboardKpiRevenue': return l10n.agencyDashboardKpiRevenue;
      case 'agencyDashboardKpiTrips': return l10n.agencyDashboardKpiTrips;
      case 'agencyDashboardKpiUpcoming': return l10n.agencyDashboardKpiUpcoming;
      case 'agencyDashboardVsLastPeriod': return l10n.agencyDashboardVsLastPeriod;
      case 'agencyDashboardNoChange': return l10n.agencyDashboardNoChange;
      case 'agencyDashboardRevenueChart': return l10n.agencyDashboardRevenueChart;
      case 'agencyDashboardNoBookings': return l10n.agencyDashboardNoBookings;
      case 'agencyDashboardNoBookingsHint': return l10n.agencyDashboardNoBookingsHint;
      case 'agencyDashboardNoBookingsRecentHint': return l10n.agencyDashboardNoBookingsRecentHint;
      case 'agencyDashboardStatusConfirmed': return l10n.agencyDashboardStatusConfirmed;
      case 'agencyDashboardStatusPending': return l10n.agencyDashboardStatusPending;
      case 'agencyDashboardStatusCompleted': return l10n.agencyDashboardStatusCompleted;
      case 'agencyDashboardStatusCancelled': return l10n.agencyDashboardStatusCancelled;
      case 'agencyDashboardBookingDistribution': return l10n.agencyDashboardBookingDistribution;
      case 'agencyDashboardActionNewTrip': return l10n.agencyDashboardActionNewTrip;
      case 'agencyDashboardActionScan': return l10n.agencyDashboardActionScan;
      case 'agencyDashboardActionSeats': return l10n.agencyDashboardActionSeats;
      case 'agencyDashboardActionSettings': return l10n.agencyDashboardActionSettings;
      case 'agencyDashboardQuickActions': return l10n.agencyDashboardQuickActions;
      case 'agencyDashboardUpcomingTrips': return l10n.agencyDashboardUpcomingTrips;
      case 'agencyDashboardNoTrips': return l10n.agencyDashboardNoTrips;
      case 'agencyDashboardNoTripsHint': return l10n.agencyDashboardNoTripsHint;
      case 'agencyDashboardRecentBookings': return l10n.agencyDashboardRecentBookings;
      case 'agencyDashboardNewTrip': return l10n.agencyDashboardNewTrip;
      case 'agencyDashboardNoAgencyTitle': return l10n.agencyDashboardNoAgencyTitle;
      case 'agencyDashboardNoAgencyMessage': return l10n.agencyDashboardNoAgencyMessage;
      case 'agencyDashboardCreateAgency': return l10n.agencyDashboardCreateAgency;
      case 'agencyDashboardExportTitle': return l10n.agencyDashboardExportTitle;
      case 'agencyDashboardExportPdf': return l10n.agencyDashboardExportPdf;
      case 'agencyDashboardExportPdfDesc': return l10n.agencyDashboardExportPdfDesc;
      case 'agencyDashboardExportCsv': return l10n.agencyDashboardExportCsv;
      case 'agencyDashboardExportCsvDesc': return l10n.agencyDashboardExportCsvDesc;

      // Agency Create Trip
      case 'agencyTripCreateTitle': return l10n.agencyTripCreateTitle;
      case 'agencyTripSectionRoute': return l10n.agencyTripSectionRoute;
      case 'agencyTripSectionSchedule': return l10n.agencyTripSectionSchedule;
      case 'agencyTripSectionPricing': return l10n.agencyTripSectionPricing;
      case 'agencyTripSectionBusConfig': return l10n.agencyTripSectionBusConfig;
      case 'agencyTripDepartureCity': return l10n.agencyTripDepartureCity;
      case 'agencyTripArrivalCity': return l10n.agencyTripArrivalCity;
      case 'agencyTripSelectDeparture': return l10n.agencyTripSelectDeparture;
      case 'agencyTripSelectArrival': return l10n.agencyTripSelectArrival;
      case 'agencyTripDepartureStation': return l10n.agencyTripDepartureStation;
      case 'agencyTripArrivalStation': return l10n.agencyTripArrivalStation;
      case 'agencyTripStationHint': return l10n.agencyTripStationHint;
      case 'agencyTripDepartureDateTime': return l10n.agencyTripDepartureDateTime;
      case 'agencyTripArrivalDateTime': return l10n.agencyTripArrivalDateTime;
      case 'agencyTripPricePerSeat': return l10n.agencyTripPricePerSeat;
      case 'agencyTripTotalSeats': return l10n.agencyTripTotalSeats;
      case 'agencyTripBusType': return l10n.agencyTripBusType;
      case 'agencyTripAmenities': return l10n.agencyTripAmenities;
      case 'agencyTripPreviewTitle': return l10n.agencyTripPreviewTitle;
      case 'agencyTripPublishButton': return l10n.agencyTripPublishButton;
      case 'agencyTripCreating': return l10n.agencyTripCreating;
      case 'agencyTripSuccessMessage': return l10n.agencyTripSuccessMessage;
      case 'agencyTripErrorMessage': return l10n.agencyTripErrorMessage;
      case 'agencyTripSearchCity': return l10n.agencyTripSearchCity;
      case 'agencyTripNoCityFound': return l10n.agencyTripNoCityFound;
      case 'agencyTripErrorCityRequired': return l10n.agencyTripErrorCityRequired;
      case 'agencyTripErrorSameCity': return l10n.agencyTripErrorSameCity;
      case 'agencyTripErrorDateOrder': return l10n.agencyTripErrorDateOrder;
      case 'agencyTripErrorDatePast': return l10n.agencyTripErrorDatePast;
      case 'agencyTripErrorPriceInvalid': return l10n.agencyTripErrorPriceInvalid;
      case 'agencyTripErrorPriceTooLow': return l10n.agencyTripErrorPriceTooLow;
      case 'agencyTripErrorSeatsInvalid': return l10n.agencyTripErrorSeatsInvalid;
      case 'agencyTripErrorSeatsTooMany': return l10n.agencyTripErrorSeatsTooMany;

      // QR Scan
      case 'qrScanTitle': return l10n.qrScanTitle;
      case 'qrScanAgencyRequiredTitle': return l10n.qrScanAgencyRequiredTitle;
      case 'qrScanAgencyRequiredMessage': return l10n.qrScanAgencyRequiredMessage;
      case 'qrScanGoToAgency': return l10n.qrScanGoToAgency;
      case 'qrScanManualEntry': return l10n.qrScanManualEntry;
      case 'qrScanTorchOn': return l10n.qrScanTorchOn;
      case 'qrScanTorchOff': return l10n.qrScanTorchOff;
      case 'qrScanValidating': return l10n.qrScanValidating;
      case 'qrScanInstructionTitle': return l10n.qrScanInstructionTitle;
      case 'qrScanInstructionSubtitle': return l10n.qrScanInstructionSubtitle;
      case 'qrScanRecentTitle': return l10n.qrScanRecentTitle;
      case 'qrScanUnknownPassenger': return l10n.qrScanUnknownPassenger;
      case 'qrScanFailed': return l10n.qrScanFailed;
      case 'qrScanSuccessTitle': return l10n.qrScanSuccessTitle;
      case 'qrScanSuccessSubtitle': return l10n.qrScanSuccessSubtitle;
      case 'qrScanSeats': return l10n.qrScanSeats;
      case 'qrScanAmount': return l10n.qrScanAmount;
      case 'qrScanRoute': return l10n.qrScanRoute;
      case 'qrScanDeparture': return l10n.qrScanDeparture;
      case 'qrScanNext': return l10n.qrScanNext;
      case 'qrScanRetry': return l10n.qrScanRetry;
      case 'qrScanManualTitle': return l10n.qrScanManualTitle;
      case 'qrScanManualSubtitle': return l10n.qrScanManualSubtitle;
      case 'qrScanManualValidate': return l10n.qrScanManualValidate;
      case 'qrScanManualEmpty': return l10n.qrScanManualEmpty;
      case 'qrScanManualTooShort': return l10n.qrScanManualTooShort;
      case 'qrScanCameraError': return l10n.qrScanCameraError;

      // Agency Seats
      case 'agencySeatsTitle': return l10n.agencySeatsTitle;
      case 'agencySeatsStatsTitle': return l10n.agencySeatsStatsTitle;
      case 'agencySeatsStatAvailable': return l10n.agencySeatsStatAvailable;
      case 'agencySeatsStatReserved': return l10n.agencySeatsStatReserved;
      case 'agencySeatsStatSold': return l10n.agencySeatsStatSold;
      case 'agencySeatsStatBlocked': return l10n.agencySeatsStatBlocked;
      case 'agencySeatsLegendReserved': return l10n.agencySeatsLegendReserved;
      case 'agencySeatsLegendSold': return l10n.agencySeatsLegendSold;
      case 'agencySeatsLegendBlocked': return l10n.agencySeatsLegendBlocked;
      case 'agencySeatsUpdating': return l10n.agencySeatsUpdating;
      case 'agencySeatsCapacityTitle': return l10n.agencySeatsCapacityTitle;
      case 'agencySeatsBulkMode': return l10n.agencySeatsBulkMode;
      case 'agencySeatsBulkSelected': return l10n.agencySeatsBulkSelected;
      case 'agencySeatsBulkUnblock': return l10n.agencySeatsBulkUnblock;
      case 'agencySeatsBulkBlock': return l10n.agencySeatsBulkBlock;
      case 'agencySeatsConfirmBlockTitle': return l10n.agencySeatsConfirmBlockTitle;
      case 'agencySeatsConfirmBlock': return l10n.agencySeatsConfirmBlock;
      case 'agencySeatsBulkBlockTitle': return l10n.agencySeatsBulkBlockTitle;
      case 'agencySeatsUpdateError': return l10n.agencySeatsUpdateError;
      case 'agencySeatsCannotSelectBooked': return l10n.agencySeatsCannotSelectBooked;
      case 'agencySeatsEmptyTitle': return l10n.agencySeatsEmptyTitle;
      case 'agencySeatsEmptyMessage': return l10n.agencySeatsEmptyMessage;

      // Filters
      case 'filtersTitle': return l10n.filtersTitle;
      case 'filtersNoActive': return l10n.filtersNoActive;
      case 'filtersClearAll': return l10n.filtersClearAll;
      case 'filtersApply': return l10n.filtersApply;
      case 'filtersPriceTitle': return l10n.filtersPriceTitle;
      case 'filtersMaxBudget': return l10n.filtersMaxBudget;
      case 'filtersBusTypeTitle': return l10n.filtersBusTypeTitle;
      case 'filtersBusTypeAll': return l10n.filtersBusTypeAll;
      case 'filtersAmenitiesTitle': return l10n.filtersAmenitiesTitle;
      case 'filtersAmenitiesAll': return l10n.filtersAmenitiesAll;

      // Popular Route
      case 'popularRouteBadge': return l10n.popularRouteBadge;

      // Currency
      case 'currencySelectTitle': return l10n.currencySelectTitle;
      case 'currencySearchHint': return l10n.currencySearchHint;
      case 'currencyPopular': return l10n.currencyPopular;
      case 'currencyNoResult': return l10n.currencyNoResult;

      default: return null;
    }
  }
}
