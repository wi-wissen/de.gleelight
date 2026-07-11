// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'GleeLight';

  @override
  String get all => 'Todas';

  @override
  String get on => 'Encendida';

  @override
  String get off => 'Apagada';

  @override
  String get offline => 'Sin conexión';

  @override
  String allOn(int count) {
    return 'Todas encendidas ($count)';
  }

  @override
  String allOff(int count) {
    return 'Todas apagadas ($count)';
  }

  @override
  String someOn(int onCount, int totalCount) {
    return '$onCount de $totalCount encendidas';
  }

  @override
  String get scenes => 'Escenas';

  @override
  String get settings => 'Ajustes';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get edit => 'Editar';

  @override
  String get deleteLamp => 'Eliminar lámpara';

  @override
  String get deleteGroup => 'Eliminar grupo';

  @override
  String get noLampsFound => 'No se encontraron lámparas';

  @override
  String get pullToRefresh => 'Desliza hacia abajo para actualizar';

  @override
  String get setupLanControl =>
      'Asegúrate de que:\n\n1. Tus lámparas Yeelight estén encendidas\n2. El control LAN esté activado en la app Yeelight:\n   • Abre la app Yeelight\n   • Selecciona tu lámpara\n   • Toca el ícono de engranaje (Ajustes)\n   • Activa \'Control LAN\'\n3. Tu dispositivo esté en la misma red WiFi';

  @override
  String get noLampsOnline => 'No hay lámparas en línea';

  @override
  String get ensureLampsReachable =>
      'Asegúrate de que tus lámparas\nestén accesibles.';

  @override
  String get noScenes => 'Sin escenas';

  @override
  String get scenesAutoCreated =>
      'Las escenas se crean automáticamente\ncuando guardas los ajustes.';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupNameHint => 'ej. Sala de estar';

  @override
  String get selectLamps => 'Seleccionar lámparas:';

  @override
  String get noLampsOnlineShort => 'No hay lámparas en línea';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Crear';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get editLamp => 'Editar lámpara';

  @override
  String get lampName => 'Nombre de la lámpara';

  @override
  String get lampNameHint => 'ej. Lámpara de pie';

  @override
  String get iconColor => 'Color del icono:';

  @override
  String get deleteSceneTitle => 'Eliminar escena';

  @override
  String deleteSceneConfirm(String name) {
    return '¿Realmente deseas eliminar la escena \"$name\"?';
  }

  @override
  String get deleteLampTitle => 'Eliminar lámpara';

  @override
  String deleteLampConfirm(String name) {
    return '¿Realmente deseas eliminar la lámpara \"$name\"?';
  }

  @override
  String get deleteGroupTitle => 'Eliminar grupo';

  @override
  String deleteGroupConfirm(String name) {
    return '¿Realmente deseas eliminar el grupo \"$name\"?';
  }

  @override
  String sceneApplied(String name) {
    return 'Escena \"$name\" aplicada';
  }

  @override
  String sceneSaved(String name) {
    return 'Escena \"$name\" guardada';
  }

  @override
  String get showScenes => 'Mostrar escenas';

  @override
  String get saveScene => 'Guardar escena';

  @override
  String get sceneName => 'Nombre de la escena';

  @override
  String get sceneNameHint => 'ej. Relajación';

  @override
  String lampsOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lámparas en línea',
      one: '1 lámpara en línea',
    );
    return '$_temp0';
  }

  @override
  String get brightness => 'Brillo';

  @override
  String get colorTemperature => 'Temperatura de color';

  @override
  String get warm => 'Cálido';

  @override
  String get neutral => 'Neutro';

  @override
  String get cool => 'Frío';

  @override
  String get saveAsScene => 'Guardar como escena';

  @override
  String get bright => 'Brillante';

  @override
  String get dimmed => 'Atenuado';

  @override
  String brightnessPercent(int value) {
    return 'Brillo $value%';
  }

  @override
  String brightnessAndColorTemp(int brightness, int colorTemp) {
    return 'Brillo $brightness%, ${colorTemp}K';
  }

  @override
  String brightnessAndRgb(int brightness, String rgb) {
    return 'Brillo $brightness%, RGB #$rgb';
  }

  @override
  String groupScenes(String groupName) {
    return '$groupName - Escenas';
  }

  @override
  String groupSettings(String groupName) {
    return '$groupName - Ajustes';
  }

  @override
  String get ensureLampsOn =>
      'Asegúrate de que tus lámparas\nestén encendidas y accesibles.';
}
