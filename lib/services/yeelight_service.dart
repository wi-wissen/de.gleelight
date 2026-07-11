import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A property update pushed by a lamp (NOTIFICATION message, spec 4.3)
/// or read back from a keepalive poll.
class LampStateUpdate {
  final String ip;
  final Map<String, String> props;

  LampStateUpdate(this.ip, this.props);

  bool? get power => props.containsKey('power') ? props['power'] == 'on' : null;
  int? get brightness => int.tryParse(props['bright'] ?? '');
  int? get colorTemp => int.tryParse(props['ct'] ?? '');
  int? get rgb => int.tryParse(props['rgb'] ?? '');
}

/// Reachability change of a lamp's control connection.
class LampReachability {
  final String ip;
  final bool reachable;

  LampReachability(this.ip, this.reachable);
}

/// Service for Yeelight lamp discovery and control.
///
/// Holds one long-lived TCP control connection per lamp (as the inter-operation
/// spec intends), so a command is a single write on an already-open socket
/// instead of a fresh TCP handshake. State changes are learned from the lamp's
/// NOTIFICATION messages rather than by re-running discovery.
class YeelightService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _multicastPort = 1982;
  static const int _commandPort = 55443;

  /// A lamp on the local network answers within a few hundred ms. Anything
  /// slower is a dead IP, so fail fast and recover instead of blocking the tap.
  static const Duration _connectTimeout = Duration(milliseconds: 1500);
  static const Duration _commandTimeout = Duration(milliseconds: 2000);

  /// Detects a silently-dead socket (Wi-Fi drop, lamp unplugged) in the
  /// background, before the user presses anything. 3 commands/min stays far
  /// below the lamp's quota of 60/min per connection.
  static const Duration _keepAliveInterval = Duration(seconds: 20);

  /// Singleton: every screen shares the same warm connection pool.
  static final YeelightService _instance = YeelightService._();
  factory YeelightService() => _instance;
  static YeelightService get instance => _instance;
  YeelightService._();

  final StreamController<YeelightDevice> _deviceController =
      StreamController.broadcast();
  final StreamController<LampStateUpdate> _stateController =
      StreamController.broadcast();
  final StreamController<LampReachability> _reachabilityController =
      StreamController.broadcast();

  final Map<String, _LampConnection> _connections = {};

  RawDatagramSocket? _udpSocket;
  Timer? _udpCloseTimer;
  Timer? _searchTimer;
  Completer<void>? _searchCompleter;
  bool _disposed = false;

  /// Lamps found by discovery.
  Stream<YeelightDevice> get deviceStream => _deviceController.stream;

  /// Property changes pushed by the lamps.
  Stream<LampStateUpdate> get stateStream => _stateController.stream;

  /// Control connection up/down per lamp.
  Stream<LampReachability> get reachabilityStream =>
      _reachabilityController.stream;

  // === CONNECTIONS ===

  _LampConnection _connection(String ip) {
    return _connections.putIfAbsent(
      ip,
      () => _LampConnection(
        ip: ip,
        onProps: (props) {
          if (!_stateController.isClosed) {
            _stateController.add(LampStateUpdate(ip, props));
          }
        },
        onReachability: (reachable) {
          if (!_reachabilityController.isClosed) {
            _reachabilityController.add(LampReachability(ip, reachable));
          }
        },
      ),
    );
  }

  /// Open control connections up front so the first button press is instant.
  void warmUp(Iterable<String> ips) {
    for (final ip in ips) {
      _connection(ip).ensureConnected();
    }
  }

  /// Verify every connection is really alive (a Wi-Fi drop kills a socket
  /// without a FIN, so `write()` would succeed into the void). Call this when
  /// the app comes back to the foreground.
  Future<void> refreshConnections() async {
    await Future.wait(_connections.values.map((c) => c.verify()));
  }

  /// A lamp moved to a new IP (DHCP): drop the dead connection, warm the new one.
  void relocate(String oldIp, String newIp) {
    if (oldIp == newIp) return;
    _connections.remove(oldIp)?.dispose();
    _connection(newIp).ensureConnected();
  }

  /// Forget a lamp entirely.
  void forget(String ip) {
    _connections.remove(ip)?.dispose();
  }

  bool isConnected(String ip) => _connections[ip]?.isConnected ?? false;

  // === COMMANDS ===

  /// Send a command over the lamp's persistent connection.
  ///
  /// Returns the parsed RESULT message, or null if the lamp could not be
  /// reached or answered with an error.
  Future<Map<String, dynamic>?> sendCommand(
    String ip,
    String method,
    List<dynamic> params,
  ) async {
    return _connection(ip).send(method, params);
  }

  /// True if the lamp answered with a RESULT (not an error) per spec 4.2.
  Future<bool> _ok(Future<Map<String, dynamic>?> response) async {
    final result = await response;
    if (result == null) return false;
    if (result['error'] != null) {
      print('⚠️ Lamp rejected command: ${result['error']}');
      return false;
    }
    return result['result'] != null;
  }

  /// Turn lamp on/off.
  Future<bool> setPower(String ip, bool on,
      {String effect = 'smooth', int duration = 500}) {
    return _ok(
        sendCommand(ip, 'set_power', [on ? 'on' : 'off', effect, duration]));
  }

  /// Set brightness (1-100).
  ///
  /// `set_bright` is only accepted while the lamp is on (spec 4.1), so an off
  /// lamp has to be switched on first. There is no "brightness only" scene
  /// class we could use to do it in one command.
  Future<bool> setBrightness(
    String ip,
    int brightness, {
    String effect = 'smooth',
    int duration = 500,
    bool isOn = true,
  }) async {
    if (!isOn) {
      await setPower(ip, true, effect: effect, duration: duration);
    }
    return _ok(sendCommand(
        ip, 'set_bright', [brightness.clamp(1, 100), effect, duration]));
  }

  /// Set color temperature (1700-6500K). Only accepted while the lamp is on,
  /// so an off lamp is driven through `set_scene` instead.
  Future<bool> setColorTemp(
    String ip,
    int colorTemp, {
    String effect = 'smooth',
    int duration = 500,
    bool isOn = true,
    int brightness = 100,
  }) {
    final value = colorTemp.clamp(1700, 6500);
    if (!isOn) {
      return _ok(sendCommand(
          ip, 'set_scene', ['ct', value, brightness.clamp(1, 100)]));
    }
    return _ok(sendCommand(ip, 'set_ct_abx', [value, effect, duration]));
  }

  /// Set RGB color. Only accepted while the lamp is on, see [setColorTemp].
  Future<bool> setRgb(
    String ip,
    int rgb, {
    String effect = 'smooth',
    int duration = 500,
    bool isOn = true,
    int brightness = 100,
  }) {
    final value = rgb.clamp(0, 16777215);
    if (!isOn) {
      return _ok(sendCommand(
          ip, 'set_scene', ['color', value, brightness.clamp(1, 100)]));
    }
    return _ok(sendCommand(ip, 'set_rgb', [value, effect, duration]));
  }

  /// Set a scene (accepted in both on and off state, spec 4.1).
  Future<bool> setScene(String ip, String sceneClass, List<dynamic> params) {
    return _ok(sendCommand(ip, 'set_scene', [sceneClass, ...params]));
  }

  /// Query properties.
  Future<Map<String, dynamic>?> getProperties(
      String ip, List<String> properties) async {
    final result = await sendCommand(ip, 'get_prop', properties);
    if (result == null || result['error'] != null) return null;
    final values = result['result'];
    if (values is! List) return null;
    return Map.fromIterables(properties, values);
  }

  // === DISCOVERY ===

  /// Discover lamps. Multicast search first (that is what the spec defines and
  /// it answers in well under a second); the TCP probes are only a fallback for
  /// networks that block multicast.
  Future<void> startDiscovery({List<String> knownIPs = const []}) async {
    if (_disposed) return;
    try {
      final foundByUdp = await _searchMulticast();
      if (_disposed) return;

      // Probe stored IPs that multicast did not cover.
      final remaining =
          knownIPs.where((ip) => !foundByUdp.contains(ip)).toList();
      int foundByProbe = 0;
      if (remaining.isNotEmpty) {
        final results = await Future.wait(remaining.map(_probeHost));
        if (_disposed) return;
        for (final device in results) {
          if (device != null) {
            foundByProbe++;
            _deviceController.add(device);
          }
        }
      }

      // Full subnet sweep only if we still have nothing to show for it.
      final total = foundByUdp.length + foundByProbe;
      if (total == 0 || (knownIPs.isNotEmpty && total < knownIPs.length / 2)) {
        await _scanLocalNetwork(
          excludeIPs: {...foundByUdp, ...remaining},
        );
      }
    } catch (e) {
      print('❌ Discovery error: $e');
    }
  }

  /// Kept for call sites that pass known IPs explicitly.
  Future<void> startDiscoveryWithKnownDevices(List<String> knownIPs) {
    return startDiscovery(knownIPs: knownIPs);
  }

  /// Send an M-SEARCH and collect the unicast responses. Returns the IPs found.
  Future<Set<String>> _searchMulticast(
      {Duration wait = const Duration(milliseconds: 1200)}) async {
    final found = <String>{};

    _udpCloseTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket = socket;
      socket.broadcastEnabled = true;
      socket.multicastHops = 1;
      socket.joinMulticast(InternetAddress(_multicastAddress));

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final device = _parseDiscoveryResponse(utf8.decode(datagram.data));
        if (device != null) {
          found.add(device.ip);
          _deviceController.add(device);
        }
      });

      const searchMessage = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1982\r\n'
          'MAN: "ssdp:discover"\r\n'
          'ST: wifi_bulb\r\n'
          '\r\n';
      final data = Uint8List.fromList(utf8.encode(searchMessage));

      socket.send(data, InternetAddress(_multicastAddress), _multicastPort);
      socket.send(data, InternetAddress('255.255.255.255'), _multicastPort);

      // Collect the unicast answers. dispose() ends the wait early rather than
      // leaving the search - and the subnet sweep behind it - running.
      final collected = Completer<void>();
      _searchCompleter = collected;
      _searchTimer?.cancel();
      _searchTimer = Timer(wait, () {
        if (!collected.isCompleted) collected.complete();
      });
      await collected.future;
    } catch (e) {
      print('❌ Multicast search error: $e');
    } finally {
      final s = socket;
      if (_disposed) {
        s?.close();
        if (identical(_udpSocket, s)) _udpSocket = null;
      } else {
        // Keep listening a little longer for slow lamps, then close this socket.
        _udpCloseTimer?.cancel();
        _udpCloseTimer = Timer(const Duration(seconds: 3), () {
          s?.close();
          if (identical(_udpSocket, s)) _udpSocket = null;
        });
      }
    }

    return found;
  }

  /// Determine local /24 network ranges.
  Future<List<String>> _getLocalNetworkRanges() async {
    final ranges = <String>[];
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.isLinkLocal) {
            final parts = addr.address.split('.');
            final base = '${parts[0]}.${parts[1]}.${parts[2]}';
            if (!ranges.contains(base)) ranges.add(base);
          }
        }
      }
    } catch (e) {
      print('❌ Network interface error: $e');
    }
    return ranges;
  }

  /// Sweep the local subnet for lamps. Last resort: 254 probes per range.
  Future<void> _scanLocalNetwork({Set<String>? excludeIPs}) async {
    try {
      final ranges = await _getLocalNetworkRanges();
      if (ranges.isEmpty) return;

      final exclude = excludeIPs ?? <String>{};

      for (final base in ranges) {
        // Batch the probes: 254 simultaneous sockets is hard on the OS and on
        // the lamps (they accept 4 TCP connections at a time).
        for (int start = 1; start <= 254; start += 32) {
          if (_disposed) return;
          final batch = <Future<YeelightDevice?>>[];
          for (int i = start; i < start + 32 && i <= 254; i++) {
            final ip = '$base.$i';
            if (!exclude.contains(ip)) batch.add(_probeHost(ip));
          }
          final results = await Future.wait(batch);
          for (final device in results) {
            if (device != null) _deviceController.add(device);
          }
        }
      }
    } catch (e) {
      print('❌ Network scan error: $e');
    }
  }

  /// Probe a single host for a Yeelight control port.
  ///
  /// Uses a throwaway socket: this runs against hundreds of IPs that are not
  /// lamps, and we do not want a connection entry for each of them.
  Future<YeelightDevice?> _probeHost(String ip) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, _commandPort,
          timeout: const Duration(milliseconds: 1200));
      socket.setOption(SocketOption.tcpNoDelay, true);

      const props = ['power', 'bright', 'ct', 'rgb', 'name', 'model'];
      final response = await _probeCommand(socket, 'get_prop', props);
      final result = response?['result'];
      if (result is! List || result.isEmpty) return null;

      String value(int i) =>
          (i < result.length && result[i] != null) ? result[i].toString() : '';

      final name = value(4);
      final model = value(5);

      return YeelightDevice(
        // get_prop cannot return the device id (only SSDP can), so lamps found
        // this way get a stable IP-derived id.
        id: 'lamp_${ip.replaceAll('.', '_')}',
        name: name.isNotEmpty ? name : 'Yeelight ($ip)',
        model: model.isNotEmpty ? model : 'unknown',
        ip: ip,
        power: value(0) == 'on',
        brightness: int.tryParse(value(1)) ?? 100,
        colorTemp: int.tryParse(value(2)),
        rgb: int.tryParse(value(3)),
        supportedMethods: _defaultSupportedMethods,
      );
    } catch (e) {
      // Timeout / connection refused is the normal case for a non-lamp IP.
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// One request/response round trip on a throwaway probe socket.
  Future<Map<String, dynamic>?> _probeCommand(
    Socket socket,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final command = jsonEncode({'id': 1, 'method': method, 'params': params});
      socket.write('$command\r\n');
      await socket.flush();

      final completer = Completer<Map<String, dynamic>>();
      final buffer = StringBuffer();

      late StreamSubscription subscription;
      subscription = socket.listen(
        (data) {
          buffer.write(utf8.decode(data, allowMalformed: true));
          for (final line in _takeLines(buffer)) {
            final message = _decode(line);
            // Skip NOTIFICATIONs, we want the RESULT for our request.
            if (message != null &&
                message['id'] == 1 &&
                !completer.isCompleted) {
              completer.complete(message);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(const SocketException('closed'));
          }
        },
        cancelOnError: true,
      );

      try {
        return await completer.future.timeout(const Duration(seconds: 2));
      } finally {
        await subscription.cancel();
      }
    } catch (e) {
      return null;
    }
  }

  static const List<String> _defaultSupportedMethods = [
    'get_prop',
    'set_power',
    'toggle',
    'set_bright',
    'set_ct_abx',
    'set_rgb',
    'set_scene',
  ];

  /// Parse an SSDP search response / advertisement (spec 3.1, 3.2).
  YeelightDevice? _parseDiscoveryResponse(String response) {
    try {
      final lines = response.split('\r\n');
      final start = lines.first.trim();
      if (!start.contains('200 OK') && !start.startsWith('NOTIFY')) return null;

      String? id, model, location, name;
      int? brightness, colorTemp, rgb;
      bool? power;
      List<String> supportedMethods = [];

      for (final line in lines) {
        final separator = line.indexOf(':');
        if (separator <= 0) continue;

        final key = line.substring(0, separator).trim().toLowerCase();
        final value = line.substring(separator + 1).trim();

        switch (key) {
          case 'id':
            id = value;
            break;
          case 'model':
            model = value;
            break;
          case 'location':
            location = value;
            break;
          case 'name':
            name = value;
            break;
          case 'power':
            power = value == 'on';
            break;
          case 'bright':
            brightness = int.tryParse(value);
            break;
          case 'ct':
            colorTemp = int.tryParse(value);
            break;
          case 'rgb':
            rgb = int.tryParse(value);
            break;
          case 'support':
            supportedMethods = value.split(RegExp(r'\s+'));
            break;
        }
      }

      if (id == null || location == null) return null;

      // location is "yeelight://192.168.1.239:55443"
      final ip = Uri.parse(location).host;
      if (ip.isEmpty) return null;

      return YeelightDevice(
        id: id,
        name: (name == null || name.isEmpty) ? 'Yeelight $model' : name,
        model: model ?? 'unknown',
        ip: ip,
        power: power ?? false,
        brightness: brightness ?? 100,
        colorTemp: colorTemp,
        rgb: rgb,
        supportedMethods: supportedMethods.isEmpty
            ? _defaultSupportedMethods
            : supportedMethods,
      );
    } catch (e) {
      print('Parse error: $e');
      return null;
    }
  }

  /// Close all connections and sockets and stop any discovery in flight.
  void dispose() {
    _disposed = true;

    _searchTimer?.cancel();
    _searchTimer = null;
    // End the wait rather than cancelling it: startDiscovery is parked on this
    // future and would otherwise never return.
    if (_searchCompleter?.isCompleted == false) _searchCompleter!.complete();
    _searchCompleter = null;

    _udpCloseTimer?.cancel();
    _udpCloseTimer = null;
    _udpSocket?.close();
    _udpSocket = null;

    for (final connection in _connections.values) {
      connection.dispose();
    }
    _connections.clear();
  }
}

