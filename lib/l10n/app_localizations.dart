import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [Locale('it'), Locale('en')];

  // ======== HOME ========
  String get appTitle;
  String helpRequest();
  String homeWelcome(Object username);
  String get lastBorgo;
  String get takePhoto;
  String get badgesTitle;
  String get eventsTitle;
  String get discoverMore;

  // ======== EXPLORE ========
  String get explore;
  String get loading;
  String get dataNotAvailable;
  String get searchHint;
  String get noBorghiFound;
  String noBorghiFor(Object query);

  // ======== PROFILE ========
  String get profileUpdated;
  String get profileSync;
  String get syncCloud;
  String get earnedBadges;

  // 👤 aggiunte nuove chiavi
  String get profileTitle;
  String get editProfile;
  String get addFriend;
  String get recognizedBorghi;
  String get goToCommunity;
  String get uploadError;

  // ======== SETTINGS / NOTIFICHE ========
  String get settings;
  String get theme;
  String get light;
  String get dark;
  String get system;
  String get notificationsActive;
  String get devAndDebug;
  String get showSyncLogs;
  String get logout;
  String get contactSupport;
  String get confirmLogoutTitle;
  String get confirmLogoutBody;
  String get cancel;
  String get noMailApp;
  String mailOpenError(Object error);
  String get friendRequests;
  String get notificationsTitle;
  String get accept;
  String get reject;
  String userSentRequest(Object username);
  String get homeTab;
  String get exploreTab;
  String get notificationsTab;
  String get profileTab;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => ['it', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'it':
      return AppLocalizationsIt();
    case 'en':
      return AppLocalizationsEn();
    default:
      return AppLocalizationsIt();
  }
}
