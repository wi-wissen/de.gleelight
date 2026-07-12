import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gleelight/services/yeelight_service.dart';

/// A stand-in for a real lamp that speaks the inter-operation protocol:
/// newline-terminated JSON, RESULT messages echoing the request "id", and
/// unsolicited NOTIFICATION messages.
class FakeLamp {
  final ServerSocket server;
  final List<Map<String, dynamic>> received = [];
  final List<Socket> clients = [];

  /// How many times a client has connected. Proves whether the app reuses one
  /// connection or opens a new socket per command.
  int connectionCount = 0;

  /// When set, the lamp pushes a notification just before answering, so we can
  /// check the app does not mistake it for the command's result.
  bool notifyBeforeResult = false;

  /// When set, the lamp accepts the command but never answers (a dead socket).
  bool goSilent = false;

  /// When set, the lamp rejects every command (spec 4.2 error object).
  bool rejectCommands = false;

  FakeLamp._(this.server);

  static Future<FakeLamp> start(int port) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    final lamp = FakeLamp._(server);
    server.listen(lamp._handleClient);
    return lamp;
  }

  String get ip => server.address.address;

  void _handleClient(Socket socket) {
    connectionCount++;
    clients.add(socket);

    var buffer = '';
    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\r\n')) {
          final index = buffer.indexOf('\r\n');
          final line = buffer.substring(0, index);
          buffer = buffer.substring(index + 2);
          if (line.trim().isEmpty) continue;

          final request = jsonDecode(line) as Map<String, dynamic>;
          received.add(request);
          if (goSilent) continue;

          if (notifyBeforeResult) {
            socket.write(
              '${jsonEncode({
                    'method': 'props',
                    'params': {'bright': '42'},
                  })}\r\n',
            );
          }

          if (rejectCommands) {
            socket.write('${jsonEncode({
                  'id': request['id'],
                  'error': {'code': -1, 'message': 'unsupported method'},
                })}\r\n');
            continue;
          }

          final method = request['method'];
          final result =
              method == 'get_prop' ? ['on', '100', '4000', '0'] : ['ok'];
          socket.write(
              '${jsonEncode({'id': request['id'], 'result': result})}\r\n');
        }
      },
      onError: (_) {},
      onDone: () => clients.remove(socket),
    );
  }

  /// Push a NOTIFICATION, as a lamp does when its state changes (spec 4.3).
  void pushProps(Map<String, String> props) {
    for (final client in clients) {
      client.write('${jsonEncode({'method': 'props', 'params': props})}\r\n');
    }
  }

  /// Drop the connection from the lamp's side.
  void dropConnections() {
    for (final client in [...clients]) {
      client.destroy();
    }
    clients.clear();
  }

  Future<void> stop() async {
    dropConnections();
    await server.close();
  }
}

/// Wait for [condition] to become true, polling until [timeout].
Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late FakeLamp lamp;
  late YeelightService service;

  setUp(() async {
    lamp = await FakeLamp.start(55443);
    service = YeelightService();
  });

  tearDown(() async {
    service.forget(lamp.ip);
    await lamp.stop();
  });

  test('reuses one connection across commands instead of reconnecting',
      () async {
    expect(await service.setPower(lamp.ip, true), isTrue);
    expect(await service.setPower(lamp.ip, false), isTrue);
    expect(await service.setBrightness(lamp.ip, 50), isTrue);

    expect(lamp.connectionCount, 1,
        reason: 'all three commands must share one socket');
    expect(lamp.received.map((r) => r['method']),
        containsAll(['set_power', 'set_bright']));
  });

  test('sends set_power with the parameters the spec defines', () async {
    await service.setPower(lamp.ip, true);

    final command = lamp.received.firstWhere((r) => r['method'] == 'set_power');
    expect(command['params'], ['on', 'smooth', 500]);
    expect(command['id'], isA<int>());
  });

  test('matches a RESULT to its request even when a notification arrives first',
      () async {
    lamp.notifyBeforeResult = true;

    // Would previously have resolved with the notification (first \r\n in the
    // buffer), which carries no "result" and would read as a failure.
    expect(await service.setPower(lamp.ip, true), isTrue);
  });

  test('treats an error response as a failure, not a success', () async {
    // A lamp rejecting a command answers with "error", not "result" (spec 4.2).
    // The old code checked only "response != null" and called this a success.
    lamp.rejectCommands = true;

    expect(await service.setPower(lamp.ip, true), isFalse);
    expect(await service.setBrightness(lamp.ip, 50), isFalse);
  });

  test('surfaces a pushed NOTIFICATION as a state update', () async {
    await service.setPower(lamp.ip, true); // opens the connection

    final updates = <LampStateUpdate>[];
    final subscription = service.stateStream.listen(updates.add);
    addTearDown(subscription.cancel);

    lamp.pushProps({'power': 'off', 'bright': '30'});

    await waitFor(() => updates.any((u) => u.power == false));

    final update = updates.firstWhere((u) => u.power == false);
    expect(update.ip, lamp.ip);
    expect(update.brightness, 30);
  });

  test('reconnects on its own after the lamp drops the connection', () async {
    await service.setPower(lamp.ip, true);
    expect(lamp.connectionCount, 1);

    lamp.dropConnections();
    await waitFor(() => !service.isConnected(lamp.ip));

    // Backoff starts at 1s; the next command must not wait for it.
    expect(await service.setPower(lamp.ip, true), isTrue);
    expect(lamp.connectionCount, 2, reason: 'must have rebuilt the socket');
  });

  test('recovers when the socket is alive but the lamp stopped answering',
      () async {
    await service.setPower(lamp.ip, true);

    // The command is written into a socket that never answers - exactly what a
    // Wi-Fi drop leaves behind. The service must give up on it and retry on a
    // fresh connection rather than hanging.
    lamp.goSilent = true;
    final failed = await service.setPower(lamp.ip, true);
    expect(failed, isFalse);

    lamp.goSilent = false;
    expect(await service.setPower(lamp.ip, true), isTrue,
        reason: 'a working lamp must be controllable again immediately');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('reports a lamp on a dead IP as unreachable quickly', () async {
    final stopwatch = Stopwatch()..start();
    // .2 is a loopback address nothing listens on: connect is refused at once.
    final result = await service.setPower('127.0.0.2', true);
    stopwatch.stop();

    expect(result, isFalse);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)),
        reason: 'a tap must not block on a retry ladder');

    service.forget('127.0.0.2');
  });
}