/// A persistent control connection to one lamp.
///
/// Commands are written to an already-open socket, RESULT messages are matched
/// back to their request by "id" (spec 4.1/4.2), and NOTIFICATION messages
/// (spec 4.3) are forwarded as state updates. A dead socket is detected by the
/// keepalive and reconnected in the background.
class _LampConnection {
  final String ip;
  final void Function(Map<String, String> props) onProps;
  final void Function(bool reachable) onReachability;

  _LampConnection({
    required this.ip,
    required this.onProps,
    required this.onReachability,
  });

  Socket? _socket;
  Completer<Socket>? _connecting;
  StreamSubscription? _subscription;

  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final StringBuffer _buffer = StringBuffer();

  Timer? _keepAlive;
  Timer? _reconnect;
  int _reconnectAttempt = 0;
  int _nextId = 1;
  bool _disposed = false;
  bool _reachable = true;

  bool get isConnected => _socket != null;

  /// Open the connection if it is not up yet. Safe to call repeatedly.
  /// A failure here is not an error: the reconnect timer takes over.
  void ensureConnected() {
    if (_disposed || _socket != null) return;
    _connect().then((_) {}, onError: (_) {});
  }

  Future<Socket> _connect() {
    final existing = _socket;
    if (existing != null) return Future.value(existing);

    final inFlight = _connecting;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<Socket>();
    _connecting = completer;

    Socket.connect(ip, YeelightService._commandPort,
            timeout: YeelightService._connectTimeout)
        .then((socket) {
      if (_disposed) {
        socket.destroy();
        completer.completeError(const SocketException('disposed'));
        return;
      }

      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _buffer.clear();
      _reconnectAttempt = 0;

      _subscription = socket.listen(
        _onData,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _startKeepAlive();
      _setReachable(true);
      completer.complete(socket);
    }).catchError((error) {
      completer.completeError(error);
      _scheduleReconnect();
      _setReachable(false);
    }).whenComplete(() {
      if (identical(_connecting, completer)) _connecting = null;
    });

    return completer.future;
  }

  void _onData(Uint8List data) {
    _buffer.write(utf8.decode(data, allowMalformed: true));
    for (final line in _takeLines(_buffer)) {
      final message = _decode(line);
      if (message == null) continue;

      // NOTIFICATION: the lamp telling us its state changed (spec 4.3).
      if (message['method'] == 'props') {
        final params = message['params'];
        if (params is Map) {
          onProps(params.map((k, v) => MapEntry('$k', '$v')));
        }
        continue;
      }

      // RESULT: match it back to the request that is waiting for it.
      final id = message['id'];
      if (id is int) {
        final completer = _pending.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
      }
    }
  }

  /// Write a command on the open socket. Reconnects and retries once if the
  /// socket turned out to be dead.
  Future<Map<String, dynamic>?> send(
    String method,
    List<dynamic> params, {
    bool isRetry = false,
  }) async {
    if (_disposed) return null;

    Socket socket;
    try {
      socket = await _connect();
    } catch (e) {
      return null;
    }

    final id = _nextId++;
    if (_nextId > 0x7FFFFFFF) _nextId = 1;

    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    try {
      socket.write(
          '${jsonEncode({'id': id, 'method': method, 'params': params})}\r\n');
    } catch (e) {
      _pending.remove(id);
      _handleDisconnect();
      return isRetry ? null : send(method, params, isRetry: true);
    }

    try {
      final result =
          await completer.future.timeout(YeelightService._commandTimeout);
      _setReachable(true);
      return result;
    } on TimeoutException {
      _pending.remove(id);
      // A socket that swallows a command without answering is dead (Wi-Fi drop
      // leaves no FIN behind). Rebuild it and try once more.
      _handleDisconnect();
      if (isRetry) {
        _setReachable(false);
        return null;
      }
      return send(method, params, isRetry: true);
    } catch (e) {
      _pending.remove(id);
      return null;
    }
  }

  /// Actively check the socket is alive; used when the app is resumed.
  Future<void> verify() async {
    if (_disposed) return;
    await send('get_prop', ['power', 'bright', 'ct', 'rgb']).then((result) {
      final values = result?['result'];
      if (values is List && values.length >= 4) {
        onProps({
          'power': '${values[0]}',
          'bright': '${values[1]}',
          'ct': '${values[2]}',
          'rgb': '${values[3]}',
        });
      }
    });
  }

  void _startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(YeelightService._keepAliveInterval, (_) {
      if (_socket == null) return;
      // Doubles as a state refresh, so the UI stays right even if a
      // notification was missed.
      verify();
    });
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _buffer.clear();
    _keepAlive?.cancel();
    _keepAlive = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const SocketException('connection lost'));
      }
    }
    _pending.clear();

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnect != null || _socket != null) return;

    // 1s, 2s, 4s, 8s, 16s, then every 30s.
    final seconds = _reconnectAttempt >= 5 ? 30 : (1 << _reconnectAttempt);
    _reconnectAttempt++;

    _reconnect = Timer(Duration(seconds: seconds), () {
      _reconnect = null;
      ensureConnected();
    });
  }

  void _setReachable(bool reachable) {
    if (_reachable == reachable) return;
    _reachable = reachable;
    onReachability(reachable);
  }

  void dispose() {
    _disposed = true;
    _keepAlive?.cancel();
    _reconnect?.cancel();
    _subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const SocketException('disposed'));
      }
    }
    _pending.clear();
  }
}

