import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GleeLight'**
  String get appTitle;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @allOn.
  ///
  /// In en, this message translates to:
  /// **'All on ({count})'**
  String allOn(int count);

  /// No description provided for @allOff.
  ///
  /// In en, this message translates to:
  /// **'All off ({count})'**
  String allOff(int count);

  /// No description provided for @someOn.
  ///
  /// In en, this message translates to:
  /// **'{onCount} of {totalCount} on'**
  String someOn(int onCount, int totalCount);

  /// No description provided for @scenes.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get scenes;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteLamp.
  ///
  /// In en, this message translates to:
  /// **'Delete lamp'**
  String get deleteLamp;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @noLampsFound.
  ///
  /// In en, this message translates to:
  /// **'No lamps found'**
  String get noLampsFound;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh'**
  String get pullToRefresh;

  /// No description provided for @setupLanControl.
  ///
  /// In en, this message translates to:
  /// **'Make sure:\n\n1. Your Yeelight lamps are turned on\n2. LAN Control is enabled in the Yeelight app:\n   • Open Yeelight app\n   • Select your lamp\n   • Tap gear icon (Settings)\n   • Enable \'LAN Control\'\n3. Your device is on the same WiFi network'**
  String get setupLanControl;

  /// No description provided for @noLampsOnline.
  ///
  /// In en, this message translates to:
  /// **'No lamps online'**
  String get noLampsOnline;

  /// No description provided for @ensureLampsReachable.
  ///
  /// In en, this message translates to:
  /// **'Make sure your lamps\nare reachable.'**
  String get ensureLampsReachable;

  /// No description provided for @noScenes.
  ///
  /// In en, this message translates to:
  /// **'No scenes'**
  String get noScenes;

  /// No description provided for @scenesAutoCreated.
  ///
  /// In en, this message translates to:
  /// **'Scenes are automatically created\nwhen you save settings.'**
  String get scenesAutoCreated;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Living room'**
  String get groupNameHint;

  /// No description provided for @selectLamps.
  ///
  /// In en, this message translates to:
  /// **'Select lamps:'**
  String get selectLamps;

  /// No description provided for @noLampsOnlineShort.
  ///
  /// In en, this message translates to:
  /// **'No lamps online'**
  String get noLampsOnlineShort;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editLamp.
  ///
  /// In en, this message translates to:
  /// **'Edit lamp'**
  String get editLamp;

  /// No description provided for @lampName.
  ///
  /// In en, this message translates to:
  /// **'Lamp name'**
  String get lampName;

  /// No description provided for @lampNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Floor lamp'**
  String get lampNameHint;

  /// No description provided for @iconColor.
  ///
  /// In en, this message translates to:
  /// **'Icon color:'**
  String get iconColor;

  /// No description provided for @deleteSceneTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete scene'**
  String get deleteSceneTitle;

  /// No description provided for @deleteSceneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete the scene \"{name}\"?'**
  String deleteSceneConfirm(String name);

  /// No description provided for @deleteLampTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete lamp'**
  String get deleteLampTitle;

  /// No description provided for @deleteLampConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete the lamp \"{name}\"?'**
  String deleteLampConfirm(String name);

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete the group \"{name}\"?'**
  String deleteGroupConfirm(String name);

  /// No description provided for @sceneApplied.
  ///
  /// In en, this message translates to:
  /// **'Scene \"{name}\" applied'**
  String sceneApplied(String name);

  /// No description provided for @sceneSaved.
  ///
  /// In en, this message translates to:
  /// **'Scene \"{name}\" saved'**
  String sceneSaved(String name);

  /// No description provided for @showScenes.
  ///
  /// In en, this message translates to:
  /// **'Show scenes'**
  String get showScenes;

  /// No description provided for @saveScene.
  ///
  /// In en, this message translates to:
  /// **'Save scene'**
  String get saveScene;

  /// No description provided for @sceneName.
  ///
  /// In en, this message translates to:
  /// **'Scene name'**
  String get sceneName;

  /// No description provided for @sceneNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Relaxation'**
  String get sceneNameHint;

  /// No description provided for @lampsOnline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 lamp online} other{{count} lamps online}}'**
  String lampsOnline(int count);

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @colorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Color temperature'**
  String get colorTemperature;

  /// No description provided for @warm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get warm;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get neutral;

  /// No description provided for @cool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get cool;

  /// No description provided for @saveAsScene.
  ///
  /// In en, this message translates to:
  /// **'Save as scene'**
  String get saveAsScene;

  /// No description provided for @bright.
  ///
  /// In en, this message translates to:
  /// **'Bright'**
  String get bright;

  /// No description provided for @dimmed.
  ///
  /// In en, this message translates to:
  /// **'Dimmed'**
  String get dimmed;

  /// No description provided for @brightnessPercent.
  ///
  /// In en, this message translates to:
  /// **'Brightness {value}%'**
  String brightnessPercent(int value);

  /// No description provided for @brightnessAndColorTemp.
  ///
  /// In en, this message translates to:
  /// **'Brightness {brightness}%, {colorTemp}K'**
  String brightnessAndColorTemp(int brightness, int colorTemp);

  /// No description provided for @brightnessAndRgb.
  ///
  /// In en, this message translates to:
  /// **'Brightness {brightness}%, RGB #{rgb}'**
  String brightnessAndRgb(int brightness, String rgb);

  /// No description provided for @groupScenes.
  ///
  /// In en, this message translates to:
  /// **'{groupName} - Scenes'**
  String groupScenes(String groupName);

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'{groupName} - Settings'**
  String groupSettings(String groupName);

  /// No description provided for @ensureLampsOn.
  ///
  /// In en, this message translates to:
  /// **'Make sure your lamps\nare turned on and reachable.'**
  String get ensureLampsOn;
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
      <String>['de', 'en', 'es', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
