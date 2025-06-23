import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  runApp(const SmartSoakApp());
}

class SmartSoakApp extends StatelessWidget {
  const SmartSoakApp({super.key});

  static final _defaultLightColorScheme =
      ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);

  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal, brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        return MaterialApp(
          title: 'SmartSoak Controller',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme ?? _defaultLightColorScheme,
            cardTheme: CardThemeData(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            // Text themes now inherit colors from the colorScheme automatically.
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
            cardTheme: CardThemeData(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            // Text themes now inherit colors from the colorScheme automatically.
          ),
          themeMode: ThemeMode.system, // Automatically adapt to system theme
          home: const SmartSoakController(),
        );
      },
    );
  }
}

class SmartSoakController extends StatefulWidget {
  const SmartSoakController({super.key});

  @override
  _SmartSoakControllerState createState() => _SmartSoakControllerState();
}

class _SmartSoakControllerState extends State<SmartSoakController> with TickerProviderStateMixin {
  bool _useHTTP = true;
  String esp8266IP = '192.168.1.100';
  final TextEditingController _ipController = TextEditingController();
  
  final String mqttBroker = 'bbbe942594e74a1ebe91977e21569d1d.s1.eu.hivemq.cloud';
  final int mqttPort = 8883;
  final String mqttUsername = 'Dinesh';
  final String mqttPassword = 'Dinesh200^';
  late MqttServerClient _mqttClient;
  
  bool _isConnected = false;
  String _connectionStatus = 'Checking connection...';
  String _lastError = '';
  
  bool _boreMotorRunning = false;
  bool _mainWaterValveOpen = false;
  bool _tankWaterAvailable = false;
  
  List<bool> _laneValveStates = [false, false, false];
  String _activeWaterSource = 'None';
  
  DateTime? _lastUpdate;
  Timer? _statusTimer;  @override
  void initState() {
    super.initState();
    _ipController.text = esp8266IP;
    _setupMqttClient();
    _checkConnection();
    _statusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_isConnected) {
        _getStatus();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _ipController.dispose();
    if (!_useHTTP) {
      _mqttClient.disconnect();
    }
    super.dispose();
  }

