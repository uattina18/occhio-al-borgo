import 'app_localizations.dart';

class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt() : super('it');

  // ======== HOME ========
  @override
  String get appTitle => 'Occhio al Borgo';
  @override
  String helpRequest() => 'RICHIEDI AIUTO';
  @override
  String homeWelcome(Object username) => 'Bentornata, $username!';
  @override
  String get lastBorgo => 'Ultimo borgo visitato';
  @override
  String get takePhoto => 'SCATTA UN NUOVO BORGO';
  @override
  String get badgesTitle => 'Badge ottenuti';
  @override
  String get eventsTitle => 'Eventi in arrivo';
  @override
  String get discoverMore => 'SCOPRI DI PIÙ';

  // ======== EXPLORE ========
  @override
  String get explore => 'Esplora Borghi';
  @override
  String get loading => 'Caricamento in corso…';
  @override
  String get dataNotAvailable => 'Dati non disponibili';
  @override
  String get searchHint => 'Cerca un borgo…';
  @override
  String get noBorghiFound => 'Nessun borgo trovato.';
  @override
  String noBorghiFor(Object query) => 'Nessun borgo per "$query".';

  // ======== PROFILE ========
  @override
  String get profileUpdated => '✅ Foto aggiornata con successo!';
  @override
  String get profileSync => '✅ Dati aggiornati dal cloud';
  @override
  String get syncCloud => 'AGGIORNA DATI DA CLOUD';
  @override
  String get earnedBadges => 'BADGE OTTENUTI';
  @override
  String get profileTitle => 'Profilo';
  @override
  String get editProfile => 'MODIFICA PROFILO';
  @override
  String get addFriend => 'AGGIUNGI UN AMICO';
  @override
  String get recognizedBorghi => 'BORGHІ RICONOSCIUTI';
  @override
  String get goToCommunity => 'VAI ALLA COMMUNITY';
  @override
  String get uploadError => 'Errore durante l’upload';

  // ======== SETTINGS / NOTIFICHE ========
  @override
  String get settings => 'Impostazioni';
  @override
  String get theme => 'Tema';
  @override
  String get light => 'Chiaro';
  @override
  String get dark => 'Scuro';
  @override
  String get system => 'Sistema';
  @override
  String get notificationsActive => 'Notifiche attive';
  @override
  String get devAndDebug => 'Sviluppo e debug';
  @override
  String get showSyncLogs => 'Mostra log di sincronizzazione';
  @override
  String get logout => 'Logout';
  @override
  String get contactSupport => 'CONTATTA L’ASSISTENZA';
  @override
  String get confirmLogoutTitle => 'Conferma logout';
  @override
  String get confirmLogoutBody => 'Vuoi davvero uscire dal tuo account?';
  @override
  String get cancel => 'Annulla';
  @override
  String get noMailApp => 'Nessuna app di posta trovata.';
  @override
  String mailOpenError(Object error) => 'Errore apertura email: $error';
  @override
  String get friendRequests => 'Richieste d’amicizia';
  @override
  String get notificationsTitle => 'Notifiche';
  @override
  String get accept => 'Accetta';
  @override
  String get reject => 'Rifiuta';
  @override
  String userSentRequest(Object username) =>
      '$username ti ha inviato una richiesta';
  @override
  String get homeTab => 'Home';
  @override
  String get exploreTab => 'Esplora';
  @override
  String get notificationsTab => 'Notifiche';
  @override
  String get profileTab => 'Profilo';
}
