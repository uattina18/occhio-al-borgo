import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  // ======== HOME ========
  @override
  String get appTitle => 'Watch the Village';
  @override
  String helpRequest() => 'REQUEST HELP';
  @override
  String homeWelcome(Object username) => 'Welcome back, $username!';
  @override
  String get lastBorgo => 'Last visited village';
  @override
  String get takePhoto => 'TAKE A NEW VILLAGE PHOTO';
  @override
  String get badgesTitle => 'Earned Badges';
  @override
  String get eventsTitle => 'Upcoming Events';
  @override
  String get discoverMore => 'DISCOVER MORE';

  // ======== EXPLORE ========
  @override
  String get explore => 'Explore Villages';
  @override
  String get loading => 'Loading…';
  @override
  String get dataNotAvailable => 'Data not available';
  @override
  String get searchHint => 'Search for a village…';
  @override
  String get noBorghiFound => 'No villages found.';
  @override
  String noBorghiFor(Object query) => 'No villages for "$query".';

  // ======== PROFILE ========
  @override
  String get profileUpdated => '✅ Photo updated successfully!';
  @override
  String get profileSync => '✅ Data synced from cloud';
  @override
  String get syncCloud => 'SYNC FROM CLOUD';
  @override
  String get earnedBadges => 'EARNED BADGES';
  @override
  String get profileTitle => 'Profile';
  @override
  String get editProfile => 'EDIT PROFILE';
  @override
  String get addFriend => 'ADD FRIEND';
  @override
  String get recognizedBorghi => 'RECOGNIZED VILLAGES';
  @override
  String get goToCommunity => 'GO TO COMMUNITY';
  @override
  String get uploadError => 'Error during upload';

  // ======== SETTINGS / NOTIFICATIONS ========
  @override
  String get settings => 'Settings';
  @override
  String get theme => 'Theme';
  @override
  String get light => 'Light';
  @override
  String get dark => 'Dark';
  @override
  String get system => 'System';
  @override
  String get notificationsActive => 'Notifications enabled';
  @override
  String get devAndDebug => 'Development & debug';
  @override
  String get showSyncLogs => 'Show sync logs';
  @override
  String get logout => 'Logout';
  @override
  String get contactSupport => 'CONTACT SUPPORT';
  @override
  String get confirmLogoutTitle => 'Confirm logout';
  @override
  String get confirmLogoutBody => 'Do you really want to sign out?';
  @override
  String get cancel => 'Cancel';
  @override
  String get noMailApp => 'No mail app found.';
  @override
  String mailOpenError(Object error) => 'Error opening email: $error';
  @override
  String get friendRequests => 'Friend requests';
  @override
  String get notificationsTitle => 'Notifications';
  @override
  String get accept => 'Accept';
  @override
  String get reject => 'Reject';
  @override
  String userSentRequest(Object username) => '$username sent you a request';
  @override
  String get homeTab => 'Home';
  @override
  String get exploreTab => 'Explore';
  @override
  String get notificationsTab => 'Notifications';
  @override
  String get profileTab => 'Profile';
}