  void _setupMqttClient() {
    _mqttClient = MqttServerClient.withPort(mqttBroker, 'flutter_smartsoak', mqttPort);
    _mqttClient.secure = true;
    _mqttClient.onBadCertificate = (dynamic certificate) => true;
    _mqttClient.logging(on: false);
    _mqttClient.keepAlivePeriod = 60;
    _mqttClient.connectTimeoutPeriod = 30000;
    
    _mqttClient.onConnected = () {
      print('MQTT Connected');
      _mqttClient.subscribe('smartsoak/status', MqttQos.atMostOnce);
      _mqttClient.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> messages) {
        for (var message in messages) {
          final payload = message.payload as MqttPublishMessage;
          final messageText = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
          _parseMqttMessage(messageText);
        }
      });
    };
    
    _mqttClient.onDisconnected = () {
      print('MQTT Disconnected');
    };
  }  void _parseMqttMessage(String message) {
    try {
      final data = jsonDecode(message);
      setState(() {
        _boreMotorRunning = data['bore_motor_on'] ?? false;
        _mainWaterValveOpen = data['main_water_on'] ?? false;
        _tankWaterAvailable = data['bore_water_available'] ?? false;
        
        if (data['valve_states'] is List) {
          final valveStates = List<bool>.from(data['valve_states']);
          for (int i = 0; i < 3 && i < valveStates.length; i++) {
            _laneValveStates[i] = valveStates[i];
          }
        }
        
        if (_boreMotorRunning) {
          _activeWaterSource = 'Bore';
        } else if (_mainWaterValveOpen) {
          _activeWaterSource = 'Main Water';
        } else {
          _activeWaterSource = 'None';
        }
        
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }
  Future<void> _checkConnection() async {
    setState(() {
      _connectionStatus = 'Connecting...';
      _lastError = '';
    });

    if (_useHTTP) {
      await _checkHTTPConnection();
    } else {
      await _checkMQTTConnection();
    }
  }

  Future<void> _checkHTTPConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://$esp8266IP/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected to ESP8266 (Local)';
        });
        _parseStatusResponse(response.body);
      } else {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'HTTP Connection failed';
          _lastError = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'HTTP Connection error';
        _lastError = e.toString();
      });
    }
  }

  Future<void> _checkMQTTConnection() async {
    try {
      await _mqttClient.connect(mqttUsername, mqttPassword);
      if (_mqttClient.connectionStatus!.state == MqttConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected to MQTT (Remote)';
        });
      } else {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'MQTT Connection failed';
          _lastError = 'MQTT connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'MQTT Connection error';
        _lastError = e.toString();
      });
    }
  }  Future<void> _getStatus() async {
    if (!_isConnected) return;

    if (_useHTTP) {
      await _getHTTPStatus();
    }
  }

  Future<void> _getHTTPStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://$esp8266IP/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        _parseStatusResponse(response.body);
      }
    } catch (e) {
      print('Error getting HTTP status: $e');
    }
  }  void _parseStatusResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      setState(() {
        _boreMotorRunning = data['bore_motor_on'] ?? data['pump'] ?? false;
        _mainWaterValveOpen = data['main_water_on'] ?? false;
        _tankWaterAvailable = data['bore_water_available'] ?? true;
        
        if (data['valve_states'] is List) {
          final valveStates = List<bool>.from(data['valve_states']);
          for (int i = 0; i < 3 && i < valveStates.length; i++) {
            _laneValveStates[i] = valveStates[i];
          }
        } else {
          _laneValveStates[0] = data['solenoid'] == true || data['solenoid'] == 'open';
        }
        
        if (_boreMotorRunning) {
          _activeWaterSource = 'Bore';
        } else if (_mainWaterValveOpen) {
          _activeWaterSource = 'Main Water';
        } else {
          _activeWaterSource = 'None';
        }
        
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      print('Error parsing status response: $e');
      setState(() {
        _lastError = 'Error parsing response: $e';
      });
    }
  }  Future<void> _sendCommand(String command) async {
    if (!_isConnected) {
      _showSnackBar('Not connected');
      return;
    }

    final isTurningLanesOn = (command.startsWith('lane') && command.endsWith('_on')) || command == 'all_lanes_on';
    if (isTurningLanesOn && !_mainWaterValveOpen) {
      _showEnableMainWaterDialog();
      return;
    }

    if (command == 'emergency_stop') {
      setState(() {
        _boreMotorRunning = false;
        _mainWaterValveOpen = false;
        _laneValveStates = [false, false, false];
        _activeWaterSource = 'None';
      });
    } else if (command == 'all_lanes_off') {
      setState(() {
        _laneValveStates = [false, false, false];
      });
    } else if (command == 'all_lanes_on') {
      setState(() {
        _laneValveStates = [true, true, true];
      });
    } else if (command == 'bore_on') {
      setState(() {
        _boreMotorRunning = true;
        _activeWaterSource = 'Bore';
      });
    } else if (command == 'bore_off') {
      setState(() {
        _boreMotorRunning = false;
        _activeWaterSource = _mainWaterValveOpen ? 'Main Water' : 'None';
      });
    } else if (command == 'main_water_on') {
      setState(() {
        _mainWaterValveOpen = true;
        if (!_boreMotorRunning) {
          _activeWaterSource = 'Main Water';
        }
      });
    } else if (command == 'main_water_off') {
      setState(() {
        _mainWaterValveOpen = false;
        _laneValveStates = [false, false, false];
        if (_activeWaterSource == 'Main Water') {
          _activeWaterSource = 'None';
        }
      });
    } else if (command.startsWith('lane') && (command.endsWith('_on') || command.endsWith('_off'))) {
      int laneIndex = int.parse(command.substring(4, 5)) - 1;
      bool newState = command.endsWith('_on');
      setState(() {
        _laneValveStates[laneIndex] = newState;
      });
    }

    if (_useHTTP) {
      await _sendHTTPCommand(command);
    } else {
      await _sendMQTTCommand(command);
    }
  }

  Future<void> _sendHTTPCommand(String command) async {
    try {
      final response = await http.post(
        Uri.parse('http://$esp8266IP/control'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar('Command sent successfully');
        Future.delayed(Duration(milliseconds: 500), () => _getStatus());
      } else {
        _showSnackBar('Command failed: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Error sending command: $e');
    }
  }  Future<void> _sendMQTTCommand(String command) async {
    try {
      Map<String, dynamic> commandData;
      
      // Water source commands
      if (command == 'bore_on' || command == 'bore_off') {
        commandData = {
          'type': 'bore',
          'state': command == 'bore_on' ? 'on' : 'off'
        };
      } else if (command == 'main_water_on' || command == 'main_water_off') {
        commandData = {
          'type': 'main_water',
          'state': command == 'main_water_on' ? 'on' : 'off'
        };
      }
      // Individual lane commands
      else if (command.startsWith('lane') && (command.endsWith('_on') || command.endsWith('_off'))) {
        int laneNumber = int.parse(command.substring(4, 5)) - 1; // Extract lane number (0-based)
        bool state = command.endsWith('_on');
        commandData = {
          'type': 'valve',
          'id': laneNumber,
          'state': state ? 'open' : 'closed'
        };
      }
      // All lanes commands
      else if (command == 'all_lanes_on' || command == 'all_lanes_off') {
        bool state = command == 'all_lanes_on';
        commandData = {
          'type': 'all_valves',
          'state': state ? 'open' : 'closed'
        };
      }
      // Emergency stop
      else if (command == 'emergency_stop') {
        commandData = {
          'type': 'emergency_stop'
        };
      }
      // Legacy commands (backward compatibility)
      else if (command == 'open' || command == 'close') {
        commandData = {
          'type': 'valve',
          'id': 0,
          'state': command == 'open' ? 'open' : 'closed'
        };
      } else if (command == 'pump_on' || command == 'pump_off') {
        commandData = {
          'type': 'bore',
          'state': command == 'pump_on' ? 'on' : 'off'
        };
      } else {
        _showSnackBar('Unknown command: $command');
        return;
      }

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(commandData));
      _mqttClient.publishMessage('smartsoak/command', MqttQos.atMostOnce, builder.payload!);
      _showSnackBar('MQTT command sent');
    } catch (e) {
      _showSnackBar('Error sending MQTT command: $e');
    }
  }

  void _showEnableMainWaterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              const Text('Main Water is Off'),
            ],
          ),
          content: const Text(
            'You must open the main water valve before turning on any irrigation lanes. Do you want to open it now?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _sendCommand('main_water_on');
              },
              icon: const Icon(Icons.water_drop),
              label: const Text('Open Main Valve'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  void _updateIPAddress() {
    setState(() {
      esp8266IP = _ipController.text.trim();
    });
    if (_useHTTP) {
      _checkConnection();
    }
  }

  void _showEmergencyStopDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: theme.colorScheme.error, size: 32),
              const SizedBox(width: 12),
              Text('Emergency Stop', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'This will immediately stop all water sources and close all valves. Are you sure?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _sendCommand('emergency_stop');
              },
              icon: const Icon(Icons.stop),
              label: const Text('STOP ALL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartSoak Controller'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Mode Toggle
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24), // Expressive shape
              ),
              clipBehavior: Clip.antiAlias, // Ensures content respects the border radius
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 12.0, top: 12.0, bottom: 12.0),
                child: Row(
                  children: [
                    // Animated text for current mode
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Connection', style: theme.textTheme.titleMedium),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.5),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _useHTTP ? 'Local (HTTP)' : 'Remote (MQTT)',
                              key: ValueKey<bool>(_useHTTP),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The control itself
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.wifi),
                          tooltip: 'Local Network',
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.cloud_queue),
                          tooltip: 'Remote via Internet',
                        ),
                      ],
                      selected: <bool>{_useHTTP},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          if (_useHTTP == newSelection.first) return;
                          _useHTTP = newSelection.first;
                          _isConnected = false;
                          _connectionStatus = _useHTTP ? 'HTTP Mode (Local)' : 'MQTT Mode (Remote)';
                        });
                        _checkConnection();
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        selectedBackgroundColor: colorScheme.primary,
                        selectedForegroundColor: colorScheme.onPrimary,
                        side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // IP Address Configuration (only show for HTTP mode)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  child: child,
                );
              },
              child: _useHTTP ? Card(
                key: const ValueKey('http-config'),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESP8266 Configuration', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ipController,
                              decoration: const InputDecoration(
                                labelText: 'ESP8266 IP Address',
                                hintText: '192.168.1.100',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _updateIPAddress,
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ) : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            
            const SizedBox(height: 16),
            
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            _isConnected ? Icons.check_circle_rounded : Icons.error_rounded,
                            key: ValueKey<bool>(_isConnected),
                            color: _isConnected ? colorScheme.primary : colorScheme.error,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _connectionStatus,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isConnected ? colorScheme.primary : colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_lastError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_lastError',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      ),
                    ],
                    if (_lastUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last Update: ${_lastUpdate!.toString().substring(11, 19)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _checkConnection,
                      child: const Text('Refresh Connection'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
              // System Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Sources', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    
                    // Tank Water Status
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _tankWaterAvailable ? Icons.water_damage_rounded : Icons.water_drop_outlined,
                            key: ValueKey<bool>(_tankWaterAvailable),
                            color: _tankWaterAvailable ? colorScheme.secondary : colorScheme.error,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tank Water: ${_tankWaterAvailable ? "AVAILABLE" : "LOW"}',
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Bore Motor
                    Row(
                      children: [
                        Icon(
                          _boreMotorRunning ? Icons.power : Icons.power_off,
                          color: _boreMotorRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bore Motor: ${_boreMotorRunning ? "RUNNING" : "STOPPED"}',
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Main Water Supply
                    Row(
                      children: [
                        Icon(
                          _mainWaterValveOpen ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                          color: _mainWaterValveOpen ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Main Water: ${_mainWaterValveOpen ? "OPEN" : "CLOSED"}',
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Active Water Source: Only show when a source is active
                    if (_activeWaterSource != 'None')
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 1,
                          )
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Source: $_activeWaterSource',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lane Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Irrigation Lanes', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    
                    // Lane statuses
                    for (int i = 0; i < 3; i++) ...[
                      Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                            child: Icon(
                              _laneValveStates[i] ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                              key: ValueKey<bool>(_laneValveStates[i]),
                              color: _laneValveStates[i] ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lane ${i + 1}: ${_laneValveStates[i] ? "OPEN" : "CLOSED"}',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      if (i < 2) const SizedBox(height: 8),
                    ],
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Lane Controls
                    for (int i = 0; i < 3; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text('Lane ${i + 1}', style: theme.textTheme.titleMedium),
                          ),
                          Switch(
                            value: _laneValveStates[i],
                            onChanged: _isConnected
                                ? (bool value) {
                                    _sendCommand('lane${i + 1}_${value ? 'on' : 'off'}');
                                  }
                                : null,
                          ),
                        ],
                      ),
                      if (i < 2) const Divider(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Water Source Controls
            Text('Water Source Controls', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected && !_boreMotorRunning ? () => _sendCommand('bore_on') : null,
                    icon: const Icon(Icons.power),
                    label: const Text('Start Bore'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected && _boreMotorRunning ? () => _sendCommand('bore_off') : null,
                    icon: const Icon(Icons.power_off),
                    label: const Text('Stop Bore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected && !_mainWaterValveOpen ? () => _sendCommand('main_water_on') : null,
                    icon: const Icon(Icons.water_drop),
                    label: const Text('Open Main'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected && _mainWaterValveOpen ? () => _sendCommand('main_water_off') : null,
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Close Main'),
                     style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // Quick Control Buttons
            Text('Quick Controls', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? () => _sendCommand('all_lanes_on') : null,
                    icon: const Icon(Icons.grid_on),
                    label: const Text('All Lanes ON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? () => _sendCommand('all_lanes_off') : null,
                    icon: const Icon(Icons.grid_off),
                    label: const Text('All Lanes OFF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isConnected ? _showEmergencyStopDialog : null,
                icon: const Icon(Icons.error),
                label: const Text('EMERGENCY STOP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
