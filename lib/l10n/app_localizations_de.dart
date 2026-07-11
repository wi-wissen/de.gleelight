// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'GleeLight';

  @override
  String get all => 'Alle';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';

  @override
  String get offline => 'Offline';

  @override
  String allOn(int count) {
    return 'Alle an ($count)';
  }

  @override
  String allOff(int count) {
    return 'Alle aus ($count)';
  }

  @override
  String someOn(int onCount, int totalCount) {
    return '$onCount von $totalCount an';
  }

  @override
  String get scenes => 'Szenen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get moreOptions => 'Weitere Optionen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get deleteLamp => 'Lampe löschen';

  @override
  String get deleteGroup => 'Gruppe löschen';

  @override
  String get noLampsFound => 'Keine Lampen gefunden';

  @override
  String get pullToRefresh => 'Ziehe nach unten um zu aktualisieren';

  @override
  String get setupLanControl =>
      'Stelle sicher:\n\n1. Deine Yeelight-Lampen sind eingeschaltet\n2. LAN-Steuerung ist in der Yeelight-App aktiviert:\n   • Öffne die Yeelight-App\n   • Wähle deine Lampe\n   • Tippe auf das Zahnrad (Einstellungen)\n   • Aktiviere \'LAN-Steuerung\'\n3. Dein Gerät ist im selben WLAN-Netzwerk';

  @override
  String get noLampsOnline => 'Keine Lampen online';

  @override
  String get ensureLampsReachable =>
      'Stelle sicher, dass deine Lampen\nerreichbar sind.';

  @override
  String get noScenes => 'Keine Szenen';

  @override
  String get scenesAutoCreated =>
      'Szenen werden automatisch erstellt\nwenn du Einstellungen speicherst.';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get groupName => 'Gruppenname';

  @override
  String get groupNameHint => 'z.B. Wohnzimmer';

  @override
  String get selectLamps => 'Lampen auswählen:';

  @override
  String get noLampsOnlineShort => 'Keine Lampen online';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get create => 'Erstellen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get editLamp => 'Lampe bearbeiten';

  @override
  String get lampName => 'Lampenname';

  @override
  String get lampNameHint => 'z.B. Stehlampe';

  @override
  String get iconColor => 'Icon-Farbe:';

  @override
  String get deleteSceneTitle => 'Szene löschen';

  @override
  String deleteSceneConfirm(String name) {
    return 'Möchtest du die Szene \"$name\" wirklich löschen?';
  }

  @override
  String get deleteLampTitle => 'Lampe löschen';

  @override
  String deleteLampConfirm(String name) {
    return 'Möchtest du die Lampe \"$name\" wirklich löschen?';
  }

  @override
  String get deleteGroupTitle => 'Gruppe löschen';

  @override
  String deleteGroupConfirm(String name) {
    return 'Möchtest du die Gruppe \"$name\" wirklich löschen?';
  }

  @override
  String sceneApplied(String name) {
    return 'Szene \"$name\" angewendet';
  }

  @override
  String sceneSaved(String name) {
    return 'Szene \"$name\" wurde gespeichert';
  }

  @override
  String get showScenes => 'Szenen anzeigen';

  @override
  String get saveScene => 'Szene speichern';

  @override
  String get sceneName => 'Szenenname';

  @override
  String get sceneNameHint => 'z.B. Entspannung';

  @override
  String lampsOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lampen online',
      one: '1 Lampe online',
    );
    return '$_temp0';
  }

  @override
  String get brightness => 'Helligkeit';

  @override
  String get colorTemperature => 'Farbtemperatur';

  @override
  String get warm => 'Warm';

  @override
  String get neutral => 'Neutral';

  @override
  String get cool => 'Kühl';

  @override
  String get saveAsScene => 'Als Szene speichern';

  @override
  String get bright => 'Hell';

  @override
  String get dimmed => 'Gedimmt';

  @override
  String brightnessPercent(int value) {
    return 'Helligkeit $value%';
  }

  @override
  String brightnessAndColorTemp(int brightness, int colorTemp) {
    return 'Helligkeit $brightness%, ${colorTemp}K';
  }

  @override
  String brightnessAndRgb(int brightness, String rgb) {
    return 'Helligkeit $brightness%, RGB #$rgb';
  }

  @override
  String groupScenes(String groupName) {
    return '$groupName - Szenen';
  }

  @override
  String groupSettings(String groupName) {
    return '$groupName - Einstellungen';
  }

  @override
  String get ensureLampsOn =>
      'Stelle sicher, dass deine Lampen\neingeschaltet und erreichbar sind.';
}
