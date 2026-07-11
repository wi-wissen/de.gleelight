// Ad-hoc probe against the real lamps on the LAN.
// Read-only unless run with --toggle.
//
//   dart run tool/lamp_probe.dart
//   dart run tool/lamp_probe.dart --toggle
import 'dart:async';

import 'package:gleelight/services/yeelight_service.dart';

Future<void> main(List<String> args) async {
  final toggle = args.contains('--toggle');
  final service = YeelightService();

  final found = <String, YeelightDevice>{};
  service.deviceStream.listen((d) => found[d.ip] = d);

  final updates = <LampStateUpdate>[];
  service.stateStream.listen((u) {
    updates.add(u);
    print('   push <- ${u.ip}: ${u.props}');
  });
  service.reachabilityStream
      .listen((r) => print('   conn <- ${r.ip}: reachable=${r.reachable}'));

  print('== 1. Discovery (M-SEARCH) ==');
  final discovery = Stopwatch()..start();
  await service.startDiscovery();
  discovery.stop();

  if (found.isEmpty) {
    print('Keine Lampen gefunden (${discovery.elapsedMilliseconds} ms).');
    service.dispose();
    return;
  }

  print('${found.length} Lampe(n) in ${discovery.elapsedMilliseconds} ms:');
  for (final d in found.values) {
    print('  - ${d.name}  ${d.ip}  model=${d.model}  id=${d.id}  '
        'power=${d.power ? "on" : "off"}  bright=${d.brightness}');
  }

  print('\n== 2. Verbindungen aufbauen (warmUp) ==');
  final warm = Stopwatch()..start();
  service.warmUp(found.keys);
  // Give the sockets a moment to come up.
  await Future.delayed(const Duration(milliseconds: 800));
  warm.stop();
  for (final ip in found.keys) {
    print('  $ip connected=${service.isConnected(ip)}');
  }

  print('\n== 3. Round-Trip auf warmer Verbindung (get_prop) ==');
  for (final ip in found.keys) {
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      final props = await service.getProperties(ip, ['power', 'bright']);
      sw.stop();
      print('  $ip  ${sw.elapsedMilliseconds} ms  -> $props');
    }
  }

  final idleArg =
      args.firstWhere((a) => a.startsWith('--idle='), orElse: () => '');
  if (idleArg.isNotEmpty) {
    final seconds = int.parse(idleArg.split('=').last);
    print('\n== Leerlauf: $seconds s nichts tun (Keepalive laeuft) ==');
    await Future.delayed(Duration(seconds: seconds));
    for (final ip in found.keys) {
      print('  $ip nach Leerlauf: connected=${service.isConnected(ip)}');
      final sw = Stopwatch()..start();
      final props = await service.getProperties(ip, ['power']);
      sw.stop();
      print('  $ip  erster Zugriff nach Leerlauf: '
          '${sw.elapsedMilliseconds} ms -> $props');
    }
  }

  if (!toggle) {
    print('\n(Kein --toggle: nichts geschaltet.)');
    service.dispose();
    return;
  }

  print('\n== 4. Schalten: Latenz eines Tastendrucks ==');
  for (final device in found.values) {
    final ip = device.ip;
    final original = device.power;

    final sw = Stopwatch()..start();
    final ok = await service.setPower(ip, !original);
    sw.stop();
    print('  ${device.name}: set_power ${!original ? "on" : "off"}  '
        '-> ok=$ok  in ${sw.elapsedMilliseconds} ms');

    await Future.delayed(const Duration(milliseconds: 1200));

    final back = Stopwatch()..start();
    final restored = await service.setPower(ip, original);
    back.stop();
    print('  ${device.name}: zurueck auf ${original ? "on" : "off"}  '
        '-> ok=$restored  in ${back.elapsedMilliseconds} ms');
  }

  print('\n== 5. Ungefragte NOTIFICATIONs waehrend des Tests ==');
  print('  ${updates.length} Push-Updates von den Lampen empfangen');

  service.dispose();
}