/// Pull all complete "\r\n"-terminated messages out of [buffer].
List<String> _takeLines(StringBuffer buffer) {
  var content = buffer.toString();
  if (!content.contains('\r\n')) {
    // Guard against a peer that never terminates a message.
    if (content.length > 16384) buffer.clear();
    return const [];
  }

  final lines = <String>[];
  int index;
  while ((index = content.indexOf('\r\n')) >= 0) {
    final line = content.substring(0, index).trim();
    content = content.substring(index + 2);
    if (line.isNotEmpty) lines.add(line);
  }

  buffer.clear();
  buffer.write(content);
  return lines;
}

Map<String, dynamic>? _decode(String line) {
  try {
    final decoded = jsonDecode(line);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (e) {
    return null;
  }
}

/// Data model for a Yeelight lamp
class YeelightDevice {
  final String id;
  final String name;
  final String model;
  final String ip;
  final bool power;
  final int brightness;
  final int? colorTemp;
  final int? rgb;
  final List<String> supportedMethods;

  YeelightDevice({
    required this.id,
    required this.name,
    required this.model,
    required this.ip,
    required this.power,
    required this.brightness,
    this.colorTemp,
    this.rgb,
    this.supportedMethods = const [],
  });

  /// Kopie mit geänderten Werten erstellen
  YeelightDevice copyWith({
    String? name,
    bool? power,
    int? brightness,
    int? colorTemp,
    int? rgb,
  }) {
    return YeelightDevice(
      id: id,
      name: name ?? this.name,
      model: model,
      ip: ip,
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      rgb: rgb ?? this.rgb,
      supportedMethods: supportedMethods,
    );
  }

  /// JSON Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'ip': ip,
      'power': power,
      'brightness': brightness,
      'colorTemp': colorTemp,
      'rgb': rgb,
      'supportedMethods': supportedMethods,
    };
  }

  /// JSON Deserialisierung
  factory YeelightDevice.fromJson(Map<String, dynamic> json) {
    return YeelightDevice(
      id: json['id'],
      name: json['name'],
      model: json['model'],
      ip: json['ip'],
      power: json['power'],
      brightness: json['brightness'],
      colorTemp: json['colorTemp'],
      rgb: json['rgb'],
      supportedMethods: List<String>.from(json['supportedMethods'] ?? []),
    );
  }

  @override
  String toString() =>
      'YeelightDevice(id: $id, name: $name, ip: $ip, power: $power)';
}
