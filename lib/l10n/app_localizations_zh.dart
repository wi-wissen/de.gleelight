// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'GleeLight';

  @override
  String get all => '全部';

  @override
  String get on => '开';

  @override
  String get off => '关';

  @override
  String get offline => '离线';

  @override
  String allOn(int count) {
    return '全部开启 ($count)';
  }

  @override
  String allOff(int count) {
    return '全部关闭 ($count)';
  }

  @override
  String someOn(int onCount, int totalCount) {
    return '$totalCount 中有 $onCount 个开启';
  }

  @override
  String get scenes => '场景';

  @override
  String get settings => '设置';

  @override
  String get moreOptions => '更多选项';

  @override
  String get edit => '编辑';

  @override
  String get deleteLamp => '删除灯具';

  @override
  String get deleteGroup => '删除分组';

  @override
  String get noLampsFound => '未找到灯具';

  @override
  String get pullToRefresh => '下拉刷新';

  @override
  String get setupLanControl =>
      '请确保：\n\n1. 您的 Yeelight 灯具已开启\n2. 在 Yeelight 应用中启用局域网控制：\n   • 打开 Yeelight 应用\n   • 选择您的灯具\n   • 点击齿轮图标（设置）\n   • 启用局域网控制\n3. 您的设备连接到相同的 WiFi 网络';

  @override
  String get noLampsOnline => '没有在线灯具';

  @override
  String get ensureLampsReachable => '请确保您的灯具\n可以访问。';

  @override
  String get noScenes => '没有场景';

  @override
  String get scenesAutoCreated => '保存设置时\n会自动创建场景。';

  @override
  String get newGroup => '新建分组';

  @override
  String get groupName => '分组名称';

  @override
  String get groupNameHint => '例如：客厅';

  @override
  String get selectLamps => '选择灯具：';

  @override
  String get noLampsOnlineShort => '没有在线灯具';

  @override
  String get cancel => '取消';

  @override
  String get create => '创建';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get editLamp => '编辑灯具';

  @override
  String get lampName => '灯具名称';

  @override
  String get lampNameHint => '例如：落地灯';

  @override
  String get iconColor => '图标颜色：';

  @override
  String get deleteSceneTitle => '删除场景';

  @override
  String deleteSceneConfirm(String name) {
    return '确定要删除场景「$name」吗？';
  }

  @override
  String get deleteLampTitle => '删除灯具';

  @override
  String deleteLampConfirm(String name) {
    return '确定要删除灯具「$name」吗？';
  }

  @override
  String get deleteGroupTitle => '删除分组';

  @override
  String deleteGroupConfirm(String name) {
    return '确定要删除分组「$name」吗？';
  }

  @override
  String sceneApplied(String name) {
    return '已应用场景「$name」';
  }

  @override
  String sceneSaved(String name) {
    return '场景「$name」已保存';
  }

  @override
  String get showScenes => '显示场景';

  @override
  String get saveScene => '保存场景';

  @override
  String get sceneName => '场景名称';

  @override
  String get sceneNameHint => '例如：放松';

  @override
  String lampsOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个灯具在线',
      one: '1 个灯具在线',
    );
    return '$_temp0';
  }

  @override
  String get brightness => '亮度';

  @override
  String get colorTemperature => '色温';

  @override
  String get warm => '暖色';

  @override
  String get neutral => '中性';

  @override
  String get cool => '冷色';

  @override
  String get saveAsScene => '保存为场景';

  @override
  String get bright => '明亮';

  @override
  String get dimmed => '昏暗';

  @override
  String brightnessPercent(int value) {
    return '亮度 $value%';
  }

  @override
  String brightnessAndColorTemp(int brightness, int colorTemp) {
    return '亮度 $brightness%，${colorTemp}K';
  }

  @override
  String brightnessAndRgb(int brightness, String rgb) {
    return '亮度 $brightness%，RGB #$rgb';
  }

  @override
  String groupScenes(String groupName) {
    return '$groupName - 场景';
  }

  @override
  String groupSettings(String groupName) {
    return '$groupName - 设置';
  }

  @override
  String get ensureLampsOn => '请确保您的灯具\n已开启且可访问。';
}
