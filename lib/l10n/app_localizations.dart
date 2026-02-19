import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Lobster Chat'**
  String get appTitle;

  /// New conversation button
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Search bar placeholder
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get searchConversations;

  /// User online status
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Input field hint
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get inputHint;

  /// Agent selector title
  ///
  /// In en, this message translates to:
  /// **'Select Agent'**
  String get selectAgent;

  /// General agent name
  ///
  /// In en, this message translates to:
  /// **'General Assistant'**
  String get generalAssistant;

  /// General agent description
  ///
  /// In en, this message translates to:
  /// **'Can answer various questions'**
  String get generalAssistantDesc;

  /// Code agent name
  ///
  /// In en, this message translates to:
  /// **'Code Assistant'**
  String get codeAssistant;

  /// Code agent description
  ///
  /// In en, this message translates to:
  /// **'Focus on programming problems'**
  String get codeAssistantDesc;

  /// Writing agent name
  ///
  /// In en, this message translates to:
  /// **'Writing Assistant'**
  String get writingAssistant;

  /// Writing agent description
  ///
  /// In en, this message translates to:
  /// **'Article polishing and creative writing'**
  String get writingAssistantDesc;

  /// Message outline drawer title
  ///
  /// In en, this message translates to:
  /// **'Message Outline'**
  String get messageOutline;

  /// Context usage drawer title
  ///
  /// In en, this message translates to:
  /// **'Context Usage'**
  String get contextUsage;

  /// Sub agents drawer title
  ///
  /// In en, this message translates to:
  /// **'Sub Agents'**
  String get subAgents;

  /// Camera button
  ///
  /// In en, this message translates to:
  /// **'Take Picture'**
  String get takePicture;

  /// Photo album button
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// File button
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Compress history button
  ///
  /// In en, this message translates to:
  /// **'Compress History'**
  String get compressHistory;

  /// Clear context button
  ///
  /// In en, this message translates to:
  /// **'Clear Context'**
  String get clearContext;

  /// Server management page title
  ///
  /// In en, this message translates to:
  /// **'AI Servers'**
  String get aiServers;

  /// Current server section
  ///
  /// In en, this message translates to:
  /// **'Currently Using'**
  String get currentUse;

  /// Server list section
  ///
  /// In en, this message translates to:
  /// **'Server List'**
  String get serverList;

  /// Add server button
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Appearance section
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// General section
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Notifications setting
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Privacy setting
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// About section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// About app item
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// Help item
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Danger zone section
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Clear all data button
  ///
  /// In en, this message translates to:
  /// **'Clear All Data'**
  String get clearAllData;

  /// Delete account button
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// AI thinking indicator
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get thinking;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation'**
  String get startConversation;

  /// Today timestamp
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Yesterday timestamp
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Past 7 days timestamp
  ///
  /// In en, this message translates to:
  /// **'Past 7 Days'**
  String get past7Days;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
