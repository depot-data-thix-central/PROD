import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Extension pour accéder facilement aux traductions depuis un BuildContext.
///
/// Usage : `context.l10n.maCleDeTraduction`
extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
