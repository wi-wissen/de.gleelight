// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GleeLight';

  @override
  String get all => 'All';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get offline => 'Offline';

  @override
  String allOn(int count) {
    return 'All on ($count)';
  }

  @override
  String allOff(int count) {
    return 'All off ($count)';
  }

  @override
  String someOn(int onCount, int totalCount) {
    return '$onCount of $totalCount on';
  }

  @override
  String get scenes => 'Scenes';

  @override
  String get settings => 'Settings';

  @override
  String get moreOptions => 'More options';

  @override
  String get edit => 'Edit';

  @override
  String get deleteLamp => 'Delete lamp';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get noLampsFound => 'No lamps found';

  @override
  String get pullToRefresh => 'Pull down to refresh';

  @override
  String get setupLanControl =>
      'Make sure:\n\n1. Your Yeelight lamps are turned on\n2. LAN Control is enabled in the Yeelight app:\n   • Open Yeelight app\n   • Select your lamp\n   • Tap gear icon (Settings)\n   • Enable \'LAN Control\'\n3. Your device is on the same WiFi network';

  @override
  String get noLampsOnline => 'No lamps online';

  @override
  String get ensureLampsReachable => 'Make sure your lamps\nare reachable.';

  @override
  String get noScenes => 'No scenes';

  @override
  String get scenesAutoCreated =>
      'Scenes are automatically created\nwhen you save settings.';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameHint => 'e.g. Living room';

  @override
  String get selectLamps => 'Select lamps:';

  @override
  String get noLampsOnlineShort => 'No lamps online';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get editLamp => 'Edit lamp';

  @override
  String get lampName => 'Lamp name';

  @override
  String get lampNameHint => 'e.g. Floor lamp';

  @override
  String get iconColor => 'Icon color:';

  @override
  String get deleteSceneTitle => 'Delete scene';

  @override
  String deleteSceneConfirm(String name) {
    return 'Do you really want to delete the scene \"$name\"?';
  }

  @override
  String get deleteLampTitle => 'Delete lamp';

  @override
  String deleteLampConfirm(String name) {
    return 'Do you really want to delete the lamp \"$name\"?';
  }

  @override
  String get deleteGroupTitle => 'Delete group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Do you really want to delete the group \"$name\"?';
  }

  @override
  String sceneApplied(String name) {
    return 'Scene \"$name\" applied';
  }

  @override
  String sceneSaved(String name) {
    return 'Scene \"$name\" saved';
  }

  @override
  String get showScenes => 'Show scenes';

  @override
  String get saveScene => 'Save scene';

  @override
  String get sceneName => 'Scene name';

  @override
  String get sceneNameHint => 'e.g. Relaxation';

  @override
  String lampsOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lamps online',
      one: '1 lamp online',
    );
    return '$_temp0';
  }

  @override
  String get brightness => 'Brightness';

  @override
  String get colorTemperature => 'Color temperature';

  @override
  String get warm => 'Warm';

  @override
  String get neutral => 'Neutral';

  @override
  String get cool => 'Cool';

  @override
  String get saveAsScene => 'Save as scene';

  @override
  String get bright => 'Bright';

  @override
  String get dimmed => 'Dimmed';

  @override
  String brightnessPercent(int value) {
    return 'Brightness $value%';
  }

  @override
  String brightnessAndColorTemp(int brightness, int colorTemp) {
    return 'Brightness $brightness%, ${colorTemp}K';
  }

  @override
  String brightnessAndRgb(int brightness, String rgb) {
    return 'Brightness $brightness%, RGB #$rgb';
  }

  @override
  String groupScenes(String groupName) {
    return '$groupName - Scenes';
  }

  @override
  String groupSettings(String groupName) {
    return '$groupName - Settings';
  }

  @override
  String get ensureLampsOn =>
      'Make sure your lamps\nare turned on and reachable.';
}
