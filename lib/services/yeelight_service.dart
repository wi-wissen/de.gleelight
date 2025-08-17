import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class YeelightService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _multicastPort = 1982;
  static const int _commandPort = 55443;
  
  final StreamController<YeelightDevice> _deviceController = StreamController.broadcast();
  RawDatagramSocket? _udpSocket;
  Timer? _discoveryTimer;
  
  Stream<YeelightDevice> get deviceStream => _deviceController.stream;

  /// Startet die Lampenerkennung
  Future<void> startDiscovery() async {
    try {
      print('🚀 Starte Discovery...');
      
      // Port-Scan im lokalen Netzwerk
      await _scanLocalNetwork();
      
      // UDP Discovery parallel versuchen (falls es doch funktioniert)
      await _startUdpDiscovery();
      
    } catch (e) {
      print('❌ Discovery Fehler: $e');
    }
  }

  /// Scannt das lokale Netzwerk nach Yeelight-Lampen
  Future<void> _scanLocalNetwork() async {
    try {
      print('🔍 Scanne lokales Netzwerk...');
      
      // Lokale IP bestimmen
      final localIP = await _getLocalIP();
      if (localIP == null) {
        print('❌ Konnte lokale IP nicht bestimmen');
        return;
      }
      
      print('🌐 Lokale IP: $localIP');
      
      // Netzwerk-Range ableiten (z.B. 192.168.178.x)
      final parts = localIP.split('.');
      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';
      
      print('🔍 Scanne Netzwerk: $networkBase.1-254');
      
      // Parallel-Scan für bessere Performance
      final List<Future<YeelightDevice?>> scanFutures = [];
      
      for (int i = 1; i <= 254; i++) {
        final ip = '$networkBase.$i';
        scanFutures.add(_scanHost(ip));
      }
      
      // Alle Scans gleichzeitig ausführen
      final results = await Future.wait(scanFutures);
      
      // Gefundene Geräte verarbeiten
      int foundCount = 0;
      for (final device in results) {
        if (device != null) {
          foundCount++;
          print('✅ Yeelight gefunden: ${device.ip} (${device.name})');
          _deviceController.add(device);
        }
      }
      
      print('🏁 Netzwerk-Scan abgeschlossen: $foundCount Lampe(n) gefunden');
      
    } catch (e) {
      print('❌ Netzwerk-Scan Fehler: $e');
    }
  }

  /// Bestimmt die lokale IP-Adresse
  Future<String?> _getLocalIP() async {
    try {
      // Verbindung zu externem Server aufbauen um lokale IP zu bestimmen
      final socket = await Socket.connect('8.8.8.8', 80);
      final localIP = socket.address.address;
      socket.destroy();
      return localIP;
    } catch (e) {
      print('❌ Lokale IP Fehler: $e');
      return null;
    }
  }

  /// Scannt einen einzelnen Host auf Yeelight-Port
  Future<YeelightDevice?> _scanHost(String ip) async {
    Socket? socket;
    try {
      // TCP-Verbindung mit kurzem Timeout versuchen
      socket = await Socket.connect(ip, _commandPort)
          .timeout(const Duration(seconds: 2));
      
      // get_prop Kommando senden um zu testen ob es eine Yeelight ist
      final properties = await _sendCommandToSocket(socket, 'get_prop', [
        'power', 'bright', 'ct', 'rgb', 'name', 'model'
      ]);
      
      if (properties != null && properties['result'] != null) {
        final result = properties['result'] as List;
        
        // YeelightDevice erstellen
        final device = YeelightDevice(
          id: 'lamp_${ip.replaceAll('.', '_')}',
          name: (result.length > 4 && result[4] != null && result[4].toString().isNotEmpty) 
              ? result[4].toString() 
              : 'Yeelight ($ip)',
          model: (result.length > 5 && result[5] != null) 
              ? result[5].toString() 
              : 'unknown',
          ip: ip,
          power: result[0] == 'on',
          brightness: int.tryParse(result[1]?.toString() ?? '100') ?? 100,
          colorTemp: int.tryParse(result[2]?.toString() ?? '0'),
          rgb: int.tryParse(result[3]?.toString() ?? '0'),
          supportedMethods: _getDefaultSupportedMethods(),
        );
        
        return device;
      }
      
    } catch (e) {
      // Timeout oder Connection refused ist normal für Nicht-Yeelight IPs
    } finally {
      socket?.destroy();
    }
    
    return null;
  }

  /// Sendet Kommando über bestehende Socket-Verbindung
  Future<Map<String, dynamic>?> _sendCommandToSocket(
    Socket socket, 
    String method, 
    List<dynamic> params
  ) async {
    try {
      final command = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'method': method,
        'params': params,
      };
      
      final jsonCommand = '${jsonEncode(command)}\r\n';
      socket.write(jsonCommand);
      
      // Antwort lesen mit Timeout
      final completer = Completer<String>();
      String buffer = '';
      
      late StreamSubscription subscription;
      subscription = socket.listen(
        (data) {
          buffer += utf8.decode(data);
          if (buffer.contains('\r\n') && !completer.isCompleted) {
            subscription.cancel();
            completer.complete(buffer);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            subscription.cancel();
            completer.completeError(error);
          }
        },
      );
      
      final response = await completer.future
          .timeout(const Duration(seconds: 3));
      
      return jsonDecode(response.trim());
      
    } catch (e) {
      return null;
    }
  }

  /// Standard unterstützte Methoden für erkannte Lampen
  List<String> _getDefaultSupportedMethods() {
    return [
      'get_prop',
      'set_power',
      'toggle',
      'set_bright',
      'set_ct_abx',
      'set_rgb',
      'set_scene',
    ];
  }

  /// Startet UDP Discovery (original)
  Future<void> _startUdpDiscovery() async {
    try {
      // UDP Socket für Multicast erstellen
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.multicastHops = 1;
      
      // WICHTIG: Multicast-Gruppe beitreten
      final multicastAddress = InternetAddress(_multicastAddress);
      _udpSocket!.joinMulticast(multicastAddress);
      
      print('🔌 Socket gebunden auf Port: ${_udpSocket!.port}');
      print('👥 Multicast-Gruppe $_multicastAddress beigetreten');
      
      // Auf eingehende Nachrichten hören
      _udpSocket!.listen(_handleDiscoveryResponse);
      print('👂 Listening gestartet');
      
      // WICHTIG: Kurz warten bis Socket bereit ist
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Sofort nach Lampen suchen
      await _sendSearchRequest();
      
      // Alle 30 Sekunden wiederholen (für neue Lampen)
      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _sendSearchRequest(),
      );
    } catch (e) {
      print('❌ UDP Discovery Fehler: $e');
    }
  }

  /// Sendet Suchanfrage an alle Lampen im Netzwerk
  Future<void> _sendSearchRequest() async {
    if (_udpSocket == null) return;
    
    const searchMessage = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1982\r\n'
        'MAN: "ssdp:discover"\r\n'
        'ST: wifi_bulb\r\n'
        '\r\n';
    
    final data = Uint8List.fromList(utf8.encode(searchMessage));
    
    // Sowohl Multicast als auch Broadcast versuchen
    try {
      // Multicast
      final multicastAddress = InternetAddress(_multicastAddress);
      final sent1 = _udpSocket!.send(data, multicastAddress, _multicastPort);
      print('📤 Multicast Request gesendet ($sent1 bytes)');
      
      // Broadcast als Fallback
      final broadcastAddress = InternetAddress('255.255.255.255');
      final sent2 = _udpSocket!.send(data, broadcastAddress, _multicastPort);
      print('📤 Broadcast Request gesendet ($sent2 bytes)');
      
    } catch (e) {
      print('❌ Send Error: $e');
    }
  }

  /// Verarbeitet Antworten der Lampen
  void _handleDiscoveryResponse(RawSocketEvent event) {
    print('📡 Socket Event: $event');
    if (event == RawSocketEvent.read) {
      final datagram = _udpSocket!.receive();
      if (datagram != null) {
        final response = utf8.decode(datagram.data);
        print('📨 Antwort empfangen von ${datagram.address}:');
        print('📄 Response: $response');
        print('---');
        final device = _parseDiscoveryResponse(response, datagram.address);
        if (device != null) {
          print('✅ Device gefunden: $device');
          _deviceController.add(device);
        } else {
          print('❌ Parsing fehlgeschlagen');
        }
      } else {
        print('📭 Datagram ist null');
      }
    }
  }

  /// Parst die Antwort einer Lampe
  YeelightDevice? _parseDiscoveryResponse(String response, InternetAddress address) {
    try {
      final lines = response.split('\r\n');
      if (!lines.first.contains('200 OK')) return null;
      
      String? id, model, location, name;
      int? brightness, colorTemp, rgb;
      bool? power;
      List<String> supportedMethods = [];
      
      for (final line in lines) {
        final parts = line.split(': ');
        if (parts.length != 2) continue;
        
        final key = parts[0].toLowerCase();
        final value = parts[1];
        
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
            name = value.isEmpty ? 'Yeelight $model' : value;
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
            supportedMethods = value.split(' ');
            break;
        }
      }
      
      if (id == null || location == null) return null;
      
      // IP aus Location extrahieren (yeelight://192.168.1.239:55443)
      final locationUri = Uri.parse(location);
      final ip = locationUri.host;
      
      return YeelightDevice(
        id: id,
        name: name ?? 'Yeelight $model',
        model: model ?? 'unknown',
        ip: ip,
        power: power ?? false,
        brightness: brightness ?? 100,
        colorTemp: colorTemp,
        rgb: rgb,
        supportedMethods: supportedMethods,
      );
    } catch (e) {
      print('Fehler beim Parsen: $e');
      return null;
    }
  }

  /// Sendet Kommando an eine Lampe
  Future<Map<String, dynamic>?> sendCommand(
    String ip,
    String method,
    List<dynamic> params,
  ) async {
    Socket? socket;
    try {
      // TCP Verbindung zur Lampe
      socket = await Socket.connect(ip, _commandPort);
      
      final command = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'method': method,
        'params': params,
      };
      
      final jsonCommand = '${jsonEncode(command)}\r\n';
      socket.write(jsonCommand);
      
      // Antwort lesen mit korrektem Transform
      final completer = Completer<String>();
      String buffer = '';
      
      socket.listen(
        (data) {
          buffer += utf8.decode(data);
          if (buffer.contains('\r\n')) {
            if (!completer.isCompleted) {
              completer.complete(buffer);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      final response = await completer.future;
      socket.destroy();
      
      return jsonDecode(response.trim());
    } catch (e) {
      print('Kommando Fehler ($method): $e');
      socket?.destroy();
      return null;
    }
  }

  /// Lampe an/aus schalten
  Future<bool> setPower(String ip, bool on, {String effect = 'smooth', int duration = 500}) async {
    final result = await sendCommand(ip, 'set_power', [
      on ? 'on' : 'off',
      effect,
      duration,
    ]);
    return result?['result']?[0] == 'ok';
  }

  /// Helligkeit setzen (1-100)
  Future<bool> setBrightness(String ip, int brightness, {String effect = 'smooth', int duration = 500}) async {
    final result = await sendCommand(ip, 'set_bright', [
      brightness.clamp(1, 100),
      effect,
      duration,
    ]);
    return result?['result']?[0] == 'ok';
  }

  /// Farbtemperatur setzen (1700-6500K)
  Future<bool> setColorTemp(String ip, int colorTemp, {String effect = 'smooth', int duration = 500}) async {
    final result = await sendCommand(ip, 'set_ct_abx', [
      colorTemp.clamp(1700, 6500),
      effect,
      duration,
    ]);
    return result?['result']?[0] == 'ok';
  }

  /// RGB Farbe setzen
  Future<bool> setRgb(String ip, int rgb, {String effect = 'smooth', int duration = 500}) async {
    final result = await sendCommand(ip, 'set_rgb', [
      rgb.clamp(0, 16777215),
      effect,
      duration,
    ]);
    return result?['result']?[0] == 'ok';
  }

  /// Eigenschaften abfragen
  Future<Map<String, dynamic>?> getProperties(String ip, List<String> properties) async {
    final result = await sendCommand(ip, 'get_prop', properties);
    if (result?['result'] != null) {
      final values = result!['result'] as List;
      return Map.fromIterables(properties, values);
    }
    return null;
  }

  /// Szene setzen
  Future<bool> setScene(String ip, String sceneClass, List<dynamic> params) async {
    final result = await sendCommand(ip, 'set_scene', [sceneClass, ...params]);
    return result?['result']?[0] == 'ok';
  }

  /// Discovery stoppen
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _udpSocket?.close();
    _deviceController.close();
  }
}

/// Datenmodell für eine Yeelight-Lampe
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
  String toString() => 'YeelightDevice(id: $id, name: $name, ip: $ip, power: $power)';
}